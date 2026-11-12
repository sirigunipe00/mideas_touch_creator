import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mideas_touch_creator/src/local_session_store.dart';
import 'package:mideas_touch_creator/src/models.dart';
import 'package:mideas_touch_creator/src/supabase_config.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final StudioUser user;
  final String accessToken;
  final String refreshToken;
}

abstract class AuthRepository {
  Future<AuthSession?> restoreSession();

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthSession> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  void close() {}
}

/// Creator accounts are separate from customer Auth users.
///
/// Supabase Auth emails must be unique project-wide, so creators sign up with a
/// private auth email while logging in with their real email via [creator_accounts].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({http.Client? client, LocalSessionStore? store})
      : _client = client ?? http.Client(),
        _store = store ?? createLocalSessionStore();

  final http.Client _client;
  final LocalSessionStore _store;

  static const _accessKey = 'mtc_access_token';
  static const _refreshKey = 'mtc_refresh_token';
  static const _userIdKey = 'mtc_user_id';
  static const _userEmailKey = 'mtc_user_email';
  static const _userNameKey = 'mtc_user_name';

  @override
  Future<AuthSession?> restoreSession() async {
    await _store.reload();
    final access = await _store.getString(_accessKey);
    final refresh = await _store.getString(_refreshKey);
    final userId = await _store.getString(_userIdKey);
    final email = await _store.getString(_userEmailKey);
    final name = await _store.getString(_userNameKey);
    if (access == null || access.isEmpty || userId == null || userId.isEmpty) {
      debugPrint('Auth session: no stored session');
      return null;
    }

    AuthSession cachedSession() {
      return AuthSession(
        user: StudioUser(
          id: userId,
          name: (name == null || name.trim().isEmpty) ? 'Creator' : name.trim(),
          email: email ?? '',
        ),
        accessToken: access,
        refreshToken: refresh ?? '',
      );
    }

    http.Response userResponse;
    try {
      userResponse = await _client.get(
        Uri.parse('${SupabaseConfig.url}/auth/v1/user'),
        headers: _headers(accessToken: access),
      );
    } catch (error, stackTrace) {
      // Keep local session on transient network errors (common on web restart).
      _logError('restoreSession network failed — using cached session', error, stackTrace);
      return cachedSession();
    }

    if (userResponse.statusCode >= 200 && userResponse.statusCode < 300) {
      try {
        final authUser = _authUserFromJson(jsonDecode(userResponse.body));
        final profile = await _fetchCreatorAccount(authUserId: authUser.id, accessToken: access);
        final session = AuthSession(
          user: StudioUser(
            id: authUser.id,
            name: (profile?.name.isNotEmpty == true)
                ? profile!.name
                : ((name == null || name.trim().isEmpty) ? authUser.name : name.trim()),
            email: (profile?.email.isNotEmpty == true)
                ? profile!.email
                : ((email == null || email.isEmpty) ? authUser.email : email),
          ),
          accessToken: access,
          refreshToken: refresh ?? '',
        );
        await _persist(session);
        debugPrint('Auth session restored for ${session.user.email}');
        return session;
      } catch (error, stackTrace) {
        _logError('restoreSession parse failed — using cached session', error, stackTrace, body: userResponse.body);
        return cachedSession();
      }
    }

    _logError('restoreSession user check failed', null, null, status: userResponse.statusCode, body: userResponse.body);

    // Only clear when the token is definitively invalid.
    if (userResponse.statusCode == 401 || userResponse.statusCode == 403) {
      if (refresh == null || refresh.isEmpty) {
        await _clearPrefs();
        return null;
      }
      try {
        final refreshed = await _refresh(refresh);
        if (refreshed == null) {
          await _clearPrefs();
          return null;
        }
        await _persist(refreshed);
        debugPrint('Auth session refreshed for ${refreshed.user.email}');
        return refreshed;
      } catch (error, stackTrace) {
        _logError('restoreSession refresh failed', error, stackTrace);
        await _clearPrefs();
        return null;
      }
    }

    // Non-auth failure (5xx etc.): keep cached session.
    return cachedSession();
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final realEmail = email.trim().toLowerCase();
    final fullName = name.trim();

    final existing = await _lookupAuthEmail(realEmail);
    if (existing != null && existing.isNotEmpty) {
      throw AuthException('A creator account with this email already exists. Please login.');
    }

    final authEmail = _creatorAuthEmail(realEmail);
    final signupResponse = await _client.post(
      Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
      headers: _headers(),
      body: jsonEncode({
        'email': authEmail,
        'password': password,
        'data': {
          'full_name': fullName,
          'creator_email': realEmail,
          'is_creator': true,
          'app_role': 'creator',
        },
      }),
    );
    if (signupResponse.statusCode < 200 || signupResponse.statusCode >= 300) {
      _logError('creator signup failed', null, null, status: signupResponse.statusCode, body: signupResponse.body);
      throw AuthException(_authMessage(signupResponse));
    }

    final session = _sessionFromAuthResponse(signupResponse, fallbackName: fullName, displayEmail: realEmail);
    await _insertCreatorAccount(
      realEmail: realEmail,
      authEmail: authEmail,
      authUserId: session.user.id,
      fullName: fullName,
      accessToken: session.accessToken,
    );
    final ready = AuthSession(
      user: StudioUser(id: session.user.id, name: fullName, email: realEmail),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    await _persist(ready);
    return ready;
  }

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final realEmail = email.trim().toLowerCase();
      final authEmail = await _lookupAuthEmail(realEmail);
      if (authEmail == null || authEmail.isEmpty) {
        throw AuthException('Invalid user');
      }

      final response = await _client.post(
        Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=password'),
        headers: _headers(),
        body: jsonEncode({
          'email': authEmail,
          'password': password,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logError('creator login failed', null, null, status: response.statusCode, body: response.body);
        throw AuthException(_loginFailureMessage(response));
      }

      final session = _sessionFromAuthResponse(response, fallbackName: 'Creator', displayEmail: realEmail);
      final profile = await _fetchCreatorAccount(authUserId: session.user.id, accessToken: session.accessToken);
      final ready = AuthSession(
        user: StudioUser(
          id: session.user.id,
          name: profile?.name.isNotEmpty == true ? profile!.name : session.user.name,
          email: realEmail,
        ),
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      await _persist(ready);
      return ready;
    } on AuthException {
      rethrow;
    } catch (error, stackTrace) {
      _logError('creator login unexpected failure', error, stackTrace);
      throw AuthException(_networkOrUnknownMessage(error));
    }
  }

  @override
  Future<void> logout() async {
    final access = await _store.getString(_accessKey);
    if (access != null && access.isNotEmpty) {
      try {
        await _client.post(
          Uri.parse('${SupabaseConfig.url}/auth/v1/logout'),
          headers: _headers(accessToken: access),
        );
      } catch (error, stackTrace) {
        _logError('logout request failed', error, stackTrace);
      }
    }
    await _clearPrefs();
  }

  Future<AuthSession?> _refresh(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('${SupabaseConfig.url}/auth/v1/token?grant_type=refresh_token'),
      headers: _headers(),
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logError('refresh failed', null, null, status: response.statusCode, body: response.body);
      return null;
    }
    try {
      final session = _sessionFromAuthResponse(response, fallbackName: 'Creator');
      final profile = await _fetchCreatorAccount(authUserId: session.user.id, accessToken: session.accessToken);
      return AuthSession(
        user: StudioUser(
          id: session.user.id,
          name: profile?.name ?? session.user.name,
          email: profile?.email ?? session.user.email,
        ),
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
    } catch (error, stackTrace) {
      _logError('refresh parse failed', error, stackTrace, body: response.body);
      return null;
    }
  }

  Future<String?> _lookupAuthEmail(String realEmail) async {
    late final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('${SupabaseConfig.url}/rest/v1/rpc/creator_auth_email'),
        headers: _headers(),
        body: jsonEncode({'p_email': realEmail}),
      );
    } catch (error, stackTrace) {
      _logError('creator_auth_email network failed', error, stackTrace);
      throw AuthException(_networkOrUnknownMessage(error));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logError('creator_auth_email rpc failed', null, null, status: response.statusCode, body: response.body);
      throw AuthException('Could not reach creator login. Run the creator_accounts SQL in Supabase.');
    }
    if (response.body.isEmpty || response.body == 'null') return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is String && decoded.isNotEmpty) return decoded;
      return null;
    } catch (error, stackTrace) {
      _logError('creator_auth_email parse failed', error, stackTrace, body: response.body);
      return null;
    }
  }

  Future<void> _insertCreatorAccount({
    required String realEmail,
    required String authEmail,
    required String authUserId,
    required String fullName,
    required String accessToken,
  }) async {
    final response = await _client.post(
      Uri.parse('${SupabaseConfig.url}/rest/v1/creator_accounts'),
      headers: {
        ..._headers(accessToken: accessToken),
        'Prefer': 'return=minimal',
      },
      body: jsonEncode({
        'email': realEmail,
        'auth_email': authEmail,
        'auth_user_id': authUserId,
        'full_name': fullName,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logError('insert creator_accounts failed', null, null, status: response.statusCode, body: response.body);
      throw AuthException(
        'Creator auth user was created, but creator_accounts insert failed. Run the SQL setup, then try again.',
      );
    }
  }

  Future<({String email, String name})?> _fetchCreatorAccount({
    required String authUserId,
    required String accessToken,
  }) async {
    final uri = Uri.parse('${SupabaseConfig.url}/rest/v1/creator_accounts').replace(
      queryParameters: {
        'auth_user_id': 'eq.$authUserId',
        'select': 'email,full_name',
        'limit': '1',
      },
    );
    final response = await _client.get(uri, headers: _headers(accessToken: accessToken));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _logError('fetch creator_accounts failed', null, null, status: response.statusCode, body: response.body);
      return null;
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty || decoded.first is! Map) return null;
      final row = Map<String, dynamic>.from(decoded.first as Map);
      return (
        email: (row['email'] as String? ?? '').trim(),
        name: (row['full_name'] as String? ?? '').trim(),
      );
    } catch (error, stackTrace) {
      _logError('fetch creator_accounts parse failed', error, stackTrace, body: response.body);
      return null;
    }
  }

  /// Maps `siri@easycloud.in` → `creator-siri@easycloud.in`.
  String _creatorAuthEmail(String realEmail) {
    final at = realEmail.lastIndexOf('@');
    if (at <= 0 || at == realEmail.length - 1) {
      throw AuthException('Enter a valid email address');
    }
    final local = realEmail.substring(0, at).trim();
    final domain = realEmail.substring(at + 1).trim();
    if (local.isEmpty || domain.isEmpty) {
      throw AuthException('Enter a valid email address');
    }
    final normalizedLocal = local.toLowerCase().startsWith('creator-') ? local : 'creator-$local';
    return '${normalizedLocal.toLowerCase()}@${domain.toLowerCase()}';
  }

  AuthSession _sessionFromAuthResponse(
    http.Response response, {
    required String fallbackName,
    String? displayEmail,
  }) {
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (error, stackTrace) {
      _logError('auth response json decode failed', error, stackTrace, status: response.statusCode, body: response.body);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _authMessage(response, decoded);
      throw AuthException(message);
    }
    if (decoded == null) {
      throw AuthException('Could not complete authentication');
    }

    final access = decoded['access_token'] as String?;
    final refresh = decoded['refresh_token'] as String? ?? '';
    final userMap = decoded['user'] is Map ? Map<String, dynamic>.from(decoded['user'] as Map) : null;
    if (access == null || access.isEmpty || userMap == null) {
      if (userMap != null && (userMap['id'] as String?)?.isNotEmpty == true) {
        throw AuthException(
          'Account created, but email confirmation is still required. Disable Confirm email in Supabase Auth settings, then login.',
        );
      }
      throw AuthException('Could not complete authentication');
    }

    final authUser = _authUserFromJson(userMap, fallbackName: fallbackName);
    return AuthSession(
      user: StudioUser(
        id: authUser.id,
        name: authUser.name,
        email: displayEmail ?? authUser.email,
      ),
      accessToken: access,
      refreshToken: refresh,
    );
  }

  ({String id, String email, String name}) _authUserFromJson(Object? raw, {String fallbackName = 'Creator'}) {
    if (raw is! Map) {
      throw AuthException('Could not complete authentication');
    }
    final userMap = Map<String, dynamic>.from(raw);
    final id = userMap['id'] as String? ?? '';
    final email = userMap['email'] as String? ?? '';
    final meta = userMap['user_metadata'] is Map
        ? Map<String, dynamic>.from(userMap['user_metadata'] as Map)
        : const <String, dynamic>{};
    final metaName = meta['full_name'] as String?;
    final name = (metaName != null && metaName.trim().isNotEmpty)
        ? metaName.trim()
        : (fallbackName.isEmpty ? 'Creator' : fallbackName);
    if (id.isEmpty) {
      throw AuthException('Could not complete authentication');
    }
    return (id: id, email: email, name: name);
  }

  String _loginFailureMessage(http.Response response) {
    final decoded = _decodeMap(response.body);
    final error = decoded?['error_description'] ?? decoded?['msg'] ?? decoded?['error'] ?? decoded?['message'];
    if (error is String && error.trim().isNotEmpty) {
      final lower = error.toLowerCase();
      if (lower.contains('invalid login') ||
          lower.contains('invalid credentials') ||
          lower.contains('invalid_grant') ||
          lower.contains('email not confirmed')) {
        return 'Incorrect password';
      }
      if (error.length < 160) return error;
    }
    if (response.statusCode == 400 || response.statusCode == 401) {
      return 'Incorrect password';
    }
    return 'Could not complete authentication';
  }

  String _authMessage(http.Response response, [Map<String, dynamic>? decoded]) {
    decoded ??= _decodeMap(response.body);
    final error = decoded?['error_description'] ?? decoded?['msg'] ?? decoded?['error'] ?? decoded?['message'];
    if (error is String && error.trim().isNotEmpty) {
      final lower = error.toLowerCase();
      if (lower.contains('already') || lower.contains('registered')) {
        return 'A creator account with this email already exists. Please login.';
      }
      if (error.length < 160) return error;
    }
    if (response.statusCode == 400) return 'Invalid email or password';
    return 'Could not complete authentication';
  }

  Map<String, dynamic>? _decodeMap(String body) {
    try {
      final raw = jsonDecode(body);
      return raw is Map<String, dynamic> ? raw : null;
    } catch (_) {
      return null;
    }
  }

  void _logError(
    String label,
    Object? error,
    StackTrace? stackTrace, {
    int? status,
    String? body,
  }) {
    final buffer = StringBuffer('Auth error: $label');
    if (status != null) buffer.write(' [HTTP $status]');
    if (error != null) buffer.write(' → $error');
    debugPrint(buffer.toString());
    if (body != null && body.isNotEmpty) debugPrint('Auth error body: $body');
    if (stackTrace != null) debugPrint('$stackTrace');
  }

  Map<String, String> _headers({String? accessToken}) {
    return {
      'apikey': SupabaseConfig.publishableKey,
      'Authorization': 'Bearer ${accessToken ?? SupabaseConfig.publishableKey}',
      'Content-Type': 'application/json',
    };
  }

  String _networkOrUnknownMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('xmlhttprequest') ||
        text.contains('clientexception') ||
        text.contains('failed to fetch') ||
        text.contains('network') ||
        text.contains('cors')) {
      return 'Network error on web. Allow your web URL in Supabase Auth → URL Configuration, then retry.';
    }
    final short = error.toString();
    if (short.length <= 120) return short;
    return 'Could not login';
  }

  Future<void> _persist(AuthSession session) async {
    await _store.setString(_accessKey, session.accessToken);
    await _store.setString(_refreshKey, session.refreshToken);
    await _store.setString(_userIdKey, session.user.id);
    await _store.setString(_userEmailKey, session.user.email);
    await _store.setString(_userNameKey, session.user.name);
    await _store.reload();
    final saved = await _store.getString(_accessKey);
    if (saved != session.accessToken) {
      _logError('persist session verification failed', null, null);
      throw AuthException('Could not save login session on this device');
    }
    debugPrint('Auth session saved for ${session.user.email}');
  }

  Future<void> _clearPrefs() async {
    await _store.remove(_accessKey);
    await _store.remove(_refreshKey);
    await _store.remove(_userIdKey);
    await _store.remove(_userEmailKey);
    await _store.remove(_userNameKey);
    await _store.reload();
    debugPrint('Auth session cleared');
  }

  @override
  void close() => _client.close();
}
