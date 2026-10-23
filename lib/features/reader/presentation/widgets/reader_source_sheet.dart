import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/repositories/book_source_switcher.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The “change source” sheet of the reader (`docs/dev/roadmap.md` §3.9-R3, ADR-0051 §决策 3).
///
/// It loads its candidates on open (one search across the other sources) and answers the candidate
/// the user picked; the switch itself belongs to the caller, because only it knows the chapter the
/// reader is on (the alignment input).
///
/// Three states, all of them visible: searching, a list, and a *failure the port answers*. An empty
/// list is **not** a failure — “no other source has this book” is the normal answer for an obscure
/// title.
class ReaderSourceSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const ReaderSourceSheet({required this.book, super.key});

  /// The book being read; its name is the search keyword.
  final ReaderBook book;

  @override
  ConsumerState<ReaderSourceSheet> createState() => _ReaderSourceSheetState();
}

class _ReaderSourceSheetState extends ConsumerState<ReaderSourceSheet> {
  late Future<ParseResult<List<ReaderSourceCandidate>>> _candidates;

  @override
  void initState() {
    super.initState();
    _candidates = ref.read(bookSourceSwitcherProvider).candidates(widget.book);
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
              child: FutureBuilder<ParseResult<List<ReaderSourceCandidate>>>(
                future: _candidates,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<ParseResult<List<ReaderSourceCandidate>>>
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
                        ParseSuccess<List<ReaderSourceCandidate>>(
                          :final List<ReaderSourceCandidate> data,
                        ) =>
                          data.isEmpty
                              ? StateMessage(message: l10n.readerSourceEmpty)
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: data.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                        final ReaderSourceCandidate candidate =
                                            data[index];

                                        return ListTile(
                                          title: Text(candidate.sourceName),
                                          subtitle: Text(
                                            <String>[
                                              if (candidate.author
                                                  case final String author
                                                  when author.isNotEmpty)
                                                author,
                                              if (candidate.lastChapter
                                                  case final String chapter
                                                  when chapter.isNotEmpty)
                                                chapter,
                                            ].join(' · '),
                                          ),
                                          onTap: () =>
                                              Navigator.of(context)
                                                  .pop(candidate),
                                        );
                                      },
                                ),
                        ParseFailure<List<ReaderSourceCandidate>>(
                          :final ParseFailureKind kind,
                        ) =>
                          FailureMessage(kind: kind),
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
