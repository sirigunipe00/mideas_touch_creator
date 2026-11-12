/// Bump this whenever you ship a mobile/web build so support can verify the client.
/// Keep in sync with `version:` in pubspec.yaml.
class AppVersion {
  static const name = '1.0.1';
  static const build = 2;

  /// Shown in UI, e.g. `v1.0.1 (2)`.
  static String get label => 'v$name ($build)';
}
