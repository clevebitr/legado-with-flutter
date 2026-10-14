import 'package:flutter_reader/core/error/parse_result.dart';

/// Asks the platform for one book source file and hands back its text (`PLAN.md` 5.8, ADR-0040
/// §决策 9's revision note).
///
/// **Why an interface:** a file dialog is a platform capability, so by C-PLT-1 it lives in
/// `core/platform/` behind an abstraction — the pages and the use case never see the plugin, and a
/// test injects an opener instead of faking a platform channel (`docs/dev/testing.md` §4).
///
/// **The contract follows `docs/dev/platform.md` §2:** a platform without a picker and a user who
/// cancels are the same answer — `ParseSuccess(null)` — and no implementation throws. The caller
/// shows nothing in that case, because “the user closed the dialog” is not a failure.
///
/// A file larger than `maxBytes` is a [ParseFailure] of kind [ParseFailureKind.invalidBookSource]
/// with `rulePath: 'import.sizeLimit'` — the same verdict the paste path gives for the same number
/// (ADR-0040 §决策 5). The check happens on the file's **size**, before its bytes are read, so an
/// oversized file is refused instead of loaded (C-SEC-5, C-PERF-5).
abstract interface class BookSourceFilePicker {
  /// Lets the user pick one JSON file and returns its text, or `null` when nothing was picked.
  Future<ParseResult<String?>> pick({required int maxBytes});
}

/// The fallback for a platform with no file dialog: it answers “nothing picked”.
///
/// Degrading instead of throwing is the platform contract (`docs/dev/platform.md` §2): the picker
/// button simply does nothing on such a target, and every target this app ships (Android, iOS,
/// Windows) has a real implementation injected at the composition root.
final class UnsupportedBookSourceFilePicker implements BookSourceFilePicker {
  /// Creates the fallback.
  const UnsupportedBookSourceFilePicker();

  @override
  Future<ParseResult<String?>> pick({required int maxBytes}) async =>
      const ParseSuccess<String?>(null);
}

/// Opens the platform's file dialog and answers what the user picked (`null` when they cancelled).
///
/// It is a typedef rather than a method so the picker can default to the real dialog and a test can
/// pass a fake one; the plugin call therefore stays in a single, exemptable file.
typedef BookSourceFileOpener = Future<PickedBookSourceFile?> Function();

/// What a file dialog produced: the bytes and a display name.
///
/// It exists so the read/cap logic can be tested without a platform channel: the opener returns
/// this, and everything downstream is ordinary Dart.
final class PickedBookSourceFile {
  /// Creates the picked file.
  const PickedBookSourceFile({required this.name, required this.bytes});

  /// The file's name, for logs only (never the path: C-PLT-3 discourages hard-coded paths and the
  /// name is all a message needs).
  final String name;

  /// The file's contents.
  final List<int> bytes;
}
