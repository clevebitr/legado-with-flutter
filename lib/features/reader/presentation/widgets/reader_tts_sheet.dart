import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reader_tts_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// The read-aloud controls (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// Start / pause / resume / stop, the three voice axes and the exit switch. Everything it changes
/// goes through [ReaderTts], which also persists the voice axes in `ReaderSettings`; the sheet
/// itself only keeps the slider scratch values of a drag that has not been released yet.
class ReaderTtsSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [book].
  const ReaderTtsSheet({required this.book, super.key});

  /// The book being read aloud.
  final ReaderBook book;

  @override
  ConsumerState<ReaderTtsSheet> createState() => _ReaderTtsSheetState();
}

class _ReaderTtsSheetState extends ConsumerState<ReaderTtsSheet> {
  /// The rate while the finger is down, or `null`.
  double? _rate;

  /// The pitch while the finger is down, or `null`.
  double? _pitch;

  /// The item that means “the platform's default voice”.
  static const SpeechVoice _systemVoice = SpeechVoice(name: '');

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<ReaderTtsState> async = ref.watch(
      readerTtsProvider(widget.book),
    );
    final ReaderTtsState? state = async.value;
    if (state == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    final ReaderTts tts = ref.read(readerTtsProvider(widget.book).notifier);
    final SpeechVoice? selected = state.voice;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.readerTtsTitle, style: tokens.typography.base.titleLarge),
            SizedBox(height: tokens.spacing.md),
            if (state.failure != null) ...<Widget>[
              Text(
                l10n.readerTtsFailed,
                style: tokens.typography.base.bodyMedium,
              ),
              SizedBox(height: tokens.spacing.sm),
            ],
            if (state.isPreparing) ...<Widget>[
              const LinearProgressIndicator(),
              SizedBox(height: tokens.spacing.sm),
            ],
            Wrap(
              spacing: tokens.spacing.sm,
              runSpacing: tokens.spacing.xs,
              children: <Widget>[
                if (!state.isActive)
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(l10n.readerTtsStart),
                    onPressed: () => unawaited(tts.start()),
                  )
                else ...<Widget>[
                  if (state.isPaused)
                    FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(l10n.readerTtsResume),
                      onPressed: () => unawaited(tts.resume()),
                    )
                  else
                    FilledButton.icon(
                      icon: const Icon(Icons.pause),
                      label: Text(l10n.readerTtsPause),
                      onPressed: () => unawaited(tts.pause()),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: Text(l10n.readerTtsStop),
                    onPressed: () => unawaited(tts.stop()),
                  ),
                ],
              ],
            ),
            SizedBox(height: tokens.spacing.lg),
            Text(l10n.readerTtsRate, style: tokens.typography.base.labelLarge),
            Slider(
              value: (_rate ?? state.rate).clamp(minTtsRate, maxTtsRate),
              min: minTtsRate,
              max: maxTtsRate,
              divisions: 6,
              label: (_rate ?? state.rate).toStringAsFixed(2),
              onChanged: (double value) => setState(() => _rate = value),
              onChangeEnd: (double value) {
                setState(() => _rate = null);
                unawaited(tts.applyRate(value));
              },
            ),
            Text(l10n.readerTtsPitch, style: tokens.typography.base.labelLarge),
            Slider(
              value: (_pitch ?? state.pitch).clamp(minTtsPitch, maxTtsPitch),
              min: minTtsPitch,
              max: maxTtsPitch,
              divisions: 6,
              label: (_pitch ?? state.pitch).toStringAsFixed(2),
              onChanged: (double value) => setState(() => _pitch = value),
              onChangeEnd: (double value) {
                setState(() => _pitch = null);
                unawaited(tts.applyPitch(value));
              },
            ),
            SizedBox(height: tokens.spacing.sm),
            Text(l10n.readerTtsVoice, style: tokens.typography.base.labelLarge),
            SizedBox(height: tokens.spacing.xs),
            DropdownButton<SpeechVoice>(
              isExpanded: true,
              value: selected ?? _systemVoice,
              items: <DropdownMenuItem<SpeechVoice>>[
                DropdownMenuItem<SpeechVoice>(
                  value: _systemVoice,
                  child: Text(l10n.readerTtsSystemVoice),
                ),
                for (final SpeechVoice voice in state.voices)
                  DropdownMenuItem<SpeechVoice>(
                    value: voice,
                    child: Text(
                      l10n.readerTtsVoiceLabel(voice.name, voice.locale),
                    ),
                  ),
              ],
              onChanged: (SpeechVoice? voice) {
                unawaited(
                  tts.applyVoice(
                    voice == null || voice.name.isEmpty ? null : voice,
                  ),
                );
              },
            ),
            SizedBox(height: tokens.spacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.readerTtsKeepOnExit),
              value: !state.stopOnExit,
              onChanged: (bool keep) => unawaited(tts.applyStopOnExit(!keep)),
            ),
          ],
        ),
      ),
    );
  }
}
