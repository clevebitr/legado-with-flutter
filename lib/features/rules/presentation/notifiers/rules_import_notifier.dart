import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/rules/di.dart';
import 'package:flutter_reader/features/rules/domain/entities/replace_rule_import.dart';
import 'package:flutter_reader/features/rules/domain/entities/rule_kind.dart';
import 'package:flutter_reader/features/rules/domain/usecases/import_replace_rules.dart';
import 'package:flutter_reader/features/rules/presentation/notifiers/rules_list_notifier.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rules_import_notifier.freezed.dart';
part 'rules_import_notifier.g.dart';

/// What the replace-rule import form currently shows
/// (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
@freezed
sealed class RulesImportState with _$RulesImportState {
  /// Nothing was submitted yet in this screen.
  const factory RulesImportState.idle() = RulesImportIdle;

  /// The document is being read and checked.
  const factory RulesImportState.importing() = RulesImportImporting;

  /// The document was read; nothing is stored until the user commits.
  const factory RulesImportState.preview(ReplaceRuleImportPreview preview) =
      RulesImportPreviewing;

  /// The ticked entries are being stored.
  const factory RulesImportState.committing() = RulesImportCommitting;

  /// The import finished; [report] carries created / updated / skipped.
  const factory RulesImportState.done(ReplaceRuleImportReport report) =
      RulesImportDone;

  /// The whole document was refused; [kind] is the message the UI shows.
  const factory RulesImportState.failed(ParseFailureKind kind) =
      RulesImportFailed;
}

/// Runs one replace-rule import (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
///
/// Same shape as the book-source import: preview first, commit what the user ticked, never touch a
/// rule the file does not mention.
@riverpod
class RulesImportNotifier extends _$RulesImportNotifier {
  @override
  RulesImportState build() => const RulesImportState.idle();

  /// Asks the platform for a JSON file and previews it; a cancelled dialog changes nothing.
  Future<void> pickFile() async {
    final ParseResult<String?> picked = await ref
        .read(jsonFilePickerProvider)
        .pick(maxBytes: replaceRuleImportSizeLimitBytes);

    switch (picked) {
      case ParseFailure<String?>(:final ParseFailureKind kind):
        state = RulesImportState.failed(kind);
      case ParseSuccess<String?>(:final String? data):
        if (data == null) {
          return;
        }
        await submit(ReplaceRuleImportText(data));
    }
  }

  /// Reads [input] and publishes the preview; nothing is stored yet.
  Future<void> submit(ReplaceRuleImportInput input) async {
    state = const RulesImportState.importing();

    try {
      final ParseResult<ReplaceRuleImportPreview> result =
          await (await ref.read(importReplaceRulesProvider.future))
              .preview(input);

      state = switch (result) {
        ParseSuccess<ReplaceRuleImportPreview>(
          :final ReplaceRuleImportPreview data,
        ) =>
          RulesImportState.preview(data),
        ParseFailure<ReplaceRuleImportPreview>(:final ParseFailureKind kind) =>
          RulesImportState.failed(kind),
      };
    } on Exception catch (error, stackTrace) {
      // C-ERR-2 的 presentation 兜底：读文件 / 下载失败不该把页面留在 loading。
      ref
          .read(appLoggerProvider)
          .error('Replace rule import failed', error, stackTrace);

      state = const RulesImportState.failed(ParseFailureKind.parseFailed);
    }
  }

  /// Stores the previewed entries whose `index` is in [selected].
  Future<void> commit(Set<int> selected) async {
    final RulesImportState current = state;
    if (current is! RulesImportPreviewing) {
      return;
    }
    state = const RulesImportState.committing();

    try {
      final ParseResult<ReplaceRuleImportReport> result = await (await ref.read(
        importReplaceRulesProvider.future,
      )).commit(current.preview, selected);

      state = switch (result) {
        ParseSuccess<ReplaceRuleImportReport>(
          :final ReplaceRuleImportReport data,
        ) =>
          RulesImportState.done(data),
        ParseFailure<ReplaceRuleImportReport>(:final ParseFailureKind kind) =>
          RulesImportState.failed(kind),
      };
      // 净化规则变了：列表与正文缓存都要跟着作废（后者由仓储在写入时处理）。
      ref.invalidate(rulesListProvider(RuleKind.replace));
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Replace rule import commit failed', error, stackTrace);

      state = const RulesImportState.failed(ParseFailureKind.parseFailed);
    }
  }
}
