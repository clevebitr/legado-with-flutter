// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_reader_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads one chapter's audio tracks for the player (`docs/dev/roadmap.md` §3.10).
///
/// Like the text content provider, it is keyed by the chapter so leaving the chapter disposes the
/// request instead of writing into a dead notifier.

@ProviderFor(readerAudioTracks)
final readerAudioTracksProvider = ReaderAudioTracksFamily._();

/// Reads one chapter's audio tracks for the player (`docs/dev/roadmap.md` §3.10).
///
/// Like the text content provider, it is keyed by the chapter so leaving the chapter disposes the
/// request instead of writing into a dead notifier.

final class ReaderAudioTracksProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<List<ReaderAudioTrack>>>,
          ParseResult<List<ReaderAudioTrack>>,
          FutureOr<ParseResult<List<ReaderAudioTrack>>>
        >
    with
        $FutureModifier<ParseResult<List<ReaderAudioTrack>>>,
        $FutureProvider<ParseResult<List<ReaderAudioTrack>>> {
  /// Reads one chapter's audio tracks for the player (`docs/dev/roadmap.md` §3.10).
  ///
  /// Like the text content provider, it is keyed by the chapter so leaving the chapter disposes the
  /// request instead of writing into a dead notifier.
  ReaderAudioTracksProvider._({
    required ReaderAudioTracksFamily super.from,
    required (ReaderBook, ReadingChapter) super.argument,
  }) : super(
         retry: null,
         name: r'readerAudioTracksProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerAudioTracksHash();

  @override
  String toString() {
    return r'readerAudioTracksProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<List<ReaderAudioTrack>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<List<ReaderAudioTrack>>> create(Ref ref) {
    final argument = this.argument as (ReaderBook, ReadingChapter);
    return readerAudioTracks(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderAudioTracksProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerAudioTracksHash() => r'8f3dde16a26b2b9f2f343ed8b0bf05a657a52906';

/// Reads one chapter's audio tracks for the player (`docs/dev/roadmap.md` §3.10).
///
/// Like the text content provider, it is keyed by the chapter so leaving the chapter disposes the
/// request instead of writing into a dead notifier.

final class ReaderAudioTracksFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<List<ReaderAudioTrack>>>,
          (ReaderBook, ReadingChapter)
        > {
  ReaderAudioTracksFamily._()
    : super(
        retry: null,
        name: r'readerAudioTracksProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads one chapter's audio tracks for the player (`docs/dev/roadmap.md` §3.10).
  ///
  /// Like the text content provider, it is keyed by the chapter so leaving the chapter disposes the
  /// request instead of writing into a dead notifier.

  ReaderAudioTracksProvider call((ReaderBook, ReadingChapter) request) =>
      ReaderAudioTracksProvider._(argument: request, from: this);

  @override
  String toString() => r'readerAudioTracksProvider';
}

/// Plays the current chapter of [book] (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// It is keyed by the book and rebuilds when the session's **chapter index** changes. It does not
/// watch the whole session value: every five seconds the offset changes, and a rebuild would
/// re-load the track and restart playback from the beginning.
///
/// The engine is watched from [audioPlaybackEngineProvider], which owns its disposal, so a chapter
/// switch keeps the same native player while a page exit releases it.

@ProviderFor(AudioReader)
final audioReaderProvider = AudioReaderFamily._();

/// Plays the current chapter of [book] (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// It is keyed by the book and rebuilds when the session's **chapter index** changes. It does not
/// watch the whole session value: every five seconds the offset changes, and a rebuild would
/// re-load the track and restart playback from the beginning.
///
/// The engine is watched from [audioPlaybackEngineProvider], which owns its disposal, so a chapter
/// switch keeps the same native player while a page exit releases it.
final class AudioReaderProvider
    extends $AsyncNotifierProvider<AudioReader, AudioReaderState> {
  /// Plays the current chapter of [book] (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
  ///
  /// It is keyed by the book and rebuilds when the session's **chapter index** changes. It does not
  /// watch the whole session value: every five seconds the offset changes, and a rebuild would
  /// re-load the track and restart playback from the beginning.
  ///
  /// The engine is watched from [audioPlaybackEngineProvider], which owns its disposal, so a chapter
  /// switch keeps the same native player while a page exit releases it.
  AudioReaderProvider._({
    required AudioReaderFamily super.from,
    required ReaderBook super.argument,
  }) : super(
         retry: null,
         name: r'audioReaderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$audioReaderHash();

  @override
  String toString() {
    return r'audioReaderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AudioReader create() => AudioReader();

  @override
  bool operator ==(Object other) {
    return other is AudioReaderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$audioReaderHash() => r'd987435ca0b400cae77f08f128a2f6767bf18e17';

/// Plays the current chapter of [book] (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// It is keyed by the book and rebuilds when the session's **chapter index** changes. It does not
/// watch the whole session value: every five seconds the offset changes, and a rebuild would
/// re-load the track and restart playback from the beginning.
///
/// The engine is watched from [audioPlaybackEngineProvider], which owns its disposal, so a chapter
/// switch keeps the same native player while a page exit releases it.

final class AudioReaderFamily extends $Family
    with
        $ClassFamilyOverride<
          AudioReader,
          AsyncValue<AudioReaderState>,
          AudioReaderState,
          FutureOr<AudioReaderState>,
          ReaderBook
        > {
  AudioReaderFamily._()
    : super(
        retry: null,
        name: r'audioReaderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Plays the current chapter of [book] (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
  ///
  /// It is keyed by the book and rebuilds when the session's **chapter index** changes. It does not
  /// watch the whole session value: every five seconds the offset changes, and a rebuild would
  /// re-load the track and restart playback from the beginning.
  ///
  /// The engine is watched from [audioPlaybackEngineProvider], which owns its disposal, so a chapter
  /// switch keeps the same native player while a page exit releases it.

  AudioReaderProvider call(ReaderBook book) =>
      AudioReaderProvider._(argument: book, from: this);

  @override
  String toString() => r'audioReaderProvider';
}

/// Plays the current chapter of [book] (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// It is keyed by the book and rebuilds when the session's **chapter index** changes. It does not
/// watch the whole session value: every five seconds the offset changes, and a rebuild would
/// re-load the track and restart playback from the beginning.
///
/// The engine is watched from [audioPlaybackEngineProvider], which owns its disposal, so a chapter
/// switch keeps the same native player while a page exit releases it.

abstract class _$AudioReader extends $AsyncNotifier<AudioReaderState> {
  late final _$args = ref.$arg as ReaderBook;
  ReaderBook get book => _$args;

  FutureOr<AudioReaderState> build(ReaderBook book);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AudioReaderState>, AudioReaderState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AudioReaderState>, AudioReaderState>,
              AsyncValue<AudioReaderState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
