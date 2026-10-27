import 'dart:convert';

import 'package:flutter_reader/core/js/source_login_info.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/cache_failure_absorber.dart';

/// [SourceLoginInfoWriter] backed by the `book_sources.login_info` column (M25/S5a).
///
/// The column holds the JSON **map** the login form reads back (`BookSourceRepository.loginInfoOf`),
/// so a write serialises the map exactly the way the form does. Failure is absorbed like the login
/// header's: a rule must not fail because a login form's values could not be stored.
final class SourceLoginInfoDaoRepository implements SourceLoginInfoWriter {
  /// Creates the repository.
  const SourceLoginInfoDaoRepository(this._dao, {required this._logger});

  final BookSourceDao _dao;
  final AppLogger _logger;

  // 稳定字符串，便于在日志中检索。
  static const String _scope = 'Source login info';

  @override
  Future<void> write(String sourceUrl, Map<String, String>? info) async {
    final String? text = info == null || info.isEmpty ? null : jsonEncode(info);
    await absorbCacheFailure<int>(
      () => _dao.writeLoginInfoByUrl(sourceUrl: sourceUrl, loginInfo: text),
      logger: _logger,
      scope: _scope,
      url: sourceUrl,
    );
  }
}
