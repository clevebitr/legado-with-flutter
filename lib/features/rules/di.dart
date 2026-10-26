import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/features/rules/data/rule_repository_impl.dart';
import 'package:flutter_reader/features/rules/data/rule_seed_loader_impl.dart';
import 'package:flutter_reader/features/rules/domain/repositories/chapter_body_invalidator.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_repository.dart';
import 'package:flutter_reader/features/rules/domain/repositories/rule_seed_loader.dart';
import 'package:flutter_reader/features/rules/domain/usecases/export_replace_rules.dart';
import 'package:flutter_reader/features/rules/domain/usecases/import_replace_rules.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the rules repository (`docs/dev/roadmap.md` M20, ADR-0070).
@Riverpod(keepAlive: true)
Future<RuleRepository> ruleRepository(Ref ref) async => RuleRepositoryImpl(
  dao: ref.watch(ruleDaoProvider),
  seeds: ref.watch(ruleSeedLoaderProvider),
  preferences: await ref.watch(preferenceStoreProvider.future),
  invalidator: ref.watch(chapterBodyInvalidatorProvider),
  clock: ref.watch(clockProvider),
  logger: ref.watch(appLoggerProvider),
);

/// Provides the replace-rule import (`docs/dev/roadmap.md` M23, ADR-0071 §决策 2).
@Riverpod(keepAlive: true)
Future<ImportReplaceRules> importReplaceRules(Ref ref) async =>
    ImportReplaceRules(
      repository: await ref.watch(ruleRepositoryProvider.future),
      http: ref.watch(httpClientProvider),
      logger: ref.watch(appLoggerProvider),
    );

/// Provides the replace-rule export (`docs/dev/roadmap.md` M23, ADR-0071 §决策 1).
@Riverpod(keepAlive: true)
Future<ExportReplaceRules> exportReplaceRules(Ref ref) async =>
    ExportReplaceRules(
      repository: await ref.watch(ruleRepositoryProvider.future),
      logger: ref.watch(appLoggerProvider),
    );

/// Provides the loader of the bundled seed rules.
@Riverpod(keepAlive: true)
RuleSeedLoader ruleSeedLoader(Ref ref) =>
    AssetRuleSeedLoader(logger: ref.watch(appLoggerProvider));

/// Provides the port that retires cached chapter bodies, **unbound** by default.
///
/// The composition root overrides it with `book_source`'s `ContentCache` (ADR-0041 §决策 2). The
/// default drops nothing and says so, so a forgotten binding costs a stale chapter instead of a
/// broken rule page.
@Riverpod(keepAlive: true)
ChapterBodyInvalidator chapterBodyInvalidator(Ref ref) =>
    UnboundChapterBodyInvalidator(logger: ref.watch(appLoggerProvider));
