import 'package:shared_preferences/shared_preferences.dart';

import 'local_session_store.dart';

LocalSessionStore createStore() => _PrefsLocalSessionStore();

class _PrefsLocalSessionStore implements LocalSessionStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensure() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<void> reload() async {
    await (await _ensure()).reload();
  }

  @override
  Future<String?> getString(String key) async {
    return (await _ensure()).getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    await (await _ensure()).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _ensure()).remove(key);
  }
}
