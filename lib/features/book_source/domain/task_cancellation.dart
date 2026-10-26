/// A cooperative stop signal shared by a long run and whoever wants to stop it.
///
/// It is checked between stages, so a stop is reported as cancelled, not as a failure.
final class TaskCancellation {
  bool _isCancelled = false;

  /// Whether [cancel] has been called; safe to read from anywhere.
  bool get isCancelled => _isCancelled;

  /// Asks the run to stop. Calling it twice is a no-op.
  void cancel() => _isCancelled = true;
}
