import 'package:freezed_annotation/freezed_annotation.dart';

part 'parse_result.freezed.dart';

/// Kinds of recoverable failures produced by the parsing, network and
/// storage layers.
///
/// Each value except [ParseFailureKind.cancelled] maps to the ARB message key
/// `failure<PascalCaseName>`, for example `failureNetworkTimeout`. The naming
/// rule is implemented once, in `resolveFailureArbKey`; the UI keeps only the
/// key to message `switch`, because `AppLocalizations` cannot look a key up at
/// runtime. The message itself therefore still lives in the UI layer, as C-ERR-7
/// requires.
enum ParseFailureKind {
  /// The connection or read exceeded the configured timeout.
  networkTimeout,

  /// DNS resolution or the connection failed, including 5xx responses.
  networkFailed,

  /// The remote site refused the request with HTTP 403.
  networkForbidden,

  /// The remote site answered with HTTP 404.
  notFound,

  /// The charset could not be detected or the response could not be decoded.
  encodingFailed,

  /// A rule matched nothing, or a JS rule threw or timed out.
  parseFailed,

  /// The book source used a rule syntax that is not supported yet.
  unsupportedRule,

  /// The imported book source JSON misses required fields or is malformed.
  invalidBookSource,

  /// The user cancelled the operation; the UI stays silent about it and no
  /// message key exists for it.
  cancelled;

  /// Whether retrying the same operation may succeed (`book-source.md` §7).
  bool get isRetryable => switch (this) {
    // 9 个值逐个列出、不写通配分支：新增 kind 必须明确它是否可重试（编译器强制）。
    ParseFailureKind.networkTimeout => true,
    ParseFailureKind.networkFailed => true,
    ParseFailureKind.networkForbidden => false,
    ParseFailureKind.notFound => false,
    ParseFailureKind.encodingFailed => false,
    ParseFailureKind.parseFailed => false,
    ParseFailureKind.unsupportedRule => false,
    ParseFailureKind.invalidBookSource => false,
    ParseFailureKind.cancelled => false,
  };
}

/// Result of an operation that can fail without throwing an exception.
///
/// Operations of the network, parsing, storage and IO layers return a
/// [ParseResult] instead of throwing (C-ERR-1); programming errors such as
/// [ArgumentError] are still thrown.
///
/// Consumers must `switch` exhaustively over [ParseSuccess] and [ParseFailure];
/// the sealed hierarchy makes the missing branch a compile-time error.
///
/// Equality is structural and includes [ParseFailure.cause] and
/// [ParseFailure.stackTrace], so two failures describing the same problem are
/// equal only when their causes compare equal; causes that do not implement
/// `==`, such as most exception instances, make otherwise identical failures
/// unequal. Never use a [ParseResult] as a deduplication, cache or map key;
/// cache keys are built from the book source ID and the request parameters
/// instead (C-NET-6).
// 结果类型构造后不再修改，故关闭 copyWith 生成（ADR-0002 未定义该需求）。
@Freezed(copyWith: false)
sealed class ParseResult<T> with _$ParseResult<T> {
  /// Creates a successful result carrying [data].
  const factory ParseResult.success(T data) = ParseSuccess<T>;

  /// Creates a failure result of [kind] located at [rulePath].
  ///
  /// [rulePath] names the failing rule as `<field>` or `<field>.<subField>`,
  /// for example `searchRule.bookList`, so logs and the UI can point at it
  /// (C-SRC-8).
  ///
  /// [cause] and [stackTrace] exist for diagnostics only: they must reach the
  /// logger, never the user interface (C-ERR-8, C-SEC-4).
  const factory ParseResult.failure({
    required ParseFailureKind kind,
    required String rulePath,
    Object? cause,
    StackTrace? stackTrace,
  }) = ParseFailure<T>;
}

/// Creates a [ParseFailure], the single construction point for failures (C-SRC-8).
///
/// [rulePath] is what makes a failure locatable, so an empty one is a programming
/// error rather than a runtime condition: it trips an assertion in debug builds
/// instead of shipping a failure nobody can act on. `PLAN.md` 2.7 introduced this
/// entry point so that every failure path of the rule engine and of the book source
/// use cases goes through it.
ParseFailure<T> failureAt<T>({
  required ParseFailureKind kind,
  required String rulePath,
  Object? cause,
  StackTrace? stackTrace,
}) {
  assert(
    rulePath.isNotEmpty,
    'A ParseFailure needs a non-empty rulePath (C-SRC-8).',
  );

  return ParseFailure<T>(
    kind: kind,
    rulePath: rulePath,
    cause: cause,
    stackTrace: stackTrace,
  );
}

/// Convenience accessors for [ParseResult].
extension ParseResultExtension<T> on ParseResult<T> {
  /// Returns the wrapped data, or `null` when the result is a failure.
  ///
  /// Prefer an exhaustive `switch` when the failure branch needs handling.
  T? get dataOrNull => switch (this) {
    ParseSuccess<T>(:final T data) => data,
    ParseFailure<T>() => null,
  };

  /// Invokes [onSuccess] with the wrapped data when this result succeeded.
  ///
  /// A failure leaves the callback untouched and stays silent; use a `switch`
  /// when the caller must react to the failure as well.
  void whenSuccess(void Function(T data) onSuccess) {
    if (this case ParseSuccess<T>(:final T data)) {
      onSuccess(data);
    }
  }
}
