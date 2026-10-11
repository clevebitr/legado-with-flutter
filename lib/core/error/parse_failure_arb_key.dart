import 'package:flutter_reader/core/error/parse_result.dart';

/// Resolves the ARB message key of [kind], or `null` when the UI stays silent.
///
/// The key follows `failure<PascalCaseName>`, for example
/// `failureNetworkTimeout` (ADR-0002, `docs/dev/naming.md` §8).
///
/// This is the single implementation of the key-naming rule. The UI keeps only
/// the key to message `switch`, because `AppLocalizations` exposes compile-time
/// getters and cannot look a key up at runtime; the message itself therefore
/// still lives in the UI layer, as C-ERR-7 requires.
///
/// Returns `null` for [ParseFailureKind.cancelled], which has no message.
String? resolveFailureArbKey(ParseFailureKind kind) => switch (kind) {
  // 故意不写 default：新增 kind 必须在此分类，否则编译失败（ADR-0002）。
  ParseFailureKind.networkTimeout => 'failureNetworkTimeout',
  ParseFailureKind.networkFailed => 'failureNetworkFailed',
  ParseFailureKind.networkForbidden => 'failureNetworkForbidden',
  ParseFailureKind.notFound => 'failureNotFound',
  ParseFailureKind.encodingFailed => 'failureEncodingFailed',
  ParseFailureKind.parseFailed => 'failureParseFailed',
  ParseFailureKind.unsupportedRule => 'failureUnsupportedRule',
  ParseFailureKind.invalidBookSource => 'failureInvalidBookSource',
  ParseFailureKind.cancelled => null,
};
