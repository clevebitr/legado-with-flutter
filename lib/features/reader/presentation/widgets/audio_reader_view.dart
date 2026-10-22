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
    final AsyncValue<AudioReaderState> state = ref.watch(
      audioReaderProvider(widget.book),
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
          AsyncData<AudioReaderState>(:final AudioReaderState value) => _body(
            value,
            known,
            index,
          ),
          AsyncError<AudioReaderState>() => StateMessage(
            message: l10n.readerAudioFailed,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  /// The player, its failure state, or the empty-book message.
  Widget _body(
    AudioReaderState state,
    List<ReadingChapter> chapters,
    int index,
  ) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (chapters.isEmpty) {
      return StateMessage(message: l10n.readerNoChapter);
    }
    if (state.failure != null) {
      return _failure(l10n);
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
          Icon(Icons.headphones, color: Theme.of(context).colorScheme.primary),
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
          if (state.tracks.length > 1) ...<Widget>[
            SizedBox(height: tokens.spacing.xs),
            Text(
              l10n.readerAudioTrackCount(
                state.trackIndex + 1,
                state.tracks.length,
              ),
              textAlign: TextAlign.center,
              style: tokens.typography.base.labelMedium,
            ),
          ],
          SizedBox(height: tokens.spacing.xl),
          _positionSlider(state),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                _format(state.position),
                style: tokens.typography.base.labelSmall,
              ),
              Text(
                _format(state.duration ?? Duration.zero),
                style: tokens.typography.base.labelSmall,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.md),
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

  /// The seek slider; dragging only moves the label until the finger lifts.
  Widget _positionSlider(AudioReaderState state) {
    final double total = (state.duration ?? Duration.zero).inMilliseconds
        .toDouble();
    final double current = state.position.inMilliseconds
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
  Widget _failure(AppLocalizations l10n) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              l10n.readerAudioFailed,
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

/// The playback speeds the player offers (ADR-0054 §决策 4).
const List<double> audioSpeedSteps = <double>[0.75, 1, 1.25, 1.5, 2];

/// A compact label for a speed multiplier: `1` instead of `1.0`, `0.75` unchanged.
String _speedLabel(double speed) {
  final String fixed = speed.toStringAsFixed(2);

  return fixed.replaceAll(RegExp(r'\.?0+$'), '');
}

/// The icon of the middle button: pause while playing, replay when the track ended.
IconData _playIcon(AudioReaderState state) {
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
