import 'dart:io';

/// Resolves the app's support directory (the root every stored image lives under).
typedef SupportDirectory = Future<Directory> Function();

/// Extensions a stored image may keep; anything else falls back to no extension.
///
/// The image is decoded by content, never by suffix, so the extension only helps a human (or a
/// future export) recognise the file. It is a whitelist rather than a copy of the user's suffix
/// because the suffix arrives from a file dialog and must not decide a path.
const Set<String> _imageExtensions = <String>{
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
};

/// Stores one user-picked image inside the app's own directory
/// (`docs/dev/roadmap.md` M22, ADR-0075 §决策 1).
///
/// Copying instead of remembering the picked path is the point: a path into the user's gallery stops
/// working when the file moves, when an Android URI grant expires, or when the folder is unmounted.
/// The store keeps the bytes and answers a **relative name**, which is what the settings file holds.
final class LocalImageStore {
  /// Creates the store.
  ///
  /// `supportDirectory` is required rather than defaulted: the provider wires `path_provider` in, so
  /// this file stays free of the plugin and a test can hand in a temporary folder.
  const LocalImageStore({required this._supportDirectory});

  final SupportDirectory _supportDirectory;

  /// Writes [bytes] as `<folder>/<name>` and answers the stored name.
  ///
  /// A same-named file is replaced: the settings hold one background image, so「换一张」should not
  /// leave the previous one behind.
  Future<String> save({
    required String folder,
    required String name,
    required List<int> bytes,
  }) async {
    final Directory directory = await _folderOf(folder);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final String safeName = imageFileName(name);
    await File('${directory.path}${Platform.pathSeparator}$safeName')
        .writeAsBytes(bytes, flush: true);

    return safeName;
  }

  /// The absolute path of `<folder>/<name>`, or `null` when the file is gone.
  ///
  /// A `null` answer is normal (the user removed the file, or restored a backup whose image is not
  /// on this device); callers fall back to a plain background instead of failing.
  Future<String?> pathOf({required String folder, required String name}) async {
    final Directory directory = await _folderOf(folder);
    final File file = File('${directory.path}${Platform.pathSeparator}$name');

    return file.existsSync() ? file.path : null;
  }

  /// Removes `<folder>/<name>`, if present.
  Future<void> delete({required String folder, required String name}) async {
    final File file = File(
      '${(await _folderOf(folder)).path}${Platform.pathSeparator}$name',
    );
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<Directory> _folderOf(String folder) async => Directory(
    '${(await _supportDirectory()).path}${Platform.pathSeparator}$folder',
  );
}

/// The file name an image is stored under: the stem with any unsafe character replaced.
///
/// The value comes from a file dialog, so it is treated as untrusted input: path separators and
/// control characters would otherwise be able to write outside the folder.
String imageFileName(String name) {
  final String extension = imageExtensionOf(name);
  // 只剩扩展名（`.png`）时 stem 为空：下面会回落到 `image`。
  final String stem = name.length > extension.length
      ? name.substring(0, name.length - extension.length)
      : '';
  final String safeStem = stem
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      // 前导下划线/连字符来自 `../` 之类的前缀：去掉它，避免生成 `_evil`。
      .replaceFirst(RegExp(r'^[_-]+'), '');

  return '${safeStem.isEmpty ? 'image' : safeStem}$extension';
}

/// The whitelisted extension of [name] in lower case, or the empty string.
String imageExtensionOf(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot < 0) {
    return '';
  }
  final String extension = name.substring(dot).toLowerCase();

  return _imageExtensions.contains(extension) ? extension : '';
}
