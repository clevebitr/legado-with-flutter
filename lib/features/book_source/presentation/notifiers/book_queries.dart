import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_queries.g.dart';

/// Reads the detail page of [book] from [source].
///
/// Fetch-on-build: leaving the page disposes the request.
@riverpod
Future<ParseResult<BookInfo>> bookInfo(Ref ref, BookSource source, Book book) =>
    ref.watch(fetchBookInfoProvider).execute(source, book.url);

/// Reads the chapter list that lives at [url] of [source].
@riverpod
Future<ParseResult<List<Chapter>>> toc(
  Ref ref,
  BookSource source,
  String url,
) => ref.watch(fetchTocProvider).execute(source, url);

/// Reads the body of the chapter at [url] of [source].
@riverpod
Future<ParseResult<String>> chapterContent(
  Ref ref,
  BookSource source,
  String url,
) => ref.watch(fetchContentProvider).execute(source, ChapterRequest(url: url));
