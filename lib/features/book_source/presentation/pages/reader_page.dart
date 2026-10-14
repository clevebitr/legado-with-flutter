import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_queries.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/failure_message.dart';
import 'package:flutter_reader/features/book_source/presentation/widgets/state_message.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// Reads one chapter as plain text.
class ReaderPage extends ConsumerWidget {
  /// Creates the page.
  const ReaderPage({required this.chapter, super.key});

  /// The chapter this page shows.
  final Chapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final BookSource? source = ref.watch(currentBookSourceProvider);

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        // 章节名可能是空串（`chapterName` 规则没匹配到），此时回落到通用标题，
        // 而不是显示一个空 AppBar（C-UI-5：文案来自 ARB）。
        title: Text(
          chapter.name.isEmpty ? l10n.bookSourceReaderTitle : chapter.name,
        ),
        backgroundColor: tokens.colors.surface,
      ),
      body: source == null
          ? StateMessage(message: l10n.bookSourceMissingSource)
          : _body(ref, source, tokens),
    );
  }

  /// Builds the text area for the selected [source].
  Widget _body(WidgetRef ref, BookSource source, M3ETheme tokens) {
    final AsyncValue<ParseResult<String>> content = ref.watch(
      chapterContentProvider(source, chapter.url),
    );

    return switch (content) {
      AsyncData<ParseResult<String>>(:final ParseResult<String> value) =>
        switch (value) {
          ParseSuccess<String>(:final String data) => SingleChildScrollView(
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: Text(data, style: tokens.typography.base.bodyLarge),
          ),
          ParseFailure<String>(:final ParseFailureKind kind) => FailureMessage(
            kind: kind,
            onRetry: () =>
                ref.invalidate(chapterContentProvider(source, chapter.url)),
          ),
        },
      // 用例按 C-ERR-1 不抛异常：这里只兜住意外错误，避免用户看到白屏。
      AsyncError<ParseResult<String>>() => FailureMessage(
        kind: ParseFailureKind.parseFailed,
        onRetry: () =>
            ref.invalidate(chapterContentProvider(source, chapter.url)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
