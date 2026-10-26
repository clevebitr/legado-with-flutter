import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/switch_book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The “change source” sheet of the book detail page (ADR-0051 §决策 3's same candidate search).
///
/// It loads every other **enabled text source** that has this book and answers the one the user
/// picked. The switch itself belongs to the caller, because only it knows the shelf identity and
/// the page that has to be refreshed afterwards.
class ChangeBookSourceSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [bookName], excluding [currentSourceUrl].
  const ChangeBookSourceSheet({
    required this.bookName,
    required this.currentSourceUrl,
    super.key,
  });

  /// The title every candidate has to match.
  final String bookName;

  /// The source the book is currently parsed with.
  final String currentSourceUrl;

  @override
  ConsumerState<ChangeBookSourceSheet> createState() =>
      _ChangeBookSourceSheetState();
}

/// State of the sheet: the candidate future and its retry.
class _ChangeBookSourceSheetState extends ConsumerState<ChangeBookSourceSheet> {
  late Future<ParseResult<List<SourceCandidate>>> _candidates = _load();

  /// Searches the other text sources for the same book.
  Future<ParseResult<List<SourceCandidate>>> _load() async {
    final List<StoredBookSource> rows = await ref.read(
      bookSourceListProvider.future,
    );
    final List<BookSource> sources = <BookSource>[
      for (final StoredBookSource row in rows)
        if (row.isEnabled && row.source.sourceType == BookSourceType.text)
          row.source,
    ];

    return ref
        .read(switchBookSourceProvider)
        .candidates(
          bookName: widget.bookName,
          sources: sources,
          currentSourceUrl: widget.currentSourceUrl,
        );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l10n.readerSourceTitle,
              style: tokens.typography.base.titleMedium,
            ),
            SizedBox(height: tokens.spacing.sm),
            Flexible(
              child: FutureBuilder<ParseResult<List<SourceCandidate>>>(
                future: _candidates,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<ParseResult<List<SourceCandidate>>>
                      snapshot,
                    ) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Padding(
                          padding: EdgeInsets.all(tokens.spacing.lg),
                          child: Row(
                            children: <Widget>[
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: tokens.spacing.sm),
                              Text(l10n.readerSourceSearching),
                            ],
                          ),
                        );
                      }
                      return switch (snapshot.data) {
                        ParseSuccess<List<SourceCandidate>>(
                          :final List<SourceCandidate> data,
                        ) =>
                          data.isEmpty
                              ? StateMessage(message: l10n.readerSourceEmpty)
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: data.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        final SourceCandidate candidate =
                                            data[index];
                                        final String subtitle = <String>[
                                          if (candidate.author
                                              case final String author
                                              when author.isNotEmpty)
                                            author,
                                          if (candidate.lastChapter
                                              case final String chapter
                                              when chapter.isNotEmpty)
                                            chapter,
                                        ].join(' · ');

                                        return ListTile(
                                          title: Text(candidate.sourceName),
                                          subtitle: subtitle.isEmpty
                                              ? null
                                              : Text(subtitle),
                                          onTap: () =>
                                              Navigator.of(context)
                                                  .pop(candidate),
                                        );
                                      },
                                ),
                        ParseFailure<List<SourceCandidate>>(
                          :final ParseFailureKind kind,
                        ) =>
                          FailureMessage(
                            kind: kind,
                            onRetry: () => setState(() {
                              _candidates = _load();
                            }),
                          ),
                        _ => const FailureMessage(
                          kind: ParseFailureKind.parseFailed,
                        ),
                      };
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
