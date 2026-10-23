/// Where one shelf entry stands for the user (`docs/dev/roadmap.md` 5.4).
///
/// The two values are deliberately coarse: upstream's shelf also has "养肥" (waiting for more
/// chapters), which needs a 「更新到第 N 章」 judgement that only the download phase can make.
/// Adding it before that exists would be a value the UI can set and nothing can act on
/// (C-BAN-2).
enum ShelfStatus {
  /// The user is still following the book.
  tracking(0),

  /// The user has finished it.
  read(1);

  const ShelfStatus(this.storageValue);

  /// The value stored in the `books.status` column.
  final int storageValue;

  /// Reads a stored column value back.
  ///
  /// An unknown number is treated as [tracking] rather than failing: a row written by a newer
  /// build must still show up on the shelf, and "still following" is the harmless direction.
  static ShelfStatus fromStorage(int value) =>
      value == read.storageValue ? read : tracking;
}
