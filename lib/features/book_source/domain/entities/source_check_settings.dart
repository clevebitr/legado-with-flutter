import 'package:flutter_reader/features/book_source/domain/entities/source_check.dart';
import 'package:flutter_reader/features/book_source/domain/source_check_keyword.dart';

/// The per-source timeout of a batch check (`docs/dev/roadmap.md` §5.10).
///
/// Upstream's default (`AppSettingsProvider` / `CheckSourceSettings`); 180 s is chosen so that a
/// source with several paged requests still finishes, while a dead site does not hold a worker
/// forever.
///
/// **A timeout is "stop waiting", not "stop working":** the HTTP layer has no cancellation
/// primitive (C-NET-1), so the abandoned request still ends on its own policy timeout (`httpPolicy`
/// default 15 s). That is why the batch also runs at most `maxConcurrentPerSource` sources at a
/// time — the leftover request dies inside that budget instead of piling up.
const Duration defaultSourceCheckTimeout = Duration(seconds: 180);

/// What one batch check should do (`docs/dev/roadmap.md` §5.10, ADR-0043 §决策 2).
///
/// The stage switches and the keyword are **page state** in this milestone: nothing is persisted
/// (registered as open in `docs/dev/roadmap.md` §3.7), so the defaults below are what a user gets
/// when they open the check page.
final class SourceCheckSettings {
  /// Creates check settings.
  const SourceCheckSettings({
    this.stages = allStages,
    this.keyword = defaultCheckKeyword,
    this.timeout = defaultSourceCheckTimeout,
  });

  /// Every stage switched on, which is what "check this source" means by default.
  static const Set<SourceCheckStage> allStages = <SourceCheckStage>{
    SourceCheckStage.search,
    SourceCheckStage.explore,
    SourceCheckStage.info,
    SourceCheckStage.toc,
    SourceCheckStage.content,
  };

  /// The stages to run; a stage left out is not even attempted.
  final Set<SourceCheckStage> stages;

  /// The keyword to search with when the source declares no usable `checkKeyWord`
  /// (`resolveCheckKeyword`).
  final String keyword;

  /// How long one source may take before the check gives up on it.
  final Duration timeout;

  /// Whether [stage] should run.
  bool runs(SourceCheckStage stage) => stages.contains(stage);

  /// Returns a copy with the given switches replaced.
  SourceCheckSettings copyWith({
    Set<SourceCheckStage>? stages,
    String? keyword,
    Duration? timeout,
  }) => SourceCheckSettings(
    stages: stages ?? this.stages,
    keyword: keyword ?? this.keyword,
    timeout: timeout ?? this.timeout,
  );

  /// Whether [other] asks for the same work.
  ///
  /// Set equality is explicit because a `Set` compares by identity: two settings that both run
  /// "all stages" must be equal, or the page would rebuild on every keystroke of a keyword that
  /// did not change.
  @override
  bool operator ==(Object other) =>
      other is SourceCheckSettings &&
      other.stages.length == stages.length &&
      other.stages.containsAll(stages) &&
      other.keyword == keyword &&
      other.timeout == timeout;

  @override
  int get hashCode =>
      Object.hash(Object.hashAllUnordered(stages), keyword, timeout);
}
