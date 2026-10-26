import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/features/rules/domain/entities/replace_rule_import.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_payload.dart';
import 'package:flutter_reader/features/rules/domain/replace_rule_exchange.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_repository.dart';

/// The largest document one replace-rule import accepts, in UTF-8 bytes.
///
/// The same cap as the book-source import: a rule file is a few kilobytes, so 32 MB is already
/// 「something is wrong」 rather than a real limit (C-SEC-5, C-PERF-5).
const int replaceRuleImportSizeLimitBytes = 32 * 1024 * 1024;

/// Where the JSON of one replace-rule import comes from
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
sealed class ReplaceRuleImportInput {
  /// Const constructor for the sealed hierarchy.
  const ReplaceRuleImportInput();
}

/// A document the user pasted.
final class ReplaceRuleImportText extends ReplaceRuleImportInput {
  /// Creates the text input.
  const ReplaceRuleImportText(this.text);

  /// The pasted document.
  final String text;
}

/// A URL the document is downloaded from.
final class ReplaceRuleImportUrl extends ReplaceRuleImportInput {
  /// Creates the URL input.
  const ReplaceRuleImportUrl(this.url);

  /// The download address.
  final String url;
}

/// Imports 替换净化 rules from pasted text, a URL or a file's text
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 1/§决策 2).
///
/// Owns the acceptance decisions (byte cap, document-level rejections, per-entry problems) and the
/// dedupe rule: a rule whose `name` + `pattern` is already stored is **rewritten**, everything else
/// is appended. Nothing is ever deleted — a file that lacks a rule leaves that rule alone.
final class ImportReplaceRules {
  /// Creates the use case.
  ///
  /// [_sizeLimit] defaults to the production cap and is overridden only in tests.
  const ImportReplaceRules({
    required this._repository,
    required this._http,
    required this._logger,
    this._sizeLimit = replaceRuleImportSizeLimitBytes,
  });

  final RuleRepository _repository;
  final HttpClient _http;
  final AppLogger _logger;
  final int _sizeLimit;

  /// Reads [input] and answers what could be stored, without writing anything.
  Future<ParseResult<ReplaceRuleImportPreview>> preview(
    ReplaceRuleImportInput input,
  ) async {
    final ParseResult<String> text = switch (input) {
      ReplaceRuleImportText(:final String text) => _withinCap(text),
      ReplaceRuleImportUrl(:final String url) => await _download(url),
    };

    return switch (text) {
      ParseFailure<String>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<ReplaceRuleImportPreview>(kind: kind, rulePath: failedAt),
      ParseSuccess<String>(:final String data) => await _previewOf(data),
    };
  }

  /// Stores the usable entries of [preview] and reports what landed.
  ///
  /// The stored rules are read again instead of trusting the preview's `isUpdate` flags: the user may
  /// have deleted a rule between the preview and this call, and「更新一条不存在的行」must become an
  /// insert rather than a silent no-op.
  Future<ParseResult<ReplaceRuleImportReport>> commit(
    ReplaceRuleImportPreview preview,
    Set<int> selected,
  ) async {
    final List<Rule> stored = await _repository.ofKind(RuleKind.replace);
    final Map<String, Rule> byKey = <String, Rule>{
      for (final Rule rule in stored)
        if (rule.payload case final ReplacePayload payload)
          replaceRuleKey(rule.name, payload.pattern): rule,
    };

    var created = 0;
    var updated = 0;

    for (final ReplaceRuleImportEntry entry in preview.entries) {
      final RulePayload? payload = entry.payload;
      if (payload == null || !selected.contains(entry.index)) {
        continue;
      }
      final Rule? existing = switch (payload) {
        ReplacePayload(:final String pattern) =>
          byKey[replaceRuleKey(entry.name, pattern)],
        _ => null,
      };

      if (existing == null) {
        await _repository.create(
          RuleDraft(
            kind: RuleKind.replace,
            name: entry.name,
            payload: payload,
            isEnabled: entry.isEnabled,
            sortOrder: entry.sortOrder,
          ),
        );
        created++;

        continue;
      }

      await _repository.save(
        existing.copyWith(
          name: entry.name,
          payload: payload,
          isEnabled: entry.isEnabled,
          sortOrder: entry.sortOrder ?? existing.sortOrder,
        ),
      );
      updated++;
    }

    return ParseSuccess<ReplaceRuleImportReport>(
      ReplaceRuleImportReport(
        created: created,
        updated: updated,
        skipped: preview.rejectedCount,
      ),
    );
  }

  // 解析之前先卡字节上限。
  ParseResult<String> _withinCap(String text) =>
      text.length > _sizeLimit || utf8.encode(text).length > _sizeLimit
      ? failureAt<String>(
          kind: ParseFailureKind.invalidBookSource,
          rulePath: 'rules.import.sizeLimit',
        )
      : ParseSuccess<String>(text);

  Future<ParseResult<String>> _download(String url) async {
    final ParseResult<HttpResponse> response = await _http.get(
      url,
      rulePath: 'rules.import.url',
      maxBytes: _sizeLimit,
    );

    return switch (response) {
      // 上限触发时请求层把异常放进 `cause`，这里改写成导入契约的 rulePath。
      ParseFailure<HttpResponse>(cause: final BodyTooLargeException _) =>
        failureAt<String>(
          kind: ParseFailureKind.invalidBookSource,
          rulePath: 'rules.import.sizeLimit',
        ),
      ParseFailure<HttpResponse>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<HttpResponse>(:final HttpResponse data) =>
        ParseSuccess<String>(data.body),
    };
  }

  Future<ParseResult<ReplaceRuleImportPreview>> _previewOf(String text) async {
    final ParseResult<List<ReplaceRuleImportEntry>> parsed =
        parseReplaceRuleDocument(text, existingKeys: await _storedKeys());

    return switch (parsed) {
      ParseFailure<List<ReplaceRuleImportEntry>>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<ReplaceRuleImportPreview>(kind: kind, rulePath: failedAt),
      ParseSuccess<List<ReplaceRuleImportEntry>>(
        :final List<ReplaceRuleImportEntry> data,
      ) =>
        ParseSuccess<ReplaceRuleImportPreview>(
          ReplaceRuleImportPreview(entries: _logged(data)),
        ),
    };
  }

  /// Records the entries that cannot be stored; the preview still shows them.
  List<ReplaceRuleImportEntry> _logged(List<ReplaceRuleImportEntry> entries) {
    for (final ReplaceRuleImportEntry entry in entries) {
      final ReplaceRuleImportProblem? problem = entry.problem;
      if (problem != null) {
        // 名字可能是空的：只记下标与原因，不把文件内容写进日志。
        _logger.warning(
          'Replace rule entry skipped: index=${entry.index} reason=${problem.name}',
        );
      }
    }

    return entries;
  }

  /// The keys of the rules already stored, so the preview can say 「更新」instead of 「新增」.
  Future<Set<String>> _storedKeys() async {
    final List<Rule> stored = await _repository.ofKind(RuleKind.replace);

    return <String>{
      for (final Rule rule in stored)
        if (rule.payload case final ReplacePayload payload)
          replaceRuleKey(rule.name, payload.pattern),
    };
  }
}
