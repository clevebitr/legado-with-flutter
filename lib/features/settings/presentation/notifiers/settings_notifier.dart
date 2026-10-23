import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/settings/di.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_notifier.g.dart';

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
