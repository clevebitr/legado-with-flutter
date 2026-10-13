/// The rate gate one book source declares (`docs/dev/book-source.md` §8).
///
/// The pair is upstream's `accessLimit` / `interval`: at most [times] requests per
/// [intervalMilliseconds] milliseconds (`ConcurrentRateLimiter.kt:17-46`, unit at `:86`).
/// It is a **rate** bound, so it is dimensionally different from the same source's
/// concurrency budget (`book-source.md` §8): both apply to a request, and ADR-0036 §决策 3
/// fixes that they are never collapsed into one number.
final class ConcurrentRate {
  /// Creates a rate gate.
  const ConcurrentRate({
    required this.times,
    required this.intervalMilliseconds,
  });

  /// How many requests the window allows.
  final int times;

  /// The window length in milliseconds.
  final int intervalMilliseconds;

  @override
  bool operator ==(Object other) =>
      other is ConcurrentRate &&
      other.times == times &&
      other.intervalMilliseconds == intervalMilliseconds;

  @override
  int get hashCode => Object.hash(times, intervalMilliseconds);

  @override
  String toString() => 'ConcurrentRate($times/$intervalMilliseconds)';
}

/// What one `concurrentRate` declaration asks for (`docs/dev/book-source.md` §8).
///
/// The three outcomes are kept apart on purpose, because ADR-0036 §决策 2 makes an illegal
/// declaration **observable**: “no gate” and “this text is broken” must not look alike, or
/// the second one silently keeps whatever the site had before.
final class ConcurrentRateDeclaration {
  const ConcurrentRateDeclaration._({this.rate, this.invalidReason});

  /// A legal declaration, so the source is rate limited.
  const ConcurrentRateDeclaration.limited(ConcurrentRate rate)
    : this._(rate: rate);

  /// An illegal declaration: ignored, with [invalidReason] for the warning.
  const ConcurrentRateDeclaration.invalid(String reason)
    : this._(invalidReason: reason);

  /// No gate: the field is absent, blank, or asks for `"0"`.
  const ConcurrentRateDeclaration.none() : this._();

  /// The gate the declaration describes, or `null` when there is none.
  final ConcurrentRate? rate;

  /// Why an illegal declaration was rejected, or `null` when it was not illegal.
  final String? invalidReason;

  /// Whether the source asks to be rate limited.
  bool get isLimited => rate != null;

  /// Whether the declaration could not be read.
  bool get isInvalid => invalidReason != null;
}

/// Reads a `concurrentRate` declaration (`docs/dev/book-source.md` §8).
///
/// | declaration | gate |
/// |---|---|
/// | absent, blank, `"0"` | none |
/// | `n/m` | `n` requests per `m` milliseconds |
/// | `x` | 1 request per `x` milliseconds |
/// | anything else (`n <= 0`, `m <= 0`, `x <= 0`, non-integers) | invalid |
///
/// Both sides of `n/m` and the bare `x` are parsed as integers with their surrounding
/// whitespace ignored, which is the one place this reader is more forgiving than upstream:
/// `ConcurrentRateLimiter.kt:17-46` calls `toInt()` on the raw substring, so `"10 / 5"` throws
/// there and falls back to a stale record. Here a declaration is either readable or reported.
ConcurrentRateDeclaration parseConcurrentRate(String? declaration) {
  if (declaration == null || declaration.trim().isEmpty) {
    return const ConcurrentRateDeclaration.none();
  }

  final String text = declaration.trim();
  // 上游把 `"0"` 当作「不限速」的另一种拼法（`ConcurrentRateLimiter.kt:52`）。
  if (text == '0') {
    return const ConcurrentRateDeclaration.none();
  }

  final int slash = text.indexOf('/');
  if (slash < 0) {
    final int? interval = int.tryParse(text);
    if (interval == null) {
      return const ConcurrentRateDeclaration.invalid('not an integer');
    }
    if (interval <= 0) {
      return const ConcurrentRateDeclaration.invalid(
        'interval must be positive',
      );
    }

    return ConcurrentRateDeclaration.limited(
      ConcurrentRate(times: 1, intervalMilliseconds: interval),
    );
  }

  final int? times = int.tryParse(text.substring(0, slash));
  final int? interval = int.tryParse(text.substring(slash + 1));
  if (times == null || interval == null) {
    return const ConcurrentRateDeclaration.invalid('not two integers');
  }
  if (times <= 0) {
    return const ConcurrentRateDeclaration.invalid('times must be positive');
  }
  if (interval <= 0) {
    return const ConcurrentRateDeclaration.invalid('interval must be positive');
  }

  return ConcurrentRateDeclaration.limited(
    ConcurrentRate(times: times, intervalMilliseconds: interval),
  );
}
