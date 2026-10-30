import 'package:flutter/foundation.dart';

/// Which way a page-turn command goes (ADR-0093 §决策 2, ADR-0096).
enum ReaderPageTurnDirection {
  /// Forward, the same way a swipe to the left goes.
  next,

  /// Backward, the same way a swipe to the right goes.
  previous,
}

/// The reader's "turn one page" command (ADR-0093 §决策 2, ADR-0096).
///
/// The page owns one instance and hands it to whichever flow is mounted; the flow subscribes and
/// moves **its own** controller. It cannot be handed a controller instead: both flows **replace**
/// their controller inside the build that has to apply a correction (ADR-0087 §决策 2), so anything
/// captured from outside would be a stale instance.
///
/// Direction is a property rather than two notifications, because a listener that had to guess would
/// need a second channel to tell forward from backward.
final class ReaderPageTurn extends ChangeNotifier {
  ReaderPageTurnDirection _direction = ReaderPageTurnDirection.next;

  /// The direction of the last command.
  ReaderPageTurnDirection get direction => _direction;

  /// Asks the mounted flow to advance one page (one page in paged mode, one screen while
  /// scrolling). A flow that is not mounted simply does nothing.
  void next() {
    _direction = ReaderPageTurnDirection.next;
    notifyListeners();
  }

  /// Asks the mounted flow to go back one page (one page / one screen), the mirror of [next].
  void previous() {
    _direction = ReaderPageTurnDirection.previous;
    notifyListeners();
  }
}
