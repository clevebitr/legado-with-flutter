import 'dart:io';

/// File name of the on-disk database.
const String databaseFileName = 'reader.db';

/// Returns the database path inside [directory].
///
/// 用 `Uri` 解析而不是字符串拼接，避免手写平台分隔符。
String databasePathIn(Directory directory) =>
    directory.uri.resolve(databaseFileName).toFilePath();
