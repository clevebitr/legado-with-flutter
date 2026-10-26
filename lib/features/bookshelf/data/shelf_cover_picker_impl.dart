import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_reader/core/di/database_path_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/cover_file_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_cover_file_picker.dart';
import 'package:flutter_reader/features/bookshelf/domain/repositories/shelf_cover_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shelf_cover_picker_impl.g.dart';

/// The largest image a cover may be (`docs/dev/roadmap.md` M19, ADR-0066 §决策 5).
///
/// Covers are watched on a phone: 8 MiB is far above a normal cover (a few hundred kilobytes) and
/// far below the point where copying one would be noticeable. A bigger file is refused instead of
/// copied.
const int maxCoverBytes = 8 * 1024 * 1024;

/// [ShelfCoverPicker] backed by the platform dialog plus the app's support directory.
///
/// Everything decidable without a dialog lives here (and is unit-tested): the size cap, the file
/// name, the directory and what a cancelled pick means.
final class ShelfCoverPickerImpl implements ShelfCoverPicker {
  /// Creates the picker; the first argument answers the app's private directory.
  const ShelfCoverPickerImpl(
    this._supportDirectory,
    this._picker,
    this._logger,
  );

  final Future<Directory> Function() _supportDirectory;
  final CoverFilePicker _picker;
  final AppLogger _logger;

  /// The sub-directory covers live in, inside the app's support directory.
  static const String coverDirectory = 'covers';

  @override
  Future<String?> pickAndStore() async {
    final PickedCoverFile? picked = await _picker.pick();
    if (picked == null) {
      return null;
    }
    if (picked.bytes.length > maxCoverBytes) {
      // 体积超限不抛异常：换封面是用户的一次操作，页面只需要知道「没换」。
      _logger.warning(
        'A cover was not stored because it is larger than the limit:'
        ' ${picked.bytes.length} bytes.',
      );

      return null;
    }
    final Directory root = await _supportDirectory();
    // 用 `Uri` 解析路径而不是拼分隔符，与 `databasePathIn` 同一条理由（platform.md §5）。
    final Directory target = Directory(
      root.uri.resolve('$coverDirectory/').toFilePath(),
    );
    await target.create(recursive: true);
    // 文件名用内容摘要：同一张图重复选用不会堆出多份，且不把用户的原文件名写进路径。
    final String digest = sha256.convert(picked.bytes).toString();
    final String path = target.uri
        .resolve('$digest${_extensionOf(picked.name)}')
        .toFilePath();
    final File file = File(path);
    // `existsSync` / `deleteSync` 是有意为之：这是用户点一次按钮才发生的一次 IO，await 的
    // 线程切换比 stat/删除本身更贵（`avoid_slow_async_io` 的判据是热路径，这里不是）。
    if (!file.existsSync()) {
      await file.writeAsBytes(picked.bytes, flush: true);
    }

    return path;
  }

  @override
  Future<void> delete(String path) async {
    final File file = File(path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// The lower-cased extension of [name] including the dot, or `.img` when it has none.
  ///
  /// The extension never decides how the bytes are decoded (Flutter sniffs the header), it only
  /// keeps the file recognisable for a human looking at the app's directory.
  String _extensionOf(String name) {
    final int dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) {
      return '.img';
    }

    return name.substring(dot).toLowerCase();
  }
}

/// Provides the cover picker of the shelf feature (`docs/dev/roadmap.md` M19).
///
/// The directory is resolved lazily per pick, because a provider that awaited `path_provider` would
/// make the shelf page depend on a platform channel just to render.
@Riverpod(keepAlive: true)
ShelfCoverPicker shelfCoverPicker(Ref ref) => ShelfCoverPickerImpl(
  // 目录从数据库路径推导：`databaseFilePath` 已经是「应用私有支持目录 / reader.db」，
  // 取它的父目录就得到同一份目录（卸载即清理，不会是用户可见的相册），不必再引一个平台通道。
  () async => File(await ref.read(databaseFilePathProvider.future)).parent,
  const PlatformCoverFilePicker(),
  ref.watch(appLoggerProvider),
);
