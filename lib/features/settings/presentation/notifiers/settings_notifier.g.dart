// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's settings and the only place that writes them (`docs/dev/roadmap.md` 5.6)。
///
/// `keepAlive` because the theme and the text scale are read on every rebuild of the root widget;
/// re-reading `shared_preferences` for each of those would be a platform call per frame.

@ProviderFor(Settings)
final settingsProvider = SettingsProvider._();

/// The user's settings and the only place that writes them (`docs/dev/roadmap.md` 5.6)。
///
/// `keepAlive` because the theme and the text scale are read on every rebuild of the root widget;
/// re-reading `shared_preferences` for each of those would be a platform call per frame.
final class SettingsProvider
    extends $AsyncNotifierProvider<Settings, AppSettings> {
  /// The user's settings and the only place that writes them (`docs/dev/roadmap.md` 5.6)。
  ///
  /// `keepAlive` because the theme and the text scale are read on every rebuild of the root widget;
  /// re-reading `shared_preferences` for each of those would be a platform call per frame.
  SettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsHash();

  @$internal
  @override
  Settings create() => Settings();
}

String _$settingsHash() => r'c5d6a85a0f9f1916d7d00ffcd9e6a31e1265575b';

/// The user's settings and the only place that writes them (`docs/dev/roadmap.md` 5.6)。
///
/// `keepAlive` because the theme and the text scale are read on every rebuild of the root widget;
/// re-reading `shared_preferences` for each of those would be a platform call per frame.

abstract class _$Settings extends $AsyncNotifier<AppSettings> {
  FutureOr<AppSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AppSettings>, AppSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppSettings>, AppSettings>,
              AsyncValue<AppSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
