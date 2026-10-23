// coverage:ignore-file
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_debug.freezed.dart';

/// The one thing the debug console runs on a source (`docs/dev/roadmap.md` §5.10).
///
/// It mirrors upstream's five targets (`BookSourceDebugTarget`); the query means a different value
/// per target — a keyword for [search], a category URL for [explore], and the page URL itself for
/// the other three.
enum SourceDebugTarget {
  /// Search with a keyword (`searchUrl` + `ruleSearch`).
  search,

  /// Open one discover-page category (`exploreUrl` + `ruleExplore`).
  explore,

  /// Read one book's detail page (`ruleBookInfo`).
  info,

  /// Read one table of contents (`ruleToc`).
  toc,

  /// Read one chapter body (`ruleContent`).
  content,
}

/// What one line of the debug console is (`Debug.EventKind` upstream).
///
/// Three kinds, because the console exists to answer three questions: what the run is doing, which
/// URL it just touched, and what went wrong. The UI filters on them; the payload of a line is
/// [SourceDebugEvent.text], which carries **data** (a count, a URL, a rule path) and never a page
/// body (C-SEC-4).
enum SourceDebugEventKind {
  /// What the run is doing.
  message,

  /// A URL the run just touched.
  source,

  /// A failure, with its kind and rule path.
  error,
}

/// Where one debug run stands.
///
/// No `pending`: a debug run is one query, so it is either not started ([idle]), running, or the
/// run ended in one of the three terminal states — and a cancelled run is cancelled, never failed
/// (ADR-0043 §后果).
enum SourceDebugStatus {
  /// Nothing has run yet (upstream's `Idle`).
  idle,

  /// The run is still going.
  running,

  /// The target read something.
  succeeded,

  /// The target failed (the error line says where).
  failed,

  /// The user stopped the run.
  cancelled,
}

/// One line of the debug event stream.
///
/// [text] is a **technical payload**, not interface copy: `books=12`, `chars=1532`, `tocRule`
/// and the like. That is why it is not in ARB (C-UI-5 covers labels, which the page takes from ARB
/// per [kind]). It must never carry a page body, a cookie or a token (C-SEC-4, C-ERR-8).
@Freezed(copyWith: false)
abstract class SourceDebugEvent with _$SourceDebugEvent {
  /// Creates one event.
  const factory SourceDebugEvent({
    required SourceDebugEventKind kind,
    required SourceDebugTarget target,
    required String text,
    String? url,
    ParseFailureKind? failureKind,
    String? rulePath,
    required int elapsedMillis,
  }) = _SourceDebugEvent;
}
