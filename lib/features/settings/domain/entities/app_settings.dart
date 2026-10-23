import 'package:flutter_reader/core/network/request_limiter.dart';
import 'package:flutter_reader/features/settings/domain/entities/app_theme_mode.dart';

/// Smallest text scale the settings page offers.
const double minFontScale = 0.8;

/// Largest text scale the settings page offers.
const double maxFontScale = 2.0;

/// Smallest per-source concurrency budget the settings page offers.
///
/// **One is the floor, not zero:** `RequestLimiter` caps in-flight requests per source, and a
/// budget of `0` would queue every request of that source forever — the failure
/// `docs/dev/roadmap.md` §3.7 registered, where the only guard was an `assert` that release
/// builds strip.
const int minConcurrentBudget = 1;

/// Largest per-source concurrency budget the settings page offers.
///
/// Eight is a politeness bound, not a technical limit: a source that declares `concurrentRate`
/// still passes its own rate gate first (`book-source.md` §8).
const int maxConcurrentBudget = 8;

/// The light switches the user chose (C-NET-9: these live in `shared_preferences`).
///
/// Every value is **clamped in the factory**, not asserted: an assertion would be stripped in
/// release builds, which is exactly how a `0` concurrency budget used to slip through
/// (`docs/dev/roadmap.md` §3.7). The constructor is private, so no code path can build an
/// unclamped instance.
final class AppSettings {
  const AppSettings._({
    required this.themeMode,
    required this.fontScale,
    required this.maxConcurrentPerSource,
  });

  /// Creates settings, clamping every value into its documented range.
  factory AppSettings({
    AppThemeMode themeMode = AppThemeMode.system,
    double fontScale = 1,
    int maxConcurrentPerSource = defaultMaxConcurrentRequestsPerSource,
  }) => AppSettings._(
    themeMode: themeMode,
    fontScale: fontScale.clamp(minFontScale, maxFontScale),
    maxConcurrentPerSource: maxConcurrentPerSource.clamp(
      minConcurrentBudget,
      maxConcurrentBudget,
    ),
  );

  /// The settings used before anything was stored and while the store is still loading.
  static const AppSettings defaults = AppSettings._(
    themeMode: AppThemeMode.system,
    fontScale: 1,
    maxConcurrentPerSource: defaultMaxConcurrentRequestsPerSource,
  );

  /// Which scheme the app follows.
  final AppThemeMode themeMode;

  /// Multiplier applied on top of the platform's own text scaling (1 = untouched).
  final double fontScale;

  /// Requests one book source may have in flight at once (`book-source.md` §8).
  final int maxConcurrentPerSource;

  /// Returns a copy with the given values, clamped the same way the factory does.
  AppSettings copyWith({
    AppThemeMode? themeMode,
    double? fontScale,
    int? maxConcurrentPerSource,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    fontScale: fontScale ?? this.fontScale,
    maxConcurrentPerSource:
        maxConcurrentPerSource ?? this.maxConcurrentPerSource,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.fontScale == fontScale &&
      other.maxConcurrentPerSource == maxConcurrentPerSource;

  @override
  int get hashCode => Object.hash(themeMode, fontScale, maxConcurrentPerSource);
}
