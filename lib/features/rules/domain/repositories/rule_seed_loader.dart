import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';

/// The rules that ship with the app (`docs/dev/roadmap.md` M20, ADR-0070 增补 §5).
///
/// The seeds are assets copied from upstream's `defaultData/` rather than code, so updating them is
/// a data change and their JSON stays diffable. Only 目录规则 and 字典规则 ship: upstream has no
/// default 净化 / 高亮 rules, and inventing some would rewrite the user's own chapter text with a
/// rule nobody can explain.
abstract interface class RuleSeedLoader {
  /// Every seed rule, in the order it should be stored.
  ///
  /// An asset that is not the expected JSON is a [ParseFailure] rather than an exception (C-ERR-1):
  /// seeding is a convenience, so the caller degrades to an empty rule list and says so in the log.
  /// A **missing** asset is a packaging defect and throws instead (`Error`, ADR-0022).
  Future<ParseResult<List<RuleDraft>>> load();
}
