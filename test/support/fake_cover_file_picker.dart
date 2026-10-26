import 'package:flutter_reader/core/platform/cover_file_picker.dart';

/// [CoverFilePicker] double answering a scripted file (`docs/dev/testing.md` §4).
final class FakeCoverFilePicker implements CoverFilePicker {
  /// What the next [`pick`] answers; `null` means the user cancelled.
  PickedCoverFile? next;

  /// How many times a pick was requested.
  int calls = 0;

  @override
  Future<PickedCoverFile?> pick() async {
    calls++;

    return next;
  }
}
