import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/book_reading_records_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reading_record_tile.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// What one book's reading sessions looked like (`docs/dev/roadmap.md` M19).
///
/// Reached from the book detail page through `AppNavigation.openBookReadingRecords` (primitives
/// only), so `book_source` never imports this feature (ADR-0066 §决策 5). The page is a flat list
/// of sessions: for a single book the day grouping would add headers without answering anything the
/// rows do not already show.
class BookReadingRecordsPage extends ConsumerWidget {
  /// Creates the page for one book.
  const BookReadingRecordsPage({
    required this.sourceUrl,
    required this.bookUrl,
    required this.bookName,
    super.key,
  });

  /// `bookSourceUrl` of the source the book came from.
  final String sourceUrl;

  /// The book's detail page URL.
  final String bookUrl;

  /// The title the detail page showed, used for the app bar.
  final String bookName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<ReadingRecord>> records = ref.watch(
      bookReadingRecordsProvider((sourceUrl: sourceUrl, bookUrl: bookUrl)),
    );

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookReadingRecordsTitle(bookName)),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (records) {
        AsyncData<List<ReadingRecord>>(:final List<ReadingRecord> value) =>
          value.isEmpty
              ? StateMessage(message: l10n.bookReadingRecordsEmpty)
              : ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
                  itemCount: value.length,
                  itemBuilder: (BuildContext context, int index) =>
                      ReadingRecordTile(
                        record: value[index],
                        showBookName: false,
                      ),
                ),
        AsyncError<List<ReadingRecord>>() => StateMessage(
          message: l10n.readingRecordsLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
