// coverage:ignore-file
import 'dart:io';

/// Whether audio on this platform is played through `media_kit` (Windows) rather than `just_audio`.
bool get usesMediaKitPlayback => Platform.isWindows;
