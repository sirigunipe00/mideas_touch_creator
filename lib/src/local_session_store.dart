import 'local_session_store_stub.dart'
    if (dart.library.html) 'local_session_store_web.dart'
    if (dart.library.io) 'local_session_store_io.dart';

/// Tiny key/value store for auth session persistence.
/// Web uses browser localStorage (avoids shared_preferences MissingPluginException).
abstract class LocalSessionStore {
  Future<void> reload();

  Future<String?> getString(String key);

  Future<void> setString(String key, String value);

  Future<void> remove(String key);
}

LocalSessionStore createLocalSessionStore() => createStore();
