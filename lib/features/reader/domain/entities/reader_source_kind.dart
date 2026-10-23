/// What kind of content a book source serves, as far as the reader cares
/// (`docs/dev/roadmap.md` §3.10 M16/M17, ADR-0053 §决策 1, ADR-0054 §决策 1).
///
/// The reader has its own enum instead of importing `book_source`'s `BookSourceType`
/// (C-ARCH-2): the composition root maps one to the other when it binds
/// `ReaderSourceKindProvider`. Three values, one per body the reader can build; adding a body is
/// one entry here plus one branch in `ReaderPage` (that is how [audio] joined in M17).
enum ReaderSourceKind {
  /// The body is text; the existing reader page shows it.
  text,

  /// The body is a list of images; the manga reader shows it.
  image,

  /// The body is a list of audio tracks; the audio player shows it (M17, ADR-0054 §决策 1).
  audio,
}
