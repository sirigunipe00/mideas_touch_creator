// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'local_session_store.dart';

LocalSessionStore createStore() => _WebLocalSessionStore();

class _WebLocalSessionStore implements LocalSessionStore {
  html.Storage get _storage => html.window.localStorage;

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getString(String key) async => _storage[key];

  @override
  Future<void> setString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}
