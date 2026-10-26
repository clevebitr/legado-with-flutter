import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/audio_reader_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_session_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_toc_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The player for an audio book (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// It is the audio half of `ReaderPage`'s dispatch: the page, the session and the chapter list are
/// shared with the text reader, but the body is a player instead of a scroll view. The view holds
/// only the scrub position while a finger is down — every other value lives in [AudioReader].
///
/// **The page follows [AudioReaderSkeleton], not the whole state** (ADR-0064 §决策 1): the notifier
/// republishes the position on every engine snapshot (~5/s), and rebuilding the app bar, the tooltips,
/// the speed chips and the slider on each of them kept the Windows UIA bridge busy enough to log
/// `Failed to update ui::AXTree … Nodes left pending by the update` on every update while a source
/// played. Only the position row (and the two time labels beside it) watches the ticking value.
class AudioReaderView extends ConsumerStatefulWidget {
  /// Creates the player for [book].
  const AudioReaderView({required this.book, super.key});

  /// The book being listened to.
  final ReaderBook book;

  @override
  ConsumerState<AudioReaderView> createState() => _AudioReaderViewState();
}

class _AudioReaderViewState extends ConsumerState<AudioReaderView> {
  /// Captured in `initState` so `dispose` can still stop playback and the notification.
  ///
  /// Reading it lazily (a `late` initializer) would touch `ref` from `dispose`, which Riverpod
  /// rejects because the widget is already unmounted.
  late final AudioReader _audio;

  /// The scratch position while the user drags the slider, or `null`.
  double? _scrubbing;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioReaderProvider(widget.book).notifier);
  }

  @override
  void dispose() {
    unawaited(_audio.onReaderClosed());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<AudioReaderSkeleton> state = ref.watch(
      audioReaderProvider(widget.book).select(audioReaderPageState),
    );
    final AsyncValue<ParseResult<List<ReadingChapter>>> chapters = ref.watch(
      readerChaptersProvider(widget.book),
    );
    final List<ReadingChapter> known = _chaptersOf(chapters);
    final int index = ref.watch(readerChapterIndexProvider(widget.book)) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: l10n.readerTocAction,
            onPressed: known.isEmpty ? null : () => _openToc(known, index),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (state) {
          AsyncData<AudioReaderSkeleton>(:final AudioReaderSkeleton value) =>
            _body(value, known, index),
          AsyncError<AudioReaderSkeleton>() => StateMessage(
            message: l10n.readerAudioFailed,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  /// The player, its failure state, or the empty-book message.
  Widget _body(
    AudioReaderSkeleton state,
    List<ReadingChapter> chapters,
    int index,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (chapters.isEmpty) {
      return StateMessage(message: l10n.readerNoChapter);
    }
    if (state.failureRulePath != null) {
      return _failure(l10n, state);
    }
    if (!state.hasTrack) {
      return const Center(child: CircularProgressIndicator());
    }
    final M3ETheme tokens = context.m3e;
    final ReadingChapter chapter =
        chapters[index.clamp(0, chapters.length - 1)];

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.isLoading || state.isBuffering)
            const LinearProgressIndicator(),
          SizedBox(height: tokens.spacing.lg),
          // 音频页的主意象：圆形色块里的耳机，比一个 24dp 的裸图标更像「正在播放」。
          Center(
            child: Container(
              width: tokens.spacing.xxl * 2,
              height: tokens.spacing.xxl * 2,
              decoration: BoxDecoration(
                color: tokens.colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.headphones,
                size: tokens.spacing.xl,
                color: tokens.colors.onPrimaryContainer,
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.lg),
          Text(
            chapter.title,
            textAlign: TextAlign.center,
            style: tokens.typography.base.titleLarge,
          ),
          SizedBox(height: tokens.spacing.xs),
          Text(
            l10n.readerChapterProgress(index + 1, chapters.length),
            textAlign: TextAlign.center,
            style: tokens.typography.base.labelMedium,
          ),
          if (state.trackCount > 1) ...<Widget>[
            SizedBox(height: tokens.spacing.xs),
            Text(
              l10n.readerAudioTrackCount(
                state.trackIndex + 1,
                state.trackCount,
              ),
              textAlign: TextAlign.center,
              style: tokens.typography.base.labelMedium,
            ),
          ],
          SizedBox(height: tokens.spacing.xl),
          _positionRow(tokens, state),
          SizedBox(height: tokens.spacing.md),
          // 三个按钮在窄屏上也会各自保留 48dp 的点击区，`spaceEvenly` 不会把它们挤在一起。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.skip_previous),
                tooltip: l10n.readerPreviousChapter,
                onPressed: index > 0 ? _audio.previousChapter : null,
              ),
              IconButton.filled(
                icon: Icon(_playIcon(state)),
                tooltip: state.isPlaying
                    ? l10n.readerAudioPause
                    : state.isCompleted
                    ? l10n.readerAudioReplay
                    : l10n.readerAudioPlay,
                onPressed: () => unawaited(_audio.toggle()),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                tooltip: l10n.readerNextChapter,
                onPressed: index + 1 < chapters.length
                    ? _audio.nextChapter
                    : null,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.lg),
          Text(l10n.readerAudioSpeed, style: tokens.typography.base.labelLarge),
          SizedBox(height: tokens.spacing.xs),
          Wrap(
            spacing: tokens.spacing.sm,
            children: <Widget>[
              for (final double speed in audioSpeedSteps)
                ChoiceChip(
                  label: Text(l10n.readerAudioSpeedValue(_speedLabel(speed))),
                  selected: state.speed == speed,
                  onSelected: (bool selected) {
                    if (selected) {
                      unawaited(_audio.setSpeed(speed));
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The seek slider and the two time labels — the only part that follows the ticking position.
  ///
  /// Its own [Consumer] watches just `position`, so an engine snapshot rebuilds this row (a few
  /// text runs and one slider) instead of the page's whole semantics subtree (ADR-0064 §决策 1).
  Widget _positionRow(M3ETheme tokens, AudioReaderSkeleton skeleton) {
    final Duration? duration = skeleton.duration;

    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? _) {
        final Duration position = ref.watch(
          audioReaderProvider(widget.book).select(
            (AsyncValue<AudioReaderState> value) =>
                value.value?.position ?? Duration.zero,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _positionSlider(position, duration),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _format(position),
                  style: tokens.typography.base.labelSmall,
                ),
                Text(
                  _format(duration ?? Duration.zero),
                  style: tokens.typography.base.labelSmall,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// The seek slider; dragging only moves the label until the finger lifts.
  Widget _positionSlider(Duration position, Duration? duration) {
    final double total = (duration ?? Duration.zero).inMilliseconds.toDouble();
    final double current = position.inMilliseconds
        .toDouble()
        .clamp(0, total)
        .toDouble();
    final double? scrubbing = _scrubbing;

    return Slider(
      value: total <= 0 ? 0 : (scrubbing ?? current).clamp(0, total).toDouble(),
      max: total <= 0 ? 1 : total,
      semanticFormatterCallback: (double value) =>
          _format(Duration(milliseconds: value.round())),
      onChanged: total <= 0
          ? null
          : (double value) => setState(() => _scrubbing = value),
      onChangeEnd: total <= 0
          ? null
          : (double value) {
              setState(() => _scrubbing = null);
              unawaited(_audio.seek(Duration(milliseconds: value.round())));
            },
    );
  }

  /// The failure state: one sentence and a retry that re-reads the chapter.
  Widget _failure(AppLocalizations l10n, AudioReaderSkeleton skeleton) {
    final M3ETheme tokens = context.m3e;
    final bool plainHttp = skeleton.failureRulePath == 'reader.audioPlainHttp';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              plainHttp ? l10n.readerAudioPlainHttp : l10n.readerAudioFailed,
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
            SizedBox(height: tokens.spacing.lg),
            FilledButton(
              onPressed: _audio.retry,
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      ),
    );
  }

  void _openToc(List<ReadingChapter> chapters, int currentIndex) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: ReaderTocSheet(
            chapters: chapters,
            currentIndex: currentIndex.clamp(0, chapters.length - 1),
            onSelected: (int index) {
              Navigator.of(context).pop();
              unawaited(
                ref
                    .read(readerSessionProvider(widget.book).notifier)
                    .selectChapter(index),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The chapters of a loaded list, or an empty list while it is loading or failed.
  List<ReadingChapter> _chaptersOf(
    AsyncValue<ParseResult<List<ReadingChapter>>> value,
  ) => switch (value.value) {
    ParseSuccess<List<ReadingChapter>>(:final List<ReadingChapter> data) =>
      data,
    _ => const <ReadingChapter>[],
  };
}

/// Everything the player page's **structure** depends on, with the ticking position left out.
///
/// `AudioReader` republishes `position` on every engine snapshot (~5/s). Watching the whole state
/// rebuilt the app bar, the tooltips, the speed chips and the slider five times a second; on
/// Windows the embedder answers that churn with
/// `Failed to update ui::AXTree … Nodes left pending by the update` on every update
/// (ADR-0064 §决策 1). The page therefore watches this projection — a value type whose equality
/// only changes when the layout would — and the position row watches `position` on its own.
///
/// Adding a field to `AudioReaderState` means deciding which side it belongs to: **structure**
/// lives here, anything that changes per snapshot tick does not.
typedef AudioReaderSkeleton = ({
  /// Whether there is a track to show the controls for.
  bool hasTrack,

  /// The `rulePath` of the failure to show, or `null` when playback is fine.
  String? failureRulePath,

  /// Whether the chapter's tracks are still loading.
  bool isLoading,

  /// Whether the player is buffering.
  bool isBuffering,

  /// Whether it is playing (drives the middle button's icon and tooltip).
  bool isPlaying,

  /// Whether the current track ended (drives the replay icon).
  bool isCompleted,

  /// The selected speed (drives the chip selection).
  double speed,

  /// How many tracks the chapter has, and which one plays.
  int trackCount,
  int trackIndex,

  /// The track's length; `null` while unknown. It is structure, not a tick: it changes once per
  /// track, and the position row needs it as the slider's maximum.
  Duration? duration,
});

/// The projection the page's `select` watches: the async value with only the structure inside.
///
/// Exported so the "a position tick must not rebuild the page" test can subscribe to the very
/// expression the view uses instead of copying it (ADR-0064 §决策 1).
AsyncValue<AudioReaderSkeleton> audioReaderPageState(
  AsyncValue<AudioReaderState> value,
) => value.whenData(audioReaderSkeleton);

/// Projects [state] onto [AudioReaderSkeleton], dropping the per-snapshot position.
AudioReaderSkeleton audioReaderSkeleton(AudioReaderState state) => (
  hasTrack: state.hasTrack,
  failureRulePath: state.failure?.rulePath,
  isLoading: state.isLoading,
  isBuffering: state.isBuffering,
  isPlaying: state.isPlaying,
  isCompleted: state.isCompleted,
  speed: state.speed,
  trackCount: state.tracks.length,
  trackIndex: state.trackIndex,
  duration: state.duration,
);

/// The playback speeds the player offers (ADR-0054 §决策 4).
const List<double> audioSpeedSteps = <double>[0.75, 1, 1.25, 1.5, 2];

/// A compact label for a speed multiplier: `1` instead of `1.0`, `0.75` unchanged.
String _speedLabel(double speed) {
  final String fixed = speed.toStringAsFixed(2);

  return fixed.replaceAll(RegExp(r'\.?0+$'), '');
}

/// The icon of the middle button: pause while playing, replay when the track ended.
IconData _playIcon(AudioReaderSkeleton state) {
  if (state.isPlaying) {
    return Icons.pause;
  }

  return state.isCompleted ? Icons.replay : Icons.play_arrow;
}

/// Formats a playback position as `m:ss` or `h:mm:ss`.
String _format(Duration value) {
  final int seconds = value.inSeconds;
  final String two = (seconds % 60).toString().padLeft(2, '0');
  final int minutes = seconds ~/ 60;
  if (minutes < 60) {
    return '$minutes:$two';
  }
  final String minutesTwo = (minutes % 60).toString().padLeft(2, '0');

  return '${minutes ~/ 60}:$minutesTwo:$two';
}
