/// The application version the build reports (`ADR-0067` §决策 2).
///
/// CI composes the version per channel and passes it as
/// `--dart-define=APP_VERSION=<pubspec version>[-beta.<sha7> | -debug.<sha7>.<stamp>]`
/// (`.github/workflows/build-artifacts.yml`); this constant is where the app reads it, so the
/// version shown in「关于」and written into a backup manifest is the one the artifact was built
/// under, not a hand-maintained copy.
///
/// A local `flutter run` / `flutter test` has no define, so the default mirrors `pubspec.yaml`;
/// `test/core/app_version_test.dart` reads that file and fails when the two disagree, which keeps
/// the fallback honest without a `package_info_plus` dependency.
const String appVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: '0.2.0+1',
);
