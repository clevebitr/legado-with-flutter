/// A rate gate one book source declares.
///
/// At most [times] requests per [intervalMilliseconds] milliseconds.
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

/// What one `concurrentRate` declaration asks for.
///
/// "No gate" and "broken declaration" are kept apart so an illegal text stays observable.
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

/// Reads a `concurrentRate` declaration.
///
/// `n/m` means `n` requests per `m` ms, a bare `x` one per `x` ms; absent, blank or `"0"` means no gate, anything else is invalid.
ConcurrentRateDeclaration parseConcurrentRate(String? declaration) {
  if (declaration == null || declaration.trim().isEmpty) {
    return const ConcurrentRateDeclaration.none();
  }

  final String text = declaration.trim();
  // "0" 沿用上游语义，表示不限速。
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
