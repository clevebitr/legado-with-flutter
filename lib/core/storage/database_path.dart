import 'dart:io';

/// File name of the on-disk database (`docs/dev/platform.md` §5).
const String databaseFileName = 'reader.db';

/// Returns the database path inside [directory] (`docs/dev/platform.md` §5).
///
/// 用 `Uri` 解析而不是字符串拼接：`platform.md` §5 禁止手写平台分隔符。
String databasePathIn(Directory directory) =>
    directory.uri.resolve(databaseFileName).toFilePath();
