// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_tts_highlight.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Publishes what the reader should highlight while reading aloud.
///
/// It is a **separate provider on purpose**: the reader body would otherwise have to build
/// the read-aloud notifier (and with it the system engine) just to ask whether anything is being
/// spoken. Watched without a value it costs one nullable read; that notifier is the only writer.

@ProviderFor(ReaderTtsHighlighter)
final readerTtsHighlighterProvider = ReaderTtsHighlighterProvider._();

/// Publishes what the reader should highlight while reading aloud.
///
/// It is a **separate provider on purpose**: the reader body would otherwise have to build
/// the read-aloud notifier (and with it the system engine) just to ask whether anything is being
/// spoken. Watched without a value it costs one nullable read; that notifier is the only writer.
final class ReaderTtsHighlighterProvider
    extends $NotifierProvider<ReaderTtsHighlighter, ReaderTtsHighlight?> {
  /// Publishes what the reader should highlight while reading aloud.
  ///
  /// It is a **separate provider on purpose**: the reader body would otherwise have to build
  /// the read-aloud notifier (and with it the system engine) just to ask whether anything is being
  /// spoken. Watched without a value it costs one nullable read; that notifier is the only writer.
  ReaderTtsHighlighterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerTtsHighlighterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerTtsHighlighterHash();

  @$internal
  @override
  ReaderTtsHighlighter create() => ReaderTtsHighlighter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReaderTtsHighlight? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReaderTtsHighlight?>(value),
    );
  }
}

String _$readerTtsHighlighterHash() =>
    r'4c16bc4bb8c6e8a0a3ab38fd8f6e73340abc3703';

/// Publishes what the reader should highlight while reading aloud.
///
/// It is a **separate provider on purpose**: the reader body would otherwise have to build
/// the read-aloud notifier (and with it the system engine) just to ask whether anything is being
/// spoken. Watched without a value it costs one nullable read; that notifier is the only writer.

abstract class _$ReaderTtsHighlighter extends $Notifier<ReaderTtsHighlight?> {
  ReaderTtsHighlight? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReaderTtsHighlight?, ReaderTtsHighlight?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReaderTtsHighlight?, ReaderTtsHighlight?>,
              ReaderTtsHighlight?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
