// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads the chapter list of [book] (`docs/dev/roadmap.md` 5.3).
///
/// A plain `ParseResult`-returning provider rather than an `AsyncValue` of data: the page shows a
/// retryable failure message for the failure branch, which is what
/// `docs/dev/architecture.md` §5 asks of every consumer.

@ProviderFor(readerChapters)
final readerChaptersProvider = ReaderChaptersFamily._();

/// Reads the chapter list of [book] (`docs/dev/roadmap.md` 5.3).
///
/// A plain `ParseResult`-returning provider rather than an `AsyncValue` of data: the page shows a
/// retryable failure message for the failure branch, which is what
/// `docs/dev/architecture.md` §5 asks of every consumer.

final class ReaderChaptersProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<List<ReadingChapter>>>,
          ParseResult<List<ReadingChapter>>,
          FutureOr<ParseResult<List<ReadingChapter>>>
        >
    with
        $FutureModifier<ParseResult<List<ReadingChapter>>>,
        $FutureProvider<ParseResult<List<ReadingChapter>>> {
  /// Reads the chapter list of [book] (`docs/dev/roadmap.md` 5.3).
  ///
  /// A plain `ParseResult`-returning provider rather than an `AsyncValue` of data: the page shows a
  /// retryable failure message for the failure branch, which is what
  /// `docs/dev/architecture.md` §5 asks of every consumer.
  ReaderChaptersProvider._({
    required ReaderChaptersFamily super.from,
    required ReaderBook super.argument,
  }) : super(
         retry: null,
         name: r'readerChaptersProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerChaptersHash();

  @override
  String toString() {
    return r'readerChaptersProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<List<ReadingChapter>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<List<ReadingChapter>>> create(Ref ref) {
    final argument = this.argument as ReaderBook;
    return readerChapters(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderChaptersProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerChaptersHash() => r'f268625e1a34b9349801bede059c6286107bbce5';

/// Reads the chapter list of [book] (`docs/dev/roadmap.md` 5.3).
///
/// A plain `ParseResult`-returning provider rather than an `AsyncValue` of data: the page shows a
/// retryable failure message for the failure branch, which is what
/// `docs/dev/architecture.md` §5 asks of every consumer.

final class ReaderChaptersFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<List<ReadingChapter>>>,
          ReaderBook
        > {
  ReaderChaptersFamily._()
    : super(
        retry: null,
        name: r'readerChaptersProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads the chapter list of [book] (`docs/dev/roadmap.md` 5.3).
  ///
  /// A plain `ParseResult`-returning provider rather than an `AsyncValue` of data: the page shows a
  /// retryable failure message for the failure branch, which is what
  /// `docs/dev/architecture.md` §5 asks of every consumer.

  ReaderChaptersProvider call(ReaderBook book) =>
      ReaderChaptersProvider._(argument: book, from: this);

  @override
  String toString() => r'readerChaptersProvider';
}

/// Reads the body of one chapter (`docs/dev/roadmap.md` 5.3).
///
/// Fetch-on-build like the detail page's providers: leaving the chapter disposes the request
/// instead of letting a detached continuation write into a dead state. The body goes through the
/// same `FetchContent` adapter, so the 5.2 cache still applies.

@ProviderFor(readerContent)
final readerContentProvider = ReaderContentFamily._();

/// Reads the body of one chapter (`docs/dev/roadmap.md` 5.3).
///
/// Fetch-on-build like the detail page's providers: leaving the chapter disposes the request
/// instead of letting a detached continuation write into a dead state. The body goes through the
/// same `FetchContent` adapter, so the 5.2 cache still applies.

final class ReaderContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<String>>,
          ParseResult<String>,
          FutureOr<ParseResult<String>>
        >
    with
        $FutureModifier<ParseResult<String>>,
        $FutureProvider<ParseResult<String>> {
  /// Reads the body of one chapter (`docs/dev/roadmap.md` 5.3).
  ///
  /// Fetch-on-build like the detail page's providers: leaving the chapter disposes the request
  /// instead of letting a detached continuation write into a dead state. The body goes through the
  /// same `FetchContent` adapter, so the 5.2 cache still applies.
  ReaderContentProvider._({
    required ReaderContentFamily super.from,
    required (ReaderBook, String) super.argument,
  }) : super(
         retry: null,
         name: r'readerContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerContentHash();

  @override
  String toString() {
    return r'readerContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<String>> create(Ref ref) {
    final argument = this.argument as (ReaderBook, String);
    return readerContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerContentHash() => r'3dccf34c6f2c9bbd16b3d893b30689adf38de75e';

/// Reads the body of one chapter (`docs/dev/roadmap.md` 5.3).
///
/// Fetch-on-build like the detail page's providers: leaving the chapter disposes the request
/// instead of letting a detached continuation write into a dead state. The body goes through the
/// same `FetchContent` adapter, so the 5.2 cache still applies.

final class ReaderContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<String>>,
          (ReaderBook, String)
        > {
  ReaderContentFamily._()
    : super(
        retry: null,
        name: r'readerContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads the body of one chapter (`docs/dev/roadmap.md` 5.3).
  ///
  /// Fetch-on-build like the detail page's providers: leaving the chapter disposes the request
  /// instead of letting a detached continuation write into a dead state. The body goes through the
  /// same `FetchContent` adapter, so the 5.2 cache still applies.

  ReaderContentProvider call((ReaderBook, String) request) =>
      ReaderContentProvider._(argument: request, from: this);

  @override
  String toString() => r'readerContentProvider';
}

/// The chapter index the session is on, or `null` while it is loading.
///
/// It exists so a listener can depend on the **index only**: the session's state also carries the
/// character offset (the audio player writes it every few seconds), and watching the whole session
/// from the player would reload the track on every progress write. A derived provider recomputes,
/// but its value is `==` to the previous one, so its listeners are not notified.

@ProviderFor(readerChapterIndex)
final readerChapterIndexProvider = ReaderChapterIndexFamily._();

/// The chapter index the session is on, or `null` while it is loading.
///
/// It exists so a listener can depend on the **index only**: the session's state also carries the
/// character offset (the audio player writes it every few seconds), and watching the whole session
/// from the player would reload the track on every progress write. A derived provider recomputes,
/// but its value is `==` to the previous one, so its listeners are not notified.

final class ReaderChapterIndexProvider
    extends $FunctionalProvider<int?, int?, int?>
    with $Provider<int?> {
  /// The chapter index the session is on, or `null` while it is loading.
  ///
  /// It exists so a listener can depend on the **index only**: the session's state also carries the
  /// character offset (the audio player writes it every few seconds), and watching the whole session
  /// from the player would reload the track on every progress write. A derived provider recomputes,
  /// but its value is `==` to the previous one, so its listeners are not notified.
  ReaderChapterIndexProvider._({
    required ReaderChapterIndexFamily super.from,
    required ReaderBook super.argument,
  }) : super(
         retry: null,
         name: r'readerChapterIndexProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerChapterIndexHash();

  @override
  String toString() {
    return r'readerChapterIndexProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<int?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int? create(Ref ref) {
    final argument = this.argument as ReaderBook;
    return readerChapterIndex(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderChapterIndexProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerChapterIndexHash() =>
    r'09d3732c771bb4344708b88fd67d69226ff46575';

/// The chapter index the session is on, or `null` while it is loading.
///
/// It exists so a listener can depend on the **index only**: the session's state also carries the
/// character offset (the audio player writes it every few seconds), and watching the whole session
/// from the player would reload the track on every progress write. A derived provider recomputes,
/// but its value is `==` to the previous one, so its listeners are not notified.

final class ReaderChapterIndexFamily extends $Family
    with $FunctionalFamilyOverride<int?, ReaderBook> {
  ReaderChapterIndexFamily._()
    : super(
        retry: null,
        name: r'readerChapterIndexProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The chapter index the session is on, or `null` while it is loading.
  ///
  /// It exists so a listener can depend on the **index only**: the session's state also carries the
  /// character offset (the audio player writes it every few seconds), and watching the whole session
  /// from the player would reload the track on every progress write. A derived provider recomputes,
  /// but its value is `==` to the previous one, so its listeners are not notified.

  ReaderChapterIndexProvider call(ReaderBook book) =>
      ReaderChapterIndexProvider._(argument: book, from: this);

  @override
  String toString() => r'readerChapterIndexProvider';
}

/// The reading session: which chapter is open and where the user is inside it
/// (`docs/dev/roadmap.md` 5.3).
///
/// Restoring happens **once**, in [build]: it reads the stored position, finds the chapter it
/// names, and falls back to the first chapter when the position names one the list no longer has
/// (a source that re-numbered its chapters must not lock the reader out).
///
/// Saving happens on every chapter switch and on [saveProgress]: a position that only lands on a
/// clean exit is exactly the position a user loses. Failures of the store are absorbed at this
/// boundary (C-ERR-2) — losing a bookmark must never cost the chapter.

@ProviderFor(ReaderSession)
final readerSessionProvider = ReaderSessionFamily._();

/// The reading session: which chapter is open and where the user is inside it
/// (`docs/dev/roadmap.md` 5.3).
///
/// Restoring happens **once**, in [build]: it reads the stored position, finds the chapter it
/// names, and falls back to the first chapter when the position names one the list no longer has
/// (a source that re-numbered its chapters must not lock the reader out).
///
/// Saving happens on every chapter switch and on [saveProgress]: a position that only lands on a
/// clean exit is exactly the position a user loses. Failures of the store are absorbed at this
/// boundary (C-ERR-2) — losing a bookmark must never cost the chapter.
final class ReaderSessionProvider
    extends $AsyncNotifierProvider<ReaderSession, ReaderSessionState> {
  /// The reading session: which chapter is open and where the user is inside it
  /// (`docs/dev/roadmap.md` 5.3).
  ///
  /// Restoring happens **once**, in [build]: it reads the stored position, finds the chapter it
  /// names, and falls back to the first chapter when the position names one the list no longer has
  /// (a source that re-numbered its chapters must not lock the reader out).
  ///
  /// Saving happens on every chapter switch and on [saveProgress]: a position that only lands on a
  /// clean exit is exactly the position a user loses. Failures of the store are absorbed at this
  /// boundary (C-ERR-2) — losing a bookmark must never cost the chapter.
  ReaderSessionProvider._({
    required ReaderSessionFamily super.from,
    required ReaderBook super.argument,
  }) : super(
         retry: null,
         name: r'readerSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerSessionHash();

  @override
  String toString() {
    return r'readerSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReaderSession create() => ReaderSession();

  @override
  bool operator ==(Object other) {
    return other is ReaderSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerSessionHash() => r'aa71b1c707b0bea6729c1a8e0c979b235a00ce91';

/// The reading session: which chapter is open and where the user is inside it
/// (`docs/dev/roadmap.md` 5.3).
///
/// Restoring happens **once**, in [build]: it reads the stored position, finds the chapter it
/// names, and falls back to the first chapter when the position names one the list no longer has
/// (a source that re-numbered its chapters must not lock the reader out).
///
/// Saving happens on every chapter switch and on [saveProgress]: a position that only lands on a
/// clean exit is exactly the position a user loses. Failures of the store are absorbed at this
/// boundary (C-ERR-2) — losing a bookmark must never cost the chapter.

final class ReaderSessionFamily extends $Family
    with
        $ClassFamilyOverride<
          ReaderSession,
          AsyncValue<ReaderSessionState>,
          ReaderSessionState,
          FutureOr<ReaderSessionState>,
          ReaderBook
        > {
  ReaderSessionFamily._()
    : super(
        retry: null,
        name: r'readerSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The reading session: which chapter is open and where the user is inside it
  /// (`docs/dev/roadmap.md` 5.3).
  ///
  /// Restoring happens **once**, in [build]: it reads the stored position, finds the chapter it
  /// names, and falls back to the first chapter when the position names one the list no longer has
  /// (a source that re-numbered its chapters must not lock the reader out).
  ///
  /// Saving happens on every chapter switch and on [saveProgress]: a position that only lands on a
  /// clean exit is exactly the position a user loses. Failures of the store are absorbed at this
  /// boundary (C-ERR-2) — losing a bookmark must never cost the chapter.

  ReaderSessionProvider call(ReaderBook book) =>
      ReaderSessionProvider._(argument: book, from: this);

  @override
  String toString() => r'readerSessionProvider';
}

/// The reading session: which chapter is open and where the user is inside it
/// (`docs/dev/roadmap.md` 5.3).
///
/// Restoring happens **once**, in [build]: it reads the stored position, finds the chapter it
/// names, and falls back to the first chapter when the position names one the list no longer has
/// (a source that re-numbered its chapters must not lock the reader out).
///
/// Saving happens on every chapter switch and on [saveProgress]: a position that only lands on a
/// clean exit is exactly the position a user loses. Failures of the store are absorbed at this
/// boundary (C-ERR-2) — losing a bookmark must never cost the chapter.

abstract class _$ReaderSession extends $AsyncNotifier<ReaderSessionState> {
  late final _$args = ref.$arg as ReaderBook;
  ReaderBook get book => _$args;

  FutureOr<ReaderSessionState> build(ReaderBook book);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ReaderSessionState>, ReaderSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReaderSessionState>, ReaderSessionState>,
              AsyncValue<ReaderSessionState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The reader's own settings, and the only place that writes them (`docs/dev/roadmap.md` 5.3).
///
/// `keepAlive` because the reader rebuilds its body on every scroll frame and re-reading
/// `shared_preferences` for each of those would be a platform call per frame (the same reason
/// `Settings` is `keepAlive`).

@ProviderFor(ReaderSettingsNotifier)
final readerSettingsProvider = ReaderSettingsNotifierProvider._();

/// The reader's own settings, and the only place that writes them (`docs/dev/roadmap.md` 5.3).
///
/// `keepAlive` because the reader rebuilds its body on every scroll frame and re-reading
/// `shared_preferences` for each of those would be a platform call per frame (the same reason
/// `Settings` is `keepAlive`).
final class ReaderSettingsNotifierProvider
    extends $AsyncNotifierProvider<ReaderSettingsNotifier, ReaderSettings> {
  /// The reader's own settings, and the only place that writes them (`docs/dev/roadmap.md` 5.3).
  ///
  /// `keepAlive` because the reader rebuilds its body on every scroll frame and re-reading
  /// `shared_preferences` for each of those would be a platform call per frame (the same reason
  /// `Settings` is `keepAlive`).
  ReaderSettingsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerSettingsNotifierHash();

  @$internal
  @override
  ReaderSettingsNotifier create() => ReaderSettingsNotifier();
}

String _$readerSettingsNotifierHash() =>
    r'79514dd300fe0352cfe66b46e9673efdbbd14436';

/// The reader's own settings, and the only place that writes them (`docs/dev/roadmap.md` 5.3).
///
/// `keepAlive` because the reader rebuilds its body on every scroll frame and re-reading
/// `shared_preferences` for each of those would be a platform call per frame (the same reason
/// `Settings` is `keepAlive`).

abstract class _$ReaderSettingsNotifier extends $AsyncNotifier<ReaderSettings> {
  FutureOr<ReaderSettings> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ReaderSettings>, ReaderSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReaderSettings>, ReaderSettings>,
              AsyncValue<ReaderSettings>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
