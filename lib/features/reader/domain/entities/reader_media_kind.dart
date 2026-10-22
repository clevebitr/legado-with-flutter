/// What kind of content the current book source serves, from the reader's point of view
/// (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 1).
///
/// `book_source` has `BookSourceType` with five values, but the reader only needs to know which
/// body to build. Keeping the reader's own enum means the reader never imports that feature
/// (C-ARCH-2), and adding the image mode later (ADR-0053) is one value here plus one branch in
/// `ReaderPage`.
enum ReaderMediaKind {
  /// Text chapters, rendered by the reader's text view.
  text,

  /// Audio chapters, rendered by the audio player view.
  audio,
}
