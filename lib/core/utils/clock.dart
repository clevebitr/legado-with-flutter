/// Source of the current time, so tests can pin it.
abstract interface class Clock {
  /// Returns the current instant.
  DateTime now();
}

/// [Clock] backed by `DateTime.now()`.
final class SystemClock implements Clock {
  /// Creates the system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
