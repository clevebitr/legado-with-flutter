import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/storage/database.dart' show RuleRow;
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/core/storage/rule_dao.dart' show RuleDao;
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/rules/data/rule_payload_codec.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/repositories/chapter_body_invalidator.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_repository.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_seed_loader.dart';

/// `shared_preferences` key of the「内置规则已经播过」flag.
///
/// The flag is what makes seeding a **once per install** event: the table being empty is not enough,
/// because a user who deleted every built-in rule must not get them back on the next launch
/// (ADR-0070 §决策 4). Keys are private to this file, like the other stores'.
const String _seededKey = 'rules.builtInSeeded';

/// [RuleRepository] on top of the Drift `rules` table (`docs/dev/roadmap.md` M20, ADR-0070).
///
/// Three behaviours live here rather than in the pages:
///
/// * **payload ⇄ JSON** goes through [decodeRulePayload] / [encodeRulePayload], so a payload this
///   build cannot read comes back as [MalformedPayload] and stays visible instead of vanishing;
/// * **seeding** happens on the first read, once per install, and never overwrites a kind the user
///   already has rules of;
/// * **a purge-rule write retires the cached chapter bodies**, because a cached body is finished
///   text with the old rules already applied (ADR-0070 增补 §7).
final class RuleRepositoryImpl implements RuleRepository {
  /// Creates the repository.
  RuleRepositoryImpl({
    required this._dao,
    required this._seeds,
    required this._preferences,
    required this._invalidator,
    required this._clock,
    required this._logger,
  });

  final RuleDao _dao;
  final RuleSeedLoader _seeds;
  final PreferenceStore _preferences;
  final ChapterBodyInvalidator _invalidator;
  final Clock _clock;
  final AppLogger _logger;

  /// The in-flight seeding, so concurrent first reads seed once and not twice.
  Future<void>? _seeding;

  @override
  Future<List<Rule>> ofKind(RuleKind kind) async {
    await _seedIfNeeded();

    final List<RuleRow> rows = await _dao.ofKind(kind.value);

    return <Rule>[
      for (final RuleRow row in rows) _toRule(kind: kind, row: row),
    ];
  }

  @override
  Future<void> create(RuleDraft draft) async {
    await _dao.insert(
      kind: draft.kind.value,
      name: draft.name,
      payload: encodeRulePayload(draft.payload),
      isEnabled: draft.isEnabled,
      isBuiltIn: draft.isBuiltIn,
      now: _clock.now(),
    );

    await _retireChapterBodies(draft.kind);
  }

  @override
  Future<void> save(Rule rule) async {
    // kind 不是可编辑字段（一行从属于一个功能），payload 与 kind 不一致是调用方的编程错误，
    // 静默写入会让「净化列表里躺着一条字典规则」，所以直接抛（C-ERR-1 的编程错误口径）。
    if (rule.payload.kind != rule.kind) {
      throw ArgumentError.value(
        rule.payload,
        'rule',
        'A ${rule.payload.kind} payload cannot be saved as a ${rule.kind} rule',
      );
    }

    await _dao.updateRow(
      rule.id,
      name: rule.name,
      payload: encodeRulePayload(rule.payload),
      isEnabled: rule.isEnabled,
    );

    await _retireChapterBodies(rule.kind);
  }

  @override
  Future<void> setEnabled({required int id, required bool isEnabled}) async {
    final RuleKind? kind = await _kindOf(id);

    await _dao.updateRow(id, isEnabled: isEnabled);
    if (kind != null) {
      await _retireChapterBodies(kind);
    }
  }

  @override
  Future<void> delete(int id) async {
    // 先读 kind 再删：删掉之后就查不出这一行原来是不是净化规则了。
    final RuleKind? kind = await _kindOf(id);

    await _dao.deleteById(id);
    if (kind != null) {
      await _retireChapterBodies(kind);
    }
  }

  @override
  Future<void> reorder({
    required RuleKind kind,
    required List<int> orderedIds,
  }) async {
    for (int index = 0; index < orderedIds.length; index++) {
      await _dao.updateSortOrder(orderedIds[index], index);
    }

    // 顺序变了，净化的结果就可能变：同样要作废已缓存的成品正文（ADR-0070 增补 §7）。
    await _retireChapterBodies(kind);
  }

  /// One stored row as a [Rule]; an unreadable payload becomes [MalformedPayload] plus a warning.
  Rule _toRule({required RuleKind kind, required RuleRow row}) {
    final RulePayload payload = decodeRulePayload(
      kind: kind,
      json: row.payload,
    );
    if (payload is MalformedPayload) {
      // 不记 payload 正文（C-SEC-4 的同一立场：日志不放数据内容），只记定位信息。
      _logger.warning(
        'Rule payload is unreadable: id=${row.id} kind=${row.kind}',
      );
    }

    return Rule(
      id: row.id,
      kind: kind,
      name: row.name,
      payload: payload,
      isEnabled: row.isEnabled,
      isBuiltIn: row.isBuiltIn,
      sortOrder: row.sortOrder,
    );
  }

  /// The kind of [id], or `null` when the row is gone or names a kind this build does not know.
  Future<RuleKind?> _kindOf(int id) async {
    final RuleRow? row = await _dao.byId(id);

    return row == null ? null : RuleKind.fromValue(row.kind);
  }

  /// Drops the cached chapter bodies after a purge-rule write (ADR-0070 增补 §7).
  Future<void> _retireChapterBodies(RuleKind kind) async {
    if (kind != RuleKind.replace) {
      return;
    }

    await _invalidator.invalidateChapterBodies();
  }

  Future<void> _seedIfNeeded() => _seeding ??= _seed();

  /// Writes the bundled rules once per install.
  ///
  /// The flag is written **after** the inserts: a crash halfway through leaves the flag unset, so
  /// the next launch seeds the missing kinds instead of ending up with a half-seeded list.
  Future<void> _seed() async {
    if (_preferences.readBool(_seededKey) ?? false) {
      return;
    }

    final ParseResult<List<RuleDraft>> loaded = await _seeds.load();
    switch (loaded) {
      case ParseFailure<List<RuleDraft>>(:final ParseFailureKind kind):
        // 不设标记：种子读不出来只是这一次没有内置规则，下次启动还能再试。
        _logger.warning('Built-in rules could not be seeded: $kind');

        return;
      case ParseSuccess<List<RuleDraft>>(:final List<RuleDraft> data):
        for (final RuleDraft draft in data) {
          // 这一类已经有规则（用户建过、或上一次播过）就整类跳过：播种只补空，不合并。
          if (await _dao.hasAny(draft.kind.value)) {
            continue;
          }
          await _dao.insert(
            kind: draft.kind.value,
            name: draft.name,
            payload: encodeRulePayload(draft.payload),
            isEnabled: draft.isEnabled,
            isBuiltIn: draft.isBuiltIn,
            now: _clock.now(),
          );
        }
    }

    await _preferences.writeBool(_seededKey, true);
  }
}
