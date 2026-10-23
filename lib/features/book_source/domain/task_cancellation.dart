/// A cooperative stop signal shared by a long run and whoever wants to stop it.
///
/// Dart has no cancellation primitive, so a batch that spans many requests stops **between**
/// stages: the runner hands one instance to every `execute` call, and the domain checks
/// [isCancelled] before it starts the next stage. Nothing is interrupted mid-request, which is why
/// a stop is reported as cancelled rather than as a failure (ADR-0043 §后果).
///
/// It lives in `domain/` rather than in `presentation/` because both the batch check and the debug
/// console talk to domain use cases, and neither may own a signal the other cannot understand.
final class TaskCancellation {
  bool _isCancelled = false;

  /// Whether [cancel] has been called; safe to read from anywhere.
  bool get isCancelled => _isCancelled;

  /// Asks the run to stop. Calling it twice is a no-op.
  void cancel() => _isCancelled = true;
}
