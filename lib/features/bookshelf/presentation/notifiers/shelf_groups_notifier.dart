import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_group.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shelf_groups_notifier.g.dart';

/// The failure reported when a group could not be created or renamed as asked.
///
/// A duplicate or blank name is an ordinary outcome (the page shows a message), not an exception;
/// `rulePath` names the write so a log line points at it (C-ERR-7, C-SRC-8).
const ParseFailure<void> shelfGroupWriteFailure = ParseFailure<void>(
  kind: ParseFailureKind.invalidBookSource,
  rulePath: 'shelf.groups',
);

/// The shelf groups, and the only place that creates, renames, deletes or reorders them
/// (`docs/dev/roadmap.md` M19, ADR-0066 §决策 2).
///
/// `keepAlive` for the same reason as the shelf: the chip row reads it on every visit. Every
/// mutation reloads the group list **and** invalidates the shelf, because deleting a group changes
/// `books.groupId` for the books that were in it.
@Riverpod(keepAlive: true)
class ShelfGroups extends _$ShelfGroups {
  @override
  Future<List<ShelfGroup>> build() =>
      ref.watch(bookshelfRepositoryProvider).getGroups();

  /// Creates a group named [name]; a blank or duplicate name answers the failure value.
  Future<ParseResult<void>> create(String name) async {
    try {
      final ShelfGroup? created = await ref
          .read(bookshelfRepositoryProvider)
          .createGroup(name);
      if (created == null) {
        return shelfGroupWriteFailure;
      }
    } on Exception catch (error, stackTrace) {
      return _failed(error, stackTrace);
    }
    await _reload();

    return const ParseResult<void>.success(null);
  }

  /// Renames group [id]; a blank or duplicate name answers the failure value.
  Future<ParseResult<void>> rename({
    required int id,
    required String name,
  }) async {
    try {
      final bool renamed = await ref
          .read(bookshelfRepositoryProvider)
          .renameGroup(id: id, name: name);
      if (!renamed) {
        return shelfGroupWriteFailure;
      }
    } on Exception catch (error, stackTrace) {
      return _failed(error, stackTrace);
    }
    await _reload();

    return const ParseResult<void>.success(null);
  }

  /// Deletes group [id]; its books stay on the shelf as 「未分组」.
  Future<ParseResult<void>> delete(int id) async {
    try {
      await ref.read(bookshelfRepositoryProvider).deleteGroup(id);
    } on Exception catch (error, stackTrace) {
      return _failed(error, stackTrace);
    }
    // 删组会把组内书的 `group_id` 清空，所以书架必须重读，否则 chip 与行数据会短暂不一致。
    ref.invalidate(bookshelfProvider);
    await _reload();

    return const ParseResult<void>.success(null);
  }

  /// Writes the normalized display order of [ids].
  Future<ParseResult<void>> reorder(List<int> ids) async {
    try {
      await ref.read(bookshelfRepositoryProvider).reorderGroups(ids);
    } on Exception catch (error, stackTrace) {
      return _failed(error, stackTrace);
    }
    await _reload();

    return const ParseResult<void>.success(null);
  }

  /// Logs one unexpected storage failure and answers the shared failure value.
  ParseResult<void> _failed(Exception error, StackTrace stackTrace) {
    ref
        .read(appLoggerProvider)
        .warning('Writing the shelf groups failed.', error, stackTrace);

    return shelfGroupWriteFailure;
  }

  /// Re-reads the groups and publishes them.
  Future<void> _reload() async {
    state = await AsyncValue.guard<List<ShelfGroup>>(
      () => ref.read(bookshelfRepositoryProvider).getGroups(),
    );
  }
}
