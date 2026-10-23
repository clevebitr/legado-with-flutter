import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';

/// Persistence for the reader's own settings (`docs/dev/roadmap.md` 5.3, C-NET-9).
///
/// The port is total, like `SettingsRepository`: a missing or wrong-typed stored value answers
/// with that one setting's default instead of a failure, because "the reader opens with sane
/// typography" is the whole point. The clamping itself happens in [ReaderSettings].
///
/// 本文件只有抽象方法签名（无可测量行），已按 ADR-0019 §2 登记在 `tool/coverage_allowlist.txt`；
/// 契约由 `ReaderSettingsRepositoryImpl` 与其测试行使。
abstract interface class ReaderSettingsRepository {
  /// The stored reader settings, clamped into their documented ranges.
  Future<ReaderSettings> load();

  /// Stores [settings]; a partial write leaves the store consistent because every key is
  /// independent and read back on the next load.
  Future<void> save(ReaderSettings settings);
}
