// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_tts_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads the open book aloud with the system TTS engine
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// It watches the session's **chapter index** (not its offset) so the session stays alive while the
/// sheet is closed, and a chapter change is what starts the next chapter. A chapter is split into
/// utterance-sized chunks ([splitSpeechText]), spoken one after another; the last chunk advances the
/// session, which rebuilds this notifier and starts the next chapter.
///
/// The provider is kept alive while it speaks, so “continue after leaving the reader” can work; the
/// sheet's switch (stored as [ReaderSettings.stopTtsOnExit]) decides whether closing the page
/// stops it.

@ProviderFor(ReaderTts)
final readerTtsProvider = ReaderTtsFamily._();

/// Reads the open book aloud with the system TTS engine
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// It watches the session's **chapter index** (not its offset) so the session stays alive while the
/// sheet is closed, and a chapter change is what starts the next chapter. A chapter is split into
/// utterance-sized chunks ([splitSpeechText]), spoken one after another; the last chunk advances the
/// session, which rebuilds this notifier and starts the next chapter.
///
/// The provider is kept alive while it speaks, so “continue after leaving the reader” can work; the
/// sheet's switch (stored as [ReaderSettings.stopTtsOnExit]) decides whether closing the page
/// stops it.
final class ReaderTtsProvider
    extends $AsyncNotifierProvider<ReaderTts, ReaderTtsState> {
  /// Reads the open book aloud with the system TTS engine
  /// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
  ///
  /// It watches the session's **chapter index** (not its offset) so the session stays alive while the
  /// sheet is closed, and a chapter change is what starts the next chapter. A chapter is split into
  /// utterance-sized chunks ([splitSpeechText]), spoken one after another; the last chunk advances the
  /// session, which rebuilds this notifier and starts the next chapter.
  ///
  /// The provider is kept alive while it speaks, so “continue after leaving the reader” can work; the
  /// sheet's switch (stored as [ReaderSettings.stopTtsOnExit]) decides whether closing the page
  /// stops it.
  ReaderTtsProvider._({
    required ReaderTtsFamily super.from,
    required ReaderBook super.argument,
  }) : super(
         retry: null,
         name: r'readerTtsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerTtsHash();

  @override
  String toString() {
    return r'readerTtsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReaderTts create() => ReaderTts();

  @override
  bool operator ==(Object other) {
    return other is ReaderTtsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerTtsHash() => r'7c07a5489f5f4fe1e2ff6d029bca0cd513cc40b2';

/// Reads the open book aloud with the system TTS engine
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// It watches the session's **chapter index** (not its offset) so the session stays alive while the
/// sheet is closed, and a chapter change is what starts the next chapter. A chapter is split into
/// utterance-sized chunks ([splitSpeechText]), spoken one after another; the last chunk advances the
/// session, which rebuilds this notifier and starts the next chapter.
///
/// The provider is kept alive while it speaks, so “continue after leaving the reader” can work; the
/// sheet's switch (stored as [ReaderSettings.stopTtsOnExit]) decides whether closing the page
/// stops it.

final class ReaderTtsFamily extends $Family
    with
        $ClassFamilyOverride<
          ReaderTts,
          AsyncValue<ReaderTtsState>,
          ReaderTtsState,
          FutureOr<ReaderTtsState>,
          ReaderBook
        > {
  ReaderTtsFamily._()
    : super(
        retry: null,
        name: r'readerTtsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reads the open book aloud with the system TTS engine
  /// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
  ///
  /// It watches the session's **chapter index** (not its offset) so the session stays alive while the
  /// sheet is closed, and a chapter change is what starts the next chapter. A chapter is split into
  /// utterance-sized chunks ([splitSpeechText]), spoken one after another; the last chunk advances the
  /// session, which rebuilds this notifier and starts the next chapter.
  ///
  /// The provider is kept alive while it speaks, so “continue after leaving the reader” can work; the
  /// sheet's switch (stored as [ReaderSettings.stopTtsOnExit]) decides whether closing the page
  /// stops it.

  ReaderTtsProvider call(ReaderBook book) =>
      ReaderTtsProvider._(argument: book, from: this);

  @override
  String toString() => r'readerTtsProvider';
}

/// Reads the open book aloud with the system TTS engine
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// It watches the session's **chapter index** (not its offset) so the session stays alive while the
/// sheet is closed, and a chapter change is what starts the next chapter. A chapter is split into
/// utterance-sized chunks ([splitSpeechText]), spoken one after another; the last chunk advances the
/// session, which rebuilds this notifier and starts the next chapter.
///
/// The provider is kept alive while it speaks, so “continue after leaving the reader” can work; the
/// sheet's switch (stored as [ReaderSettings.stopTtsOnExit]) decides whether closing the page
/// stops it.

abstract class _$ReaderTts extends $AsyncNotifier<ReaderTtsState> {
  late final _$args = ref.$arg as ReaderBook;
  ReaderBook get book => _$args;

  FutureOr<ReaderTtsState> build(ReaderBook book);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ReaderTtsState>, ReaderTtsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReaderTtsState>, ReaderTtsState>,
              AsyncValue<ReaderTtsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
