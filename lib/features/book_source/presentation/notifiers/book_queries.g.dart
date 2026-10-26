// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_queries.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads the detail page of [book] from [source].
///
/// Fetch-on-build: leaving the page disposes the request.

@ProviderFor(bookInfo)
final bookInfoProvider = BookInfoFamily._();

/// Reads the detail page of [book] from [source].
///
/// Fetch-on-build: leaving the page disposes the request.

final class BookInfoProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<BookInfo>>,
          ParseResult<BookInfo>,
          FutureOr<ParseResult<BookInfo>>
        >
    with
        $FutureModifier<ParseResult<BookInfo>>,
        $FutureProvider<ParseResult<BookInfo>> {
  /// Reads the detail page of [book] from [source].
  ///
  /// Fetch-on-build: leaving the page disposes the request.
  BookInfoProvider._({
    required BookInfoFamily super.from,
    required (BookSource, Book) super.argument,
  }) : super(
         retry: null,
         name: r'bookInfoProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookInfoHash();

  @override
  String toString() {
    return r'bookInfoProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<BookInfo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<BookInfo>> create(Ref ref) {
    final argument = this.argument as (BookSource, Book);
    return bookInfo(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BookInfoProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookInfoHash() => r'f51b80128fca711c4a0a45137a455adde902f2b5';

/// Reads the detail page of [book] from [source].
///
/// Fetch-on-build: leaving the page disposes the request.

final class BookInfoFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<BookInfo>>,
          (BookSource, Book)
        > {
  BookInfoFamily._()
    : super(
        retry: null,
        name: r'bookInfoProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads the detail page of [book] from [source].
  ///
  /// Fetch-on-build: leaving the page disposes the request.

  BookInfoProvider call(BookSource source, Book book) =>
      BookInfoProvider._(argument: (source, book), from: this);

  @override
  String toString() => r'bookInfoProvider';
}

/// Reads the chapter list that lives at [url] of [source].

@ProviderFor(toc)
final tocProvider = TocFamily._();

/// Reads the chapter list that lives at [url] of [source].

final class TocProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<List<Chapter>>>,
          ParseResult<List<Chapter>>,
          FutureOr<ParseResult<List<Chapter>>>
        >
    with
        $FutureModifier<ParseResult<List<Chapter>>>,
        $FutureProvider<ParseResult<List<Chapter>>> {
  /// Reads the chapter list that lives at [url] of [source].
  TocProvider._({
    required TocFamily super.from,
    required (BookSource, String) super.argument,
  }) : super(
         retry: null,
         name: r'tocProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tocHash();

  @override
  String toString() {
    return r'tocProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<List<Chapter>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<List<Chapter>>> create(Ref ref) {
    final argument = this.argument as (BookSource, String);
    return toc(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is TocProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tocHash() => r'36e065fe6993f1b35d053f5556d429500d2f6e22';

/// Reads the chapter list that lives at [url] of [source].

final class TocFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<List<Chapter>>>,
          (BookSource, String)
        > {
  TocFamily._()
    : super(
        retry: null,
        name: r'tocProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads the chapter list that lives at [url] of [source].

  TocProvider call(BookSource source, String url) =>
      TocProvider._(argument: (source, url), from: this);

  @override
  String toString() => r'tocProvider';
}

/// Reads the body of the chapter at [url] of [source].

@ProviderFor(chapterContent)
final chapterContentProvider = ChapterContentFamily._();

/// Reads the body of the chapter at [url] of [source].

final class ChapterContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<String>>,
          ParseResult<String>,
          FutureOr<ParseResult<String>>
        >
    with
        $FutureModifier<ParseResult<String>>,
        $FutureProvider<ParseResult<String>> {
  /// Reads the body of the chapter at [url] of [source].
  ChapterContentProvider._({
    required ChapterContentFamily super.from,
    required (BookSource, String) super.argument,
  }) : super(
         retry: null,
         name: r'chapterContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chapterContentHash();

  @override
  String toString() {
    return r'chapterContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<String>> create(Ref ref) {
    final argument = this.argument as (BookSource, String);
    return chapterContent(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ChapterContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chapterContentHash() => r'56a60c5716ab7a1f814cbd0466ad60007836f753';

/// Reads the body of the chapter at [url] of [source].

final class ChapterContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<String>>,
          (BookSource, String)
        > {
  ChapterContentFamily._()
    : super(
        retry: null,
        name: r'chapterContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads the body of the chapter at [url] of [source].

  ChapterContentProvider call(BookSource source, String url) =>
      ChapterContentProvider._(argument: (source, url), from: this);

  @override
  String toString() => r'chapterContentProvider';
}
