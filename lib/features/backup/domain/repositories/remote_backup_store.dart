import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/backup/domain/entities/stored_backup.dart';

/// The cloud side of the backup: one WebDAV collection holding the same archives
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 6).
///
/// Only four actions exist — list, upload, download, delete — because the product decision is
/// 「备份文件可以放到 WebDAV」, not 「阅读进度在云端同步」. Failures are [ParseResult]s so the page can
/// tell 「没配置」 from 「服务器拒绝」.
abstract interface class RemoteBackupStore {
  /// Whether the URL and user name are configured (the password may still be missing).
  Future<bool> isConfigured();

  /// Lists the archives in the configured collection, newest first.
  Future<ParseResult<List<RemoteBackup>>> list();

  /// Uploads one archive under [name].
  Future<ParseResult<void>> upload({
    required String name,
    required List<int> bytes,
  });

  /// Downloads [backup].
  Future<ParseResult<List<int>>> download(RemoteBackup backup);

  /// Deletes [backup].
  Future<ParseResult<void>> delete(RemoteBackup backup);

  /// Keeps the newest [keep] archives remotely, deleting the rest of ours.
  Future<ParseResult<int>> prune({required int keep});
}
