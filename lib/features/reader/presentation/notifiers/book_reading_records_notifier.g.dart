// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_reading_records_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The recent reading sessions of one book (`docs/dev/roadmap.md` M19).
///
/// The book identity is passed as a small record of primitives instead of `ReaderBook`: the detail
/// page's entry point only knows `(sourceUrl, bookUrl)`, and the port that carries it is primitive
/// by construction (ADR-0042). The title is not needed here — the page's app bar gets it from the
/// route.

@ProviderFor(bookReadingRecords)
final bookReadingRecordsProvider = BookReadingRecordsFamily._();

/// The recent reading sessions of one book (`docs/dev/roadmap.md` M19).
///
/// The book identity is passed as a small record of primitives instead of `ReaderBook`: the detail
/// page's entry point only knows `(sourceUrl, bookUrl)`, and the port that carries it is primitive
/// by construction (ADR-0042). The title is not needed here — the page's app bar gets it from the
/// route.

final class BookReadingRecordsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReadingRecord>>,
          List<ReadingRecord>,
          FutureOr<List<ReadingRecord>>
        >
    with
        $FutureModifier<List<ReadingRecord>>,
        $FutureProvider<List<ReadingRecord>> {
  /// The recent reading sessions of one book (`docs/dev/roadmap.md` M19).
  ///
  /// The book identity is passed as a small record of primitives instead of `ReaderBook`: the detail
  /// page's entry point only knows `(sourceUrl, bookUrl)`, and the port that carries it is primitive
  /// by construction (ADR-0042). The title is not needed here — the page's app bar gets it from the
  /// route.
  BookReadingRecordsProvider._({
    required BookReadingRecordsFamily super.from,
    required ({String bookUrl, String sourceUrl}) super.argument,
  }) : super(
         retry: null,
         name: r'bookReadingRecordsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookReadingRecordsHash();

  @override
  String toString() {
    return r'bookReadingRecordsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ReadingRecord>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ReadingRecord>> create(Ref ref) {
    final argument = this.argument as ({String bookUrl, String sourceUrl});
    return bookReadingRecords(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is BookReadingRecordsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookReadingRecordsHash() =>
    r'3fc6067720b524c93d4c276c1e78659f040835a4';

/// The recent reading sessions of one book (`docs/dev/roadmap.md` M19).
///
/// The book identity is passed as a small record of primitives instead of `ReaderBook`: the detail
/// page's entry point only knows `(sourceUrl, bookUrl)`, and the port that carries it is primitive
/// by construction (ADR-0042). The title is not needed here — the page's app bar gets it from the
/// route.

final class BookReadingRecordsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ReadingRecord>>,
          ({String bookUrl, String sourceUrl})
        > {
  BookReadingRecordsFamily._()
    : super(
        retry: null,
        name: r'bookReadingRecordsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The recent reading sessions of one book (`docs/dev/roadmap.md` M19).
  ///
  /// The book identity is passed as a small record of primitives instead of `ReaderBook`: the detail
  /// page's entry point only knows `(sourceUrl, bookUrl)`, and the port that carries it is primitive
  /// by construction (ADR-0042). The title is not needed here — the page's app bar gets it from the
  /// route.

  BookReadingRecordsProvider call(({String bookUrl, String sourceUrl}) book) =>
      BookReadingRecordsProvider._(argument: book, from: this);

  @override
  String toString() => r'bookReadingRecordsProvider';
}
