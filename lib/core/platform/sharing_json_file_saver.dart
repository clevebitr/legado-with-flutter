import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:flutter_reader/core/platform/json_file_saver.dart';

// 私有字段不能做具名初始化形参（Dart 限制）。
// ignore_for_file: prefer_initializing_formals

/// [JsonFileSaver] that hands the document to the system share sheet.
///
/// Mobile platforms have no save dialog (`file_selector` cannot implement `getSaveLocation` on
/// Android or iOS), so exporting a source or a replace-rule file used to answer “not saved”. The
/// share sheet also lets the user write the document into Files / Drive / another app, which is the
/// only way out of the app's private directory on Android (`ADR-0083` §决策 1).
final class SharingJsonFileSaver implements JsonFileSaver {
  /// Creates the saver on top of [sharer].
  const SharingJsonFileSaver({required FileSharer sharer}) : _sharer = sharer;

  final FileSharer _sharer;

  @override
  Future<ParseResult<bool>> save({
    required String suggestedName,
    required String contents,
  }) {
    if (!_sharer.isSupported) {
      return Future<ParseResult<bool>>.value(const ParseSuccess<bool>(false));
    }

    return _sharer.share(<ShareableFile>[
      ShareableFile.inMemory(
        name: suggestedName,
        mimeType: 'application/json',
        bytes: utf8.encode(contents),
      ),
    ]);
  }
}
