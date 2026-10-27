import 'dart:typed_data';

import 'package:flutter_reader/core/error/parse_result.dart';

// 私有字段不能做具名初始化形参（Dart 限制）。
// ignore_for_file: prefer_initializing_formals

/// One file handed to the system share sheet.
///
/// A file is either already on disk ([ShareableFile.onDisk]) or lives only in memory
/// ([ShareableFile.inMemory]). Keeping both shapes in one type lets the log page share files
/// without reading them into memory while exports share bytes they already have.
final class ShareableFile {
  /// Describes a file that already exists at [path].
  const ShareableFile.onDisk({
    required this.name,
    required this.mimeType,
    required String path,
  }) : _path = path,
       _bytes = null;

  /// Describes a file whose bytes are already in memory.
  ShareableFile.inMemory({
    required this.name,
    required this.mimeType,
    required List<int> bytes,
  }) : _path = null,
       // utf8.encode 与备份编解码通常已经给出 Uint8List：能复用就不复制。
       _bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  /// The file name the receiving app sees.
  final String name;

  /// The MIME type the receiving app uses to decide how to open the file.
  final String mimeType;

  final String? _path;
  final Uint8List? _bytes;

  /// The absolute path when this file is on disk, or `null` for an in-memory file.
  String? get path => _path;

  /// The bytes when this file lives in memory, or `null` for an on-disk file.
  Uint8List? get bytes => _bytes;
}

/// Hands files to the platform's share sheet (Android `ACTION_SEND`, iOS
/// `UIActivityViewController`, Windows share UI).
///
/// This is the mobile escape hatch for private application directories: an exported book source,
/// a backup archive or a log file under the app's support directory cannot be reached by a file
/// manager on Android, but a share sends a copy to whichever app the user picks.
///
/// Platforms without a share sheet answer [isSupported] `false` instead of throwing.
abstract interface class FileSharer {
  /// Whether this platform can show a share sheet.
  bool get isSupported;

  /// Offers [files] to the user, answering whether a share was actually started.
  ///
  /// Dismissing the sheet answers `ParseSuccess(false)` (a cancel, not a failure); a platform
  /// error answers a [ParseFailure].
  Future<ParseResult<bool>> share(List<ShareableFile> files, {String? subject});
}

/// The fallback for a platform with no share sheet: it answers “not shared”.
final class UnsupportedFileSharer implements FileSharer {
  /// Creates the fallback.
  const UnsupportedFileSharer();

  @override
  bool get isSupported => false;

  @override
  Future<ParseResult<bool>> share(
    List<ShareableFile> files, {
    String? subject,
  }) async => const ParseSuccess<bool>(false);
}
