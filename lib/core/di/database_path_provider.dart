import 'package:flutter_reader/core/storage/database_path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_path_provider.g.dart';

/// Provides the on-disk database path: `<application support>/reader.db`.
///
/// Isolated so tests can fake the platform lookup without opening a database.
@Riverpod(keepAlive: true)
Future<String> databaseFilePath(Ref ref) async =>
    databasePathIn(await getApplicationSupportDirectory());
