import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/background_image_picker.dart';
import 'package:flutter_reader/core/storage/local_image_store.dart';
import 'package:flutter_reader/features/settings/di.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_notifier.g.dart';

/// The failure reported when the background image could not be stored.
const ParseFailure<bool> backgroundImageFailure = ParseFailure<bool>(
  kind: ParseFailureKind.parseFailed,
  rulePath: 'settings.backgroundImage',
);

/// The failure reported when clearing the cache did not complete.
///
/// No user-visible text (C-ERR-7); the page maps the kind to ARB and the log line names the
/// table through `rulePath`.
const ParseFailure<int> cachePurgeFailure = ParseFailure<int>(
  kind: ParseFailureKind.parseFailed,
  rulePath: 'cache.purgeAll',
);

/// The user's settings and the only place that writes them (`docs/dev/roadmap.md` 5.6)。
///
/// `keepAlive` because the theme and the text scale are read on every rebuild of the root widget;
/// re-reading `shared_preferences` for each of those would be a platform call per frame.
@Riverpod(keepAlive: true)
class Settings extends _$Settings {
  @override
  Future<AppSettings> build() async =>
      (await ref.watch(settingsRepositoryProvider.future)).load();

  /// Switches the theme mode.
  Future<void> setThemeMode(AppThemeMode mode) =>
      _update((AppSettings current) => current.copyWith(themeMode: mode));

  /// Sets the default text scale; the value is clamped by [AppSettings] itself.
  Future<void> setFontScale(double scale) =>
      _update((AppSettings current) => current.copyWith(fontScale: scale));

  /// Sets the per-source concurrency budget; the value is clamped by [AppSettings] itself.
  Future<void> setMaxConcurrentPerSource(int budget) => _update(
    (AppSettings current) => current.copyWith(maxConcurrentPerSource: budget),
  );

  /// Sets the theme seed colour (`ADR-0075` §决策 1); `null` restores the project default.
  Future<void> setSeedColor(int? color) => _update(
    (AppSettings current) =>
        current.copyWith(seedColor: color, clearSeedColor: color == null),
  );

  /// Asks for an image, copies it into the app, and makes it the theme background.
  ///
  /// Answers `false` when the user cancelled and a [ParseFailure] when the copy failed; the previous
  /// image is removed only after the new one is stored, so a failed pick never leaves the theme
  /// pointing at a missing file.
  Future<ParseResult<bool>> pickBackgroundImage() async {
    final PickedBackgroundImage? picked = await ref
        .read(backgroundImagePickerProvider)
        .pick();
    if (picked == null) {
      return const ParseSuccess<bool>(false);
    }

    try {
      final LocalImageStore store = ref.read(localImageStoreProvider);
      final String? previous = state.value?.backgroundImageName;
      final String name = await store.save(
        folder: backgroundImageFolder,
        // 固定名 + 源扩展名：设置里只有一张背景图，「换一张」应该替换而不是堆积。
        name: 'background${imageExtensionOf(picked.name)}',
        bytes: picked.bytes,
      );
      if (previous != null && previous != name) {
        await store.delete(folder: backgroundImageFolder, name: previous);
      }
      await _update(
        (AppSettings current) => current.copyWith(backgroundImageName: name),
      );

      return const ParseSuccess<bool>(true);
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('Storing the background image failed.', error, stackTrace);

      return backgroundImageFailure;
    }
  }

  /// Removes the theme background (the stored file goes too).
  Future<void> removeBackgroundImage() async {
    final String? name = state.value?.backgroundImageName;
    if (name != null) {
      await ref
          .read(localImageStoreProvider)
          .delete(folder: backgroundImageFolder, name: name);
    }
    await _update(
      (AppSettings current) => current.copyWith(clearBackgroundImage: true),
    );
  }

  /// Turns the plaintext-HTTP opt-in on or off (C-SEC-2).
  Future<void> setAllowPlainHttp(bool allow) =>
      _update((AppSettings current) => current.copyWith(allowPlainHttp: allow));

  /// Empties the cache tables and answers how many entries went away.
  Future<ParseResult<int>> clearCache() async {
    try {
      final int removed = await ref.read(cachePurgerProvider).purgeAll();

      return ParseSuccess<int>(removed);
    } on Exception catch (error, stackTrace) {
      // C-ERR-2 的 presentation 兜底：记一条并转成失败态，不吞、不抛给用户。
      ref
          .read(appLoggerProvider)
          .warning('Clearing the cache failed.', error, stackTrace);

      return cachePurgeFailure;
    }
  }

  /// Applies [change] to the current settings and stores the result.
  ///
  /// The state is updated **after** the write, and with the clamped value the repository was
  /// given, so the UI never shows a value that was not stored (`docs/dev/roadmap.md` 5.6).
  Future<void> _update(AppSettings Function(AppSettings current) change) async {
    final AppSettings current = state.value ?? AppSettings.defaults;
    final AppSettings next = change(current);
    await (await ref.read(settingsRepositoryProvider.future)).save(next);
    state = AsyncData<AppSettings>(next);
  }
}
