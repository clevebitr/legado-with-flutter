import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/repositories/reader_settings_repository.dart';

/// `shared_preferences` key of the body text scale.
///
/// Keys are private to this file: the storage layout is an implementation detail, and a key
/// spelled anywhere else would be a second source for it (`docs/dev/roadmap.md` §6 #9).
const String _fontScaleKey = 'reader.fontScale';

/// `shared_preferences` key of the line height multiplier.
const String _lineHeightKey = 'reader.lineHeight';

/// `shared_preferences` key of the background palette index.
const String _backgroundKey = 'reader.background';

/// `shared_preferences` key of the page mode index.
const String _pageModeKey = 'reader.pageMode';

/// [ReaderSettingsRepository] on top of [PreferenceStore] (`docs/dev/roadmap.md` 5.3, C-NET-9).
///
/// Every read is defensive: an unknown enum index (a store written by a newer build, or a
/// hand-edited file) falls back to that setting's default instead of indexing out of range, and a
/// wrong type falls back too — `PreferenceStore` narrows rather than casts for the same reason.
final class ReaderSettingsRepositoryImpl implements ReaderSettingsRepository {
  /// Creates the repository.
  const ReaderSettingsRepositoryImpl({required this._store});

  final PreferenceStore _store;

  @override
  Future<ReaderSettings> load() async => ReaderSettings(
    fontScale: _store.readDouble(_fontScaleKey) ?? defaultReaderFontScale,
    lineHeight: _store.readDouble(_lineHeightKey) ?? defaultReaderLineHeight,
    background: _backgroundOf(_store.readInt(_backgroundKey)),
    pageMode: _pageModeOf(_store.readInt(_pageModeKey)),
  );

  @override
  Future<void> save(ReaderSettings settings) async {
    // 存的是**钳制后**的值：读回来的永远是 UI 能表示的范围（与 `SettingsRepositoryImpl` 同口径）。
    await _store.writeDouble(_fontScaleKey, settings.fontScale);
    await _store.writeDouble(_lineHeightKey, settings.lineHeight);
    await _store.writeInt(_backgroundKey, settings.background.index);
    await _store.writeInt(_pageModeKey, settings.pageMode.index);
  }

  /// Maps a stored index onto [ReaderBackground], defaulting when it names nothing.
  ReaderBackground _backgroundOf(int? stored) {
    if (stored == null ||
        stored < 0 ||
        stored >= ReaderBackground.values.length) {
      return ReaderBackground.system;
    }

    return ReaderBackground.values[stored];
  }

  /// Maps a stored index onto [ReaderPageMode], defaulting when it names nothing.
  ReaderPageMode _pageModeOf(int? stored) {
    if (stored == null ||
        stored < 0 ||
        stored >= ReaderPageMode.values.length) {
      return ReaderPageMode.scroll;
    }

    return ReaderPageMode.values[stored];
  }
}
