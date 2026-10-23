/// What kind of content a book source serves, as far as the reader cares
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053 §决策 1).
///
/// The reader has its own enum instead of importing `book_source`'s `BookSourceType`
/// (C-ARCH-2): the composition root maps one to the other when it binds
/// `ReaderSourceKindProvider`. Only the two values this milestone reads are listed — an audio
/// source stays [text] until M17 gives it a player, which is the honest answer today.
enum ReaderSourceKind {
  /// The body is text; the existing reader page shows it.
  text,

  /// The body is a list of images; the manga reader shows it.
  image,
}
