import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/book_source_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_dialog.dart';

/// [BookSourceFilePicker] backed by `file_selector` (the Flutter team's federated plugin).
///
/// The platform call is injected through `opener` so the read, the cap and the BOM handling are
/// ordinary, testable Dart: only `fileSelectorOpenJsonFile` touches a platform channel, and that is
/// the one file the coverage gate exempts (ADR-0019's second category).
final class FileSelectorBookSourceFilePicker implements BookSourceFilePicker {
  /// Creates the picker.
  ///
  /// `opener` defaults to the real dialog; a test passes its own to exercise the logic without a
  /// channel.
  const FileSelectorBookSourceFilePicker({
    this._opener = fileSelectorOpenJsonFile,
  });

  final BookSourceFileOpener _opener;

  @override
  Future<ParseResult<String?>> pick({required int maxBytes}) async {
    final PickedBookSourceFile? file = await _opener();
    if (file == null) {
      // 用户取消：不是失败，也不该被当成「读了空文件」去解析。
      return const ParseSuccess<String?>(null);
    }

    // 先看体积再读字节：超限的文件**根本不会**进内存（C-SEC-5、C-PERF-5）。
    if (file.bytes.length > maxBytes) {
      return failureAt<String?>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'import.sizeLimit',
      );
    }

    return ParseSuccess<String?>(_decode(file.bytes));
  }

  /// Decodes the file as UTF-8 and strips a byte-order mark.
  ///
  /// Legado writes its exports as UTF-8, and some editors leave a BOM in front; `jsonDecode` would
  /// fail on it, so it is removed here rather than reported as a malformed file.
  String _decode(List<int> bytes) {
    final String text = utf8.decode(bytes, allowMalformed: true);

    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  }
}
