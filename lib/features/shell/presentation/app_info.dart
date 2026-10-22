/// The app's identity, shown by the about page (`docs/dev/roadmap.md` §3.11, ADR-0055 §决策 4).
///
/// `version` is a hand-kept copy of `pubspec.yaml`'s `version` (without the build number): reading
/// the manifest at runtime would need a platform plugin, and one more dependency is not worth one
/// string (C-DEP-1). `app_info_test.dart` reads `pubspec.yaml` and fails when the two drift.
const String appVersion = '0.1.0';

/// Where the Corresponding Source of this build is published (GPL-3.0 §6, C-UI-9).
const String appRepositoryUrl =
    'https://github.com/clevebitr/legado-with-flutter';
