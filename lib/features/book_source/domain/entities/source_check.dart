// coverage:ignore-file
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_check.freezed.dart';

/// The stages one batch check can run (`docs/dev/roadmap.md` §5.10).
///
/// `search` starts from a keyword, `explore` from a discover-page category, and the last three
/// follow whichever book the first two produced — upstream's order
/// (`BookSourceCheckRepository.kt:196-247`). Each one can be switched off, because a user may want
/// to know whether only the body rule broke.
enum SourceCheckStage {
  /// `searchUrl` + `ruleSearch` produce at least one book.
  search,

  /// `exploreUrl` + `ruleExplore` produce at least one book.
  explore,

  /// `ruleBookInfo` reads the detail page of a book.
  info,

  /// `ruleToc` reads at least one chapter.
  toc,

  /// `ruleContent` reads a non-empty body for the first chapter.
  content,
}

/// Where one source's check stands (`BookSourceCheckGateway.kt:5-11`).
///
/// The three terminal values are what the progress counter counts; [pending] and [running] are the
/// two the UI shows while the batch is still going. A cancelled source is **cancelled**, never
/// failed: the user stopped it, so nothing about the source was proven (ADR-0043 §后果).
enum SourceCheckStatus {
  /// Not started yet.
  pending,

  /// Running right now.
  running,

  /// Every stage that ran was usable.
  succeeded,

  /// The run finished, but at least one stage wrote an invalid group.
  failed,

  /// The user stopped the batch; nothing about the source was proven.
  cancelled,
}

/// Why a source's check did not produce a verdict (`BookSourceCheckGateway.kt:13-18`, minus one).
///
/// [checkFailed] means the pipeline ran and found problems; [sourceMissing] means the row was
/// deleted meanwhile; [saveFailed] means the verdict could not be written back.
///
/// Upstream's fourth value `Incomplete` has **no counterpart here**: cancellation is cooperative
/// (ADR-0043 §后果), so a stopped batch leaves every remaining source `cancelled` rather than
/// `failed + incomplete` — there is never a half-finished entry to describe.
enum SourceCheckFailure {
  /// The pipeline ran and found problems (the report's groups say which).
  checkFailed,

  /// The stored row was deleted while the batch was running.
  sourceMissing,

  /// The verdict could not be written back.
  saveFailed,
}

/// What one stage of one source's check did.
///
/// [failureKind] and [rulePath] carry the stage's own failure verbatim (`ParseFailureKind` +
/// `book-source.md` §7 path), so the UI can name the failing rule without inventing a second error
/// model (ADR-0043 §决策 4). [invalidGroup] is the token that was written into the source's group
/// list, or `null` when this stage was fine.
@Freezed(copyWith: false)
abstract class SourceCheckStageOutcome with _$SourceCheckStageOutcome {
  /// Creates one stage outcome.
  const factory SourceCheckStageOutcome({
    /// The stage this outcome belongs to.
    required SourceCheckStage stage,

    /// Whether the stage was usable, failed or was skipped by a stop.
    required SourceCheckStatus status,

    /// The failure kind the stage's `ParseResult` carried, when it failed.
    ParseFailureKind? failureKind,

    /// The rule path of the failure (`book-source.md` §7), when it failed.
    String? rulePath,

    /// The group token written into the source's group list, when it failed.
    String? invalidGroup,
  }) = _SourceCheckStageOutcome;
}

/// One source's verdict, produced by `CheckBookSource` and written back by the batch runner.
///
/// The report is **pure data**: it never writes anything itself, which is what lets the domain
/// decide "what is wrong with this source" while `BookSourceRepository` owns the write-back
/// (ADR-0043 §决策 1).
@Freezed(copyWith: false)
abstract class SourceCheckReport with _$SourceCheckReport {
  /// Creates a check report.
  const factory SourceCheckReport({
    required SourceCheckStatus status,

    /// One outcome per stage that actually ran, in [SourceCheckStage] order.
    @Default(<SourceCheckStageOutcome>[]) List<SourceCheckStageOutcome> stages,

    /// The group tokens this run should leave on the source (empty when it is healthy).
    @Default(<String>[]) List<String> invalidGroups,

    /// The error note the run should leave in `bookSourceComment`, or `null` when healthy.
    String? errorComment,

    /// How long the check took, which is what `respondTime` stores.
    required int elapsedMillis,
  }) = _SourceCheckReport;
}
