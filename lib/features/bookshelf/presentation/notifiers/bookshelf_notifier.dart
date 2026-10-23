import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/bookshelf/di.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bookshelf_notifier.g.dart';

/// The failure reported when a shelf write could not be stored.
///
/// It carries no user-visible text (C-ERR-7) and names the entry in `rulePath`, so a log line
/// points at what was being written (C-SRC-8 的同一条理由：失败必须可定位）。
const ParseFailure<void> shelfWriteFailure = ParseFailure<void>(
  kind: ParseFailureKind.parseFailed,
  rulePath: 'shelf.entry',
);

/// The shelf, and the only place that changes it (`docs/dev/roadmap.md` 5.4)。
///
/// `keepAlive` for the same reason as the source list: the shelf is read on every visit and a
/// reload after each mutation is an explicit decision, while the writes below are the only
/// writers (C-STATE-6: the state itself stays an immutable list).
///
/// The mutations answer [ParseResult] instead of throwing, because the shelf is written from
/// another feature through `BookshelfWriter` (ADR-0041 §决策 2) and that port has to report a
/// failure without turning it into an exception.
@Riverpod(keepAlive: true)
class Bookshelf extends _$Bookshelf {
  @override
  Future<List<ShelvedBook>> build() =>
      ref.watch(bookshelfRepositoryProvider).getAll();

  /// Puts [candidate] on the shelf, or refreshes it when it is already there.
  Future<ParseResult<void>> add(ShelfCandidate candidate) =>
      _write(() => ref.read(bookshelfRepositoryProvider).add(candidate));

  /// Writes the two user-state columns of entry [id].
  Future<ParseResult<void>> updateUserState({
    required int id,
    required ShelfStatus status,
    required bool isPinned,
  }) => _write(
    () => ref
        .read(bookshelfRepositoryProvider)
        .updateUserState(id: id, status: status, isPinned: isPinned),
  );

  /// Deletes entry [id] and its reading progress.
  Future<ParseResult<void>> remove(int id) =>
      _write(() => ref.read(bookshelfRepositoryProvider).remove(id));

  /// Runs one repository write, absorbs failures, and reloads the shelf afterwards.
  ///
  /// The catch is the `presentation` boundary C-ERR-2 allows (`on Exception`, logged, converted
  /// to a failure state); `Error` keeps travelling (ADR-0022). Reloading after a write is what
  /// makes the page show the stored order rather than the order the page hoped for.
  Future<ParseResult<void>> _write(Future<void> Function() action) async {
    try {
      await action();
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('Writing the shelf failed.', error, stackTrace);

      return shelfWriteFailure;
    }

    await _reload();

    return const ParseResult<void>.success(null);
  }

  /// Re-reads the shelf and publishes it.
  ///
  /// Reading the repository directly (instead of `invalidateSelf` + `ref.read(self.future)`) is
  /// what Riverpod allows inside a notifier — a provider may not depend on itself — and the
  /// guard keeps a failed reload an error state instead of an exception.
  Future<void> _reload() async {
    state = await AsyncValue.guard<List<ShelvedBook>>(
      () => ref.read(bookshelfRepositoryProvider).getAll(),
    );
  }
}
