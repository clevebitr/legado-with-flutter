import 'dart:typed_data';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the platform share sheet for `files` (`ADR-0083`).
///
/// The plugin writes in-memory files to its own cache directory and grants the receiving app a
/// temporary read URI on Android, so no storage permission is involved. `share` exists so tests
/// can answer a share result without a platform channel.
typedef ShareInvoker = Future<ShareResult> Function(ShareParams params);

/// [FileSharer] backed by `share_plus`.
///
/// A dismissed sheet answers `ParseSuccess(false)`; a thrown plugin error travels as a
/// [ParseFailure] with `rulePath: 'share'`.
final class SharePlusFileSharer implements FileSharer {
  /// Creates the adapter; [share] defaults to the real plugin.
  SharePlusFileSharer({ShareInvoker? share})
    : _share = share ?? _shareWithPlugin;

  final ShareInvoker _share;

  static Future<ShareResult> _shareWithPlugin(ShareParams params) =>
      SharePlus.instance.share(params);

  @override
  bool get isSupported => true;

  @override
  Future<ParseResult<bool>> share(
    List<ShareableFile> files, {
    String? subject,
  }) async {
    if (files.isEmpty) {
      return const ParseSuccess<bool>(false);
    }

    try {
      final ShareResult result = await _share(
        ShareParams(
          files: <XFile>[
            for (final ShareableFile file in files) _asXFile(file),
          ],
          fileNameOverrides: <String>[
            for (final ShareableFile file in files) file.name,
          ],
          subject: subject,
        ),
      );

      // `unavailable` 只表示平台不回报「用户选了哪个目标」，分享面板本身已经出现过；
      // 只有明确取消才算没有分享（ADR-0083 §决策 3）。
      return ParseSuccess<bool>(result.status != ShareResultStatus.dismissed);
    } on Exception {
      return failureAt<bool>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'share',
      );
    }
  }

  static XFile _asXFile(ShareableFile file) {
    final String? path = file.path;
    if (path != null) {
      return XFile(path, name: file.name, mimeType: file.mimeType);
    }

    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      // 两个工厂都保证 path 与 bytes 恰有一个非空，走到这里说明类型被改坏了。
      throw ArgumentError.value(file.name, 'file', 'needs a path or bytes');
    }

    return XFile.fromData(bytes, name: file.name, mimeType: file.mimeType);
  }
}
