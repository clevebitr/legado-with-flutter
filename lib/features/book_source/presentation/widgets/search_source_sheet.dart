import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_reader/features/book_source/domain/entities/search_book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// Asks which source's copy of [book] to open (`docs/dev/roadmap.md` §3.12, ADR-0091 §决策 6).
///
/// A merged search row says "4 sources"; before this sheet existed the tap only ever opened the
/// **first** one, and the other three addresses were not even kept (`DECISIONS.md` #76). Every row
/// here is one `OriginHit` — a snapshot taken at merge time, so no request is sent to build the
/// list.
///
/// A source that was deleted in the meantime stays visible but disabled: opening it would show
/// "source is missing" on the detail page, and hiding it would look like the row lied about having
/// four sources.
Future<OriginHit?> showSearchSourceSheet({
  required BuildContext context,
  required SearchBook book,
  required List<StoredBookSource> rows,
}) => showModalBottomSheet<OriginHit>(
  context: context,
  isScrollControlled: true,
  builder: (BuildContext sheetContext) => SafeArea(
    child: _SearchSourceSheet(book: book, rows: rows),
  ),
);

/// The sheet body: one tile per origin, ordered as the merger collected them.
class _SearchSourceSheet extends StatelessWidget {
  const _SearchSourceSheet({required this.book, required this.rows});

  final SearchBook book;
  final List<StoredBookSource> rows;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.lg,
            tokens.spacing.md,
            tokens.spacing.lg,
            tokens.spacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.searchSourceSheetTitle,
                style: tokens.typography.base.titleMedium,
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                book.name,
                style: tokens.typography.base.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        for (final OriginHit hit in book.hits)
          _tile(context, l10n, tokens, hit, _rowFor(hit.sourceUrl)),
      ],
    );
  }

  /// One origin: its source name, then the author and latest chapter that source spelled.
  Widget _tile(
    BuildContext context,
    AppLocalizations l10n,
    M3ETheme tokens,
    OriginHit hit,
    StoredBookSource? stored,
  ) {
    final String subtitle = <String>[
      if (hit.author case final String author when author.isNotEmpty) author,
      if (hit.lastChapter case final String chapter when chapter.isNotEmpty)
        chapter,
      if (stored == null) l10n.bookSourceCheckFailureSourceMissing,
    ].join(' · ');

    return ListTile(
      leading: CoverImage(
        url: hit.coverUrl,
        width: tokens.spacing.xxl,
        height: tokens.spacing.xxl * 1.35,
      ),
      title: Text(stored?.source.name ?? hit.sourceUrl),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      enabled: stored != null,
      onTap: stored == null ? null : () => Navigator.of(context).pop(hit),
    );
  }

  /// The stored row behind [sourceUrl], or `null` when it was deleted.
  StoredBookSource? _rowFor(String sourceUrl) {
    for (final StoredBookSource row in rows) {
      if (row.source.url == sourceUrl) {
        return row;
      }
    }

    return null;
  }
}
