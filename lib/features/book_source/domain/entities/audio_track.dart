import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_track.freezed.dart';

/// One playable address of an audio chapter (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 2).
///
/// An audio source's `ruleContent.content` yields **addresses**, not text: one matched value is
/// one track, and a chapter that names several (a multi-part episode) keeps them in rule order.
///
/// [headers] is the source's own request-header rule evaluated once for the chapter page. Audio
/// CDNs behind the same site usually accept the same headers, so the player sends them on the
/// media request too; an empty map means "no extra headers", never "drop the defaults".
///
/// A title or a declared duration is deliberately **not** modelled: Legado's `ruleContent` has no
/// field that supplies either, the chapter already carries the display title, and the duration the
/// UI shows is the one the player reports after loading the stream (ADR-0054 落地注记).
@freezed
abstract class AudioTrack with _$AudioTrack {
  /// Creates one audio track.
  const factory AudioTrack({
    /// The absolute `http(s)` address of the media stream.
    required String url,

    /// Headers the source declared for its requests, sent with the media request too.
    @Default(<String, String>{}) Map<String, String> headers,
  }) = _AudioTrack;
}
