import 'package:flutter_reader/core/storage/database_path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_path_provider.g.dart';

/// Provides the on-disk database path: `<application support>/reader.db`
/// (`docs/dev/platform.md` §5).
///
/// The platform lookup is isolated here so tests can assert the resolved path
/// without opening a file database: they fake the `path_provider` channel
/// instead of touching the real application directory.
@Riverpod(keepAlive: true)
Future<String> databaseFilePath(Ref ref) async =>
    databasePathIn(await getApplicationSupportDirectory());
