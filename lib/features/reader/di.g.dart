// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'di.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the reader's own settings store (`docs/dev/roadmap.md` 5.3).

@ProviderFor(readerSettingsRepository)
final readerSettingsRepositoryProvider = ReaderSettingsRepositoryProvider._();

/// Provides the reader's own settings store (`docs/dev/roadmap.md` 5.3).

final class ReaderSettingsRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReaderSettingsRepository>,
          ReaderSettingsRepository,
          FutureOr<ReaderSettingsRepository>
        >
    with
        $FutureModifier<ReaderSettingsRepository>,
        $FutureProvider<ReaderSettingsRepository> {
  /// Provides the reader's own settings store (`docs/dev/roadmap.md` 5.3).
  ReaderSettingsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerSettingsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerSettingsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<ReaderSettingsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReaderSettingsRepository> create(Ref ref) {
    return readerSettingsRepository(ref);
  }
}

String _$readerSettingsRepositoryHash() =>
    r'fd39b73defa3577d7b83a59ca17e8239db804aeb';

/// Provides the chapter-list port, **unbound** by default.
///
/// The composition root overrides it with `book_source`'s `FetchToc` (ADR-0041 §决策 2). The
/// default is the null object, so a forgotten binding is a failure message plus a warning rather
/// than an exception in the middle of reading.

@ProviderFor(readerChapterList)
final readerChapterListProvider = ReaderChapterListProvider._();

/// Provides the chapter-list port, **unbound** by default.
///
/// The composition root overrides it with `book_source`'s `FetchToc` (ADR-0041 §决策 2). The
/// default is the null object, so a forgotten binding is a failure message plus a warning rather
/// than an exception in the middle of reading.

final class ReaderChapterListProvider
    extends
        $FunctionalProvider<
          ChapterListProvider,
          ChapterListProvider,
          ChapterListProvider
        >
    with $Provider<ChapterListProvider> {
  /// Provides the chapter-list port, **unbound** by default.
  ///
  /// The composition root overrides it with `book_source`'s `FetchToc` (ADR-0041 §决策 2). The
  /// default is the null object, so a forgotten binding is a failure message plus a warning rather
  /// than an exception in the middle of reading.
  ReaderChapterListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerChapterListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerChapterListHash();

  @$internal
  @override
  $ProviderElement<ChapterListProvider> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChapterListProvider create(Ref ref) {
    return readerChapterList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChapterListProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChapterListProvider>(value),
    );
  }
}

String _$readerChapterListHash() => r'3b847da206a3d53186a4dfec3e5322342cecf74e';

/// Provides the chapter-body port, **unbound** by default.

@ProviderFor(readerChapterContent)
final readerChapterContentProvider = ReaderChapterContentProvider._();

/// Provides the chapter-body port, **unbound** by default.

final class ReaderChapterContentProvider
    extends
        $FunctionalProvider<
          ChapterContentProvider,
          ChapterContentProvider,
          ChapterContentProvider
        >
    with $Provider<ChapterContentProvider> {
  /// Provides the chapter-body port, **unbound** by default.
  ReaderChapterContentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerChapterContentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerChapterContentHash();

  @$internal
  @override
  $ProviderElement<ChapterContentProvider> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChapterContentProvider create(Ref ref) {
    return readerChapterContent(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChapterContentProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChapterContentProvider>(value),
    );
  }
}

String _$readerChapterContentHash() =>
    r'71afbfd8814ede15f4fe7f43b9c28d2afe91f366';

/// Provides the manga-page port, **unbound** by default
/// (`docs/dev/roadmap.md` §3.10 M16).

@ProviderFor(readerMangaPages)
final readerMangaPagesProvider = ReaderMangaPagesProvider._();

/// Provides the manga-page port, **unbound** by default
/// (`docs/dev/roadmap.md` §3.10 M16).

final class ReaderMangaPagesProvider
    extends
        $FunctionalProvider<
          MangaPageProvider,
          MangaPageProvider,
          MangaPageProvider
        >
    with $Provider<MangaPageProvider> {
  /// Provides the manga-page port, **unbound** by default
  /// (`docs/dev/roadmap.md` §3.10 M16).
  ReaderMangaPagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerMangaPagesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerMangaPagesHash();

  @$internal
  @override
  $ProviderElement<MangaPageProvider> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MangaPageProvider create(Ref ref) {
    return readerMangaPages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MangaPageProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MangaPageProvider>(value),
    );
  }
}

String _$readerMangaPagesHash() => r'd014eac0a758db1643bc5911c252bdb5ecac19a9';

/// Provides the source-kind port, **unbound** by default: an unbound reader opens text.

@ProviderFor(readerSourceKindPort)
final readerSourceKindPortProvider = ReaderSourceKindPortProvider._();

/// Provides the source-kind port, **unbound** by default: an unbound reader opens text.

final class ReaderSourceKindPortProvider
    extends
        $FunctionalProvider<
          ReaderSourceKindProvider,
          ReaderSourceKindProvider,
          ReaderSourceKindProvider
        >
    with $Provider<ReaderSourceKindProvider> {
  /// Provides the source-kind port, **unbound** by default: an unbound reader opens text.
  ReaderSourceKindPortProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerSourceKindPortProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerSourceKindPortHash();

  @$internal
  @override
  $ProviderElement<ReaderSourceKindProvider> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReaderSourceKindProvider create(Ref ref) {
    return readerSourceKindPort(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReaderSourceKindProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReaderSourceKindProvider>(value),
    );
  }
}

String _$readerSourceKindPortHash() =>
    r'6f83a1250b92e73c85a908ab28302910a50347d4';

/// Provides the reading-progress port, **unbound** by default.
///
/// The composition root binds it to `bookshelf`, which owns the table (ADR-0041 §决策 4,
/// ADR-0044 §决策 2).

@ProviderFor(readerProgressStore)
final readerProgressStoreProvider = ReaderProgressStoreProvider._();

/// Provides the reading-progress port, **unbound** by default.
///
/// The composition root binds it to `bookshelf`, which owns the table (ADR-0041 §决策 4,
/// ADR-0044 §决策 2).

final class ReaderProgressStoreProvider
    extends
        $FunctionalProvider<
          ReadingProgressStore,
          ReadingProgressStore,
          ReadingProgressStore
        >
    with $Provider<ReadingProgressStore> {
  /// Provides the reading-progress port, **unbound** by default.
  ///
  /// The composition root binds it to `bookshelf`, which owns the table (ADR-0041 §决策 4,
  /// ADR-0044 §决策 2).
  ReaderProgressStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerProgressStoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerProgressStoreHash();

  @$internal
  @override
  $ProviderElement<ReadingProgressStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReadingProgressStore create(Ref ref) {
    return readerProgressStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadingProgressStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadingProgressStore>(value),
    );
  }
}

String _$readerProgressStoreHash() =>
    r'dd9eeeee651d67ee3e19a0a882d83218be17480e';
