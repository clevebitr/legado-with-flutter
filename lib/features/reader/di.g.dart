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

/// Provides the audio player, **unbound** to a platform until it is really needed.
///
/// The adapter creates a native player in its constructor, so this provider is only instantiated
/// when an audio book is opened (or a test overrides it). Its own disposal releases the native
/// player once the page stops watching it.

@ProviderFor(audioPlaybackEngine)
final audioPlaybackEngineProvider = AudioPlaybackEngineProvider._();

/// Provides the audio player, **unbound** to a platform until it is really needed.
///
/// The adapter creates a native player in its constructor, so this provider is only instantiated
/// when an audio book is opened (or a test overrides it). Its own disposal releases the native
/// player once the page stops watching it.

final class AudioPlaybackEngineProvider
    extends
        $FunctionalProvider<
          AudioPlaybackEngine,
          AudioPlaybackEngine,
          AudioPlaybackEngine
        >
    with $Provider<AudioPlaybackEngine> {
  /// Provides the audio player, **unbound** to a platform until it is really needed.
  ///
  /// The adapter creates a native player in its constructor, so this provider is only instantiated
  /// when an audio book is opened (or a test overrides it). Its own disposal releases the native
  /// player once the page stops watching it.
  AudioPlaybackEngineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlaybackEngineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlaybackEngineHash();

  @$internal
  @override
  $ProviderElement<AudioPlaybackEngine> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioPlaybackEngine create(Ref ref) {
    return audioPlaybackEngine(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlaybackEngine value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlaybackEngine>(value),
    );
  }
}

String _$audioPlaybackEngineHash() =>
    r'60cceec4fe17a9cdb3d98827acd387157aae82ab';

/// Provides the system TTS engine (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).

@ProviderFor(speechSynthesizer)
final speechSynthesizerProvider = SpeechSynthesizerProvider._();

/// Provides the system TTS engine (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).

final class SpeechSynthesizerProvider
    extends
        $FunctionalProvider<
          SpeechSynthesizer,
          SpeechSynthesizer,
          SpeechSynthesizer
        >
    with $Provider<SpeechSynthesizer> {
  /// Provides the system TTS engine (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
  SpeechSynthesizerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'speechSynthesizerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$speechSynthesizerHash();

  @$internal
  @override
  $ProviderElement<SpeechSynthesizer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SpeechSynthesizer create(Ref ref) {
    return speechSynthesizer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SpeechSynthesizer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SpeechSynthesizer>(value),
    );
  }
}

String _$speechSynthesizerHash() => r'736b1e84895f98f7e0d43a6fb9b6960ac11beacb';

/// Provides the audio-track port, **unbound** by default.
///
/// The composition root binds it to `book_source`'s `FetchAudioTracks` (ADR-0041 §决策 2).

@ProviderFor(readerAudioTrack)
final readerAudioTrackProvider = ReaderAudioTrackProvider._();

/// Provides the audio-track port, **unbound** by default.
///
/// The composition root binds it to `book_source`'s `FetchAudioTracks` (ADR-0041 §决策 2).

final class ReaderAudioTrackProvider
    extends
        $FunctionalProvider<
          AudioTrackProvider,
          AudioTrackProvider,
          AudioTrackProvider
        >
    with $Provider<AudioTrackProvider> {
  /// Provides the audio-track port, **unbound** by default.
  ///
  /// The composition root binds it to `book_source`'s `FetchAudioTracks` (ADR-0041 §决策 2).
  ReaderAudioTrackProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerAudioTrackProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerAudioTrackHash();

  @$internal
  @override
  $ProviderElement<AudioTrackProvider> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioTrackProvider create(Ref ref) {
    return readerAudioTrack(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioTrackProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioTrackProvider>(value),
    );
  }
}

String _$readerAudioTrackHash() => r'302ea06f6920d7d0ea3896e5e77b0a89dd82e46d';

/// Provides the source-kind port, **unbound** by default (text).

@ProviderFor(readerSourceKind)
final readerSourceKindProvider = ReaderSourceKindProvider._();

/// Provides the source-kind port, **unbound** by default (text).

final class ReaderSourceKindProvider
    extends
        $FunctionalProvider<
          SourceKindProvider,
          SourceKindProvider,
          SourceKindProvider
        >
    with $Provider<SourceKindProvider> {
  /// Provides the source-kind port, **unbound** by default (text).
  ReaderSourceKindProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerSourceKindProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerSourceKindHash();

  @$internal
  @override
  $ProviderElement<SourceKindProvider> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SourceKindProvider create(Ref ref) {
    return readerSourceKind(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceKindProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceKindProvider>(value),
    );
  }
}

String _$readerSourceKindHash() => r'5fc89b68d08486f77979ea283e3c25c78be87aa0';

/// What the open book source serves; the reader page dispatches on it
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).

@ProviderFor(readerMediaKind)
final readerMediaKindProvider = ReaderMediaKindFamily._();

/// What the open book source serves; the reader page dispatches on it
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).

final class ReaderMediaKindProvider
    extends
        $FunctionalProvider<
          AsyncValue<ReaderMediaKind>,
          ReaderMediaKind,
          FutureOr<ReaderMediaKind>
        >
    with $FutureModifier<ReaderMediaKind>, $FutureProvider<ReaderMediaKind> {
  /// What the open book source serves; the reader page dispatches on it
  /// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).
  ReaderMediaKindProvider._({
    required ReaderMediaKindFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'readerMediaKindProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerMediaKindHash();

  @override
  String toString() {
    return r'readerMediaKindProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReaderMediaKind> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ReaderMediaKind> create(Ref ref) {
    final argument = this.argument as String;
    return readerMediaKind(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderMediaKindProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerMediaKindHash() => r'371d06ae2c840184d3ba515dd7e2de3429b3cc06';

/// What the open book source serves; the reader page dispatches on it
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).

final class ReaderMediaKindFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReaderMediaKind>, String> {
  ReaderMediaKindFamily._()
    : super(
        retry: null,
        name: r'readerMediaKindProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// What the open book source serves; the reader page dispatches on it
  /// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).

  ReaderMediaKindProvider call(String sourceUrl) =>
      ReaderMediaKindProvider._(argument: sourceUrl, from: this);

  @override
  String toString() => r'readerMediaKindProvider';
}

/// Provides the media-notification binding for this platform
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3/4).

@ProviderFor(playbackNotification)
final playbackNotificationProvider = PlaybackNotificationProvider._();

/// Provides the media-notification binding for this platform
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3/4).

final class PlaybackNotificationProvider
    extends
        $FunctionalProvider<
          PlaybackNotification,
          PlaybackNotification,
          PlaybackNotification
        >
    with $Provider<PlaybackNotification> {
  /// Provides the media-notification binding for this platform
  /// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3/4).
  PlaybackNotificationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackNotificationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackNotificationHash();

  @$internal
  @override
  $ProviderElement<PlaybackNotification> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PlaybackNotification create(Ref ref) {
    return playbackNotification(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackNotification value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackNotification>(value),
    );
  }
}

String _$playbackNotificationHash() =>
    r'44d8091be3ca7e4ceaa879a1f7398333d2d6608b';
