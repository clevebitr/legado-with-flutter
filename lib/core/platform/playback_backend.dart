// coverage:ignore-file
import 'dart:io';

/// Which native backend plays audio on this platform (ADR-0061).
///
/// The decision lives in `core/platform/` so neither the reader nor its adapter asks the
/// platform itself (C-PLT-1). Windows uses `media_kit` (mpv): `just_audio_windows` stops at
/// position 0 for some real streams and can crash on a failed load; Android / iOS keep
/// `just_audio`.
bool get usesMediaKitPlayback => Platform.isWindows;
