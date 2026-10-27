import 'package:flutter_reader/core/js/source_login_header.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/cache_failure_absorber.dart';

/// [SourceLoginHeaderRepository] backed by the `book_sources.login_header` column (M25/S3b).
///
/// Every operation goes through [absorbCacheFailure]: a lost login header costs one re-login, and a
/// `@js:` rule must not fail over it (the same stance as the per-source variables).
final class SourceLoginHeaderDaoRepository
    implements SourceLoginHeaderRepository {
  /// Creates the repository.
  const SourceLoginHeaderDaoRepository(this._dao, {required this._logger});

  final BookSourceDao _dao;
  final AppLogger _logger;

  // 稳定字符串，便于在日志中检索。
  static const String _scope = 'Source login header';

  @override
  Future<String?> read(String sourceUrl) => absorbCacheFailure<String?>(
    () => _dao.findLoginHeaderByUrl(sourceUrl),
    logger: _logger,
    scope: _scope,
    url: sourceUrl,
  );

  @override
  Future<void> write(String sourceUrl, String? header) async {
    await absorbCacheFailure<int>(
      () =>
          _dao.writeLoginHeaderByUrl(sourceUrl: sourceUrl, loginHeader: header),
      logger: _logger,
      scope: _scope,
      url: sourceUrl,
    );
  }
}
