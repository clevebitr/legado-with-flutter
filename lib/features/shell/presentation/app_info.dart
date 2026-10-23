/// The app's identity, shown by the about page (`docs/dev/roadmap.md` §3.11, ADR-0055 §决策 4).
///
/// `version` is a hand-kept copy of `pubspec.yaml`'s `version` (without the build number): reading
/// the manifest at runtime would need a platform plugin, and one more dependency is not worth one
/// string (C-DEP-1). `app_info_test.dart` reads `pubspec.yaml` and fails when the two drift.
///
/// A packaged build may override it: the release / beta / debug workflows pass
/// `--dart-define=APP_VERSION=…` so the about page shows what was actually built
/// (`0.1.0-beta.a1b2c3d`, `0.1.0-debug.a1b2c3d.202610231540`) instead of the manifest version
/// (ADR-0067 §决策 2). With no define the constant below is the version, which is what every test
/// and every local run sees.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: _manifestVersion,
);

/// `pubspec.yaml`'s `version:`, kept in sync by `app_info_test.dart`.
const String _manifestVersion = '0.1.0';

/// Where the Corresponding Source of this build is published (GPL-3.0 §6, C-UI-9).
const String appRepositoryUrl =
    'https://github.com/clevebitr/legado-with-flutter';
