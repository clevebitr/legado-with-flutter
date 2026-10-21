import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The books the user put on the shelf (`docs/dev/roadmap.md` 5.4).
///
/// The rows are managed here and nowhere else: pinning, the tracking / finished switch and
/// deletion are the user state the shelf owns. Opening a book happens in the reader, which is
/// 5.3's move, so a row is deliberately **not** tappable yet — a button that does nothing would
/// be a dead end (C-BAN-2).
///
/// Accessibility (C-UI-7): each row is a [ListTile] (label from its own text) and the menu
/// button carries the row title in its tooltip.
class BookshelfPage extends ConsumerWidget {
  /// Creates the page.
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<ShelvedBook>> shelf = ref.watch(bookshelfProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.shelfTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (shelf) {
        AsyncData<List<ShelvedBook>>(:final List<ShelvedBook> value) =>
          value.isEmpty
              ? StateMessage(message: l10n.shelfEmpty)
              : _list(context, ref, value, tokens, l10n),
        // 读取失败与「书架为空」是两件事：空态会误导用户以为书没了。
        AsyncError<List<ShelvedBook>>() => StateMessage(
          message: l10n.shelfLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Builds the lazily built list of shelf entries (C-PERF-2).
  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<ShelvedBook> books,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) => ListView.builder(
    padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
    itemCount: books.length,
    itemBuilder: (BuildContext context, int index) {
      final ShelvedBook book = books[index];

      return ListTile(
        leading: Icon(
          book.status == ShelfStatus.read
              ? Icons.check_circle_outline
              : Icons.book_outlined,
        ),
        title: Text(book.name),
        subtitle: Text(_subtitle(book, l10n)),
        trailing: PopupMenuButton<_ShelfAction>(
          tooltip: book.name,
          onSelected: (_ShelfAction action) =>
              unawaited(_act(context, ref, book, action, l10n)),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<_ShelfAction>>[
            if (book.isPinned)
              PopupMenuItem<_ShelfAction>(
                value: _ShelfAction.unpin,
                child: Text(l10n.shelfActionUnpin),
              )
            else
              PopupMenuItem<_ShelfAction>(
                value: _ShelfAction.pin,
                child: Text(l10n.shelfActionPin),
              ),
            if (book.status == ShelfStatus.read)
              PopupMenuItem<_ShelfAction>(
                value: _ShelfAction.markTracking,
                child: Text(l10n.shelfActionMarkTracking),
              )
            else
              PopupMenuItem<_ShelfAction>(
                value: _ShelfAction.markRead,
                child: Text(l10n.shelfActionMarkRead),
              ),
            PopupMenuItem<_ShelfAction>(
              value: _ShelfAction.remove,
              child: Text(l10n.shelfActionRemove),
            ),
          ],
        ),
      );
    },
  );

  /// The second line of a row: author, then where the reader stopped (or the last chapter).
  ///
  /// Progress wins over `lastChapter` because it is about **this** user rather than about the
  /// site; a book that was never opened falls back to the snapshot taken when it was added.
  String _subtitle(ShelvedBook book, AppLocalizations l10n) {
    final String? progressChapter = book.progress?.chapterName;
    final String line = switch (progressChapter) {
      final String chapter when chapter.isNotEmpty => l10n.shelfProgressLine(
        chapter,
      ),
      _ => switch (book.lastChapter) {
        final String chapter when chapter.isNotEmpty =>
          l10n.bookSourceLastChapterLine(chapter),
        _ => l10n.shelfStatusTracking,
      },
    };

    return switch (book.author) {
      final String author when author.isNotEmpty => '$author · $line',
      _ => line,
    };
  }

  /// Runs one menu action: confirmation first for deletion, then the write.
  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    ShelvedBook book,
    _ShelfAction action,
    AppLocalizations l10n,
  ) async {
    if (action == _ShelfAction.remove) {
      final bool confirmed = await _confirmRemove(context, l10n);
      if (!confirmed) {
        return;
      }
    }
    if (!context.mounted) {
      return;
    }

    final Bookshelf bookshelf = ref.read(bookshelfProvider.notifier);
    final ParseResult<void> result = switch (action) {
      _ShelfAction.pin => await bookshelf.updateUserState(
        id: book.id,
        status: book.status,
        isPinned: true,
      ),
      _ShelfAction.unpin => await bookshelf.updateUserState(
        id: book.id,
        status: book.status,
        isPinned: false,
      ),
      _ShelfAction.markRead => await bookshelf.updateUserState(
        id: book.id,
        status: ShelfStatus.read,
        isPinned: book.isPinned,
      ),
      _ShelfAction.markTracking => await bookshelf.updateUserState(
        id: book.id,
        status: ShelfStatus.tracking,
        isPinned: book.isPinned,
      ),
      _ShelfAction.remove => await bookshelf.remove(book.id),
    };

    if (!context.mounted) {
      return;
    }
    if (result is ParseFailure<void>) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.shelfWriteFailed)));
    }
  }

  /// Asks before a shelf entry (and its progress) is deleted.
  Future<bool> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.shelfRemoveTitle),
        content: Text(l10n.shelfRemoveBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDelete),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }
}

/// The actions the row menu offers.
enum _ShelfAction { pin, unpin, markRead, markTracking, remove }
