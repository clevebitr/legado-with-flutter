import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelved_book.dart';
import 'package:flutter_reader/features/bookshelf/presentation/notifiers/bookshelf_notifier.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_book_scope.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks to put the open book on the shelf when the reader is left and the book is not there.
///
/// The guard lives at the composition root because the reader must not import `bookshelf`
/// (C-ARCH-2). The reader publishes its current identity through [ReaderBookScope], so a source
/// switch inside the reader is honoured instead of asking about the route's original URL.
class ReaderExitGuard extends ConsumerStatefulWidget {
  /// Wraps [child] for [book].
  const ReaderExitGuard({required this.book, required this.child, super.key});

  /// The book the route opened; it is only the initial value, a switch replaces it.
  final ReaderBook book;

  /// The reader page (text, manga or audio).
  final Widget child;

  @override
  ConsumerState<ReaderExitGuard> createState() => _ReaderExitGuardState();
}

/// State of the guard: the current book and the “asking” re-entrancy flag.
class _ReaderExitGuardState extends ConsumerState<ReaderExitGuard> {
  late final ValueNotifier<ReaderBook> _book = ValueNotifier<ReaderBook>(
    widget.book,
  );

  /// Whether the confirmation dialog is already up.
  bool _asking = false;

  @override
  void dispose() {
    _book.dispose();
    super.dispose();
  }

  /// Whether [book] already has a shelf row.
  ///
  /// A source switch rewrites the row's identity and the reader publishes the new book through
  /// [ReaderBookScope], so an exact match is enough: the title is not a substitute (two sources can
  /// have the same title and the user may still want both).
  bool _onShelf(List<ShelvedBook>? rows, ReaderBook book) {
    if (rows == null) {
      // 书架还在读：不挡退出（挡掉会让阅读器退不出去）。
      return true;
    }
    for (final ShelvedBook row in rows) {
      if (row.sourceUrl == book.sourceUrl && row.bookUrl == book.bookUrl) {
        return true;
      }
    }

    return false;
  }

  /// Shows the dialog and, on “add”, stores the book before letting the route go.
  Future<void> _confirmAndPop() async {
    if (_asking) {
      return;
    }
    _asking = true;
    final ReaderBook book = _book.value;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? add = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.shelfAddAction),
        content: Text(book.name),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.shelfAddAction),
          ),
        ],
      ),
    );
    _asking = false;
    if (!mounted) {
      return;
    }

    if (add == true) {
      final ParseResult<void> result = await ref
          .read(bookshelfProvider.notifier)
          .add(
            ShelfCandidate(
              sourceUrl: book.sourceUrl,
              bookUrl: book.bookUrl,
              name: book.name,
              tocUrl: book.tocUrl,
            ),
          );
      if (!mounted) {
        return;
      }
      if (result is ParseFailure<void>) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.shelfAddFailed)));

        return;
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ShelvedBook>? rows = ref.watch(bookshelfProvider).value;

    return ReaderBookScope(
      book: _book,
      child: ValueListenableBuilder<ReaderBook>(
        valueListenable: _book,
        builder: (BuildContext context, ReaderBook book, Widget? child) =>
            PopScope(
              canPop: _onShelf(rows, book),
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop || _asking) {
                  return;
                }
                unawaited(_confirmAndPop());
              },
              child: child ?? const SizedBox.shrink(),
            ),
        child: widget.child,
      ),
    );
  }
}
