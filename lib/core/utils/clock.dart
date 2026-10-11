/// Source of the current time.
///
/// Time-dependent logic — cache TTL (C-NET-6) and, later, cookie expiry — must
/// read the time from here instead of calling `DateTime.now()` directly, so
/// tests can pin it (`docs/dev/testing.md` §4).
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
