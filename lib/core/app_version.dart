/// The application version, mirroring `version` in `pubspec.yaml`.
///
/// It goes into the backup manifest so a support question can say which build wrote an archive.
/// A constant instead of a `package_info_plus` dependency: one metadata string does not justify a
/// plugin that ships native code on three platforms.
///
/// `test/core/app_version_test.dart` reads `pubspec.yaml` and fails when the two disagree, so this
/// is a mirror with a guard, not a second source of truth.
const String appVersion = '0.1.0+1';
