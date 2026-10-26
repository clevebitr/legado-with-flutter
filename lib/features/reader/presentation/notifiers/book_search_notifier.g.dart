// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_search_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs one in-book search and publishes its progress
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// The notifier owns the [BookSearchSession]: starting a second search cancels the first (two runs
/// against one source would double every request), and disposing it — which is what closing the
/// search sheet does — cancels too, so a closed page stops asking the source for chapters.

@ProviderFor(BookSearch)
final bookSearchProvider = BookSearchFamily._();

/// Runs one in-book search and publishes its progress
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// The notifier owns the [BookSearchSession]: starting a second search cancels the first (two runs
/// against one source would double every request), and disposing it — which is what closing the
/// search sheet does — cancels too, so a closed page stops asking the source for chapters.
final class BookSearchProvider
    extends $NotifierProvider<BookSearch, BookSearchProgress?> {
  /// Runs one in-book search and publishes its progress
  /// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
  ///
  /// The notifier owns the [BookSearchSession]: starting a second search cancels the first (two runs
  /// against one source would double every request), and disposing it — which is what closing the
  /// search sheet does — cancels too, so a closed page stops asking the source for chapters.
  BookSearchProvider._({
    required BookSearchFamily super.from,
    required ReaderBook super.argument,
  }) : super(
         retry: null,
         name: r'bookSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookSearchHash();

  @override
  String toString() {
    return r'bookSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BookSearch create() => BookSearch();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSearchProgress? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSearchProgress?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BookSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookSearchHash() => r'556ec86f483767023fc58e6361baa772f50871eb';

/// Runs one in-book search and publishes its progress
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// The notifier owns the [BookSearchSession]: starting a second search cancels the first (two runs
/// against one source would double every request), and disposing it — which is what closing the
/// search sheet does — cancels too, so a closed page stops asking the source for chapters.

final class BookSearchFamily extends $Family
    with
        $ClassFamilyOverride<
          BookSearch,
          BookSearchProgress?,
          BookSearchProgress?,
          BookSearchProgress?,
          ReaderBook
        > {
  BookSearchFamily._()
    : super(
        retry: null,
        name: r'bookSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Runs one in-book search and publishes its progress
  /// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
  ///
  /// The notifier owns the [BookSearchSession]: starting a second search cancels the first (two runs
  /// against one source would double every request), and disposing it — which is what closing the
  /// search sheet does — cancels too, so a closed page stops asking the source for chapters.

  BookSearchProvider call(ReaderBook book) =>
      BookSearchProvider._(argument: book, from: this);

  @override
  String toString() => r'bookSearchProvider';
}

/// Runs one in-book search and publishes its progress
/// (`docs/dev/roadmap.md` M20, ADR-0070 §决策 2).
///
/// The notifier owns the [BookSearchSession]: starting a second search cancels the first (two runs
/// against one source would double every request), and disposing it — which is what closing the
/// search sheet does — cancels too, so a closed page stops asking the source for chapters.

abstract class _$BookSearch extends $Notifier<BookSearchProgress?> {
  late final _$args = ref.$arg as ReaderBook;
  ReaderBook get book => _$args;

  BookSearchProgress? build(ReaderBook book);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BookSearchProgress?, BookSearchProgress?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BookSearchProgress?, BookSearchProgress?>,
              BookSearchProgress?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
