import 'package:flutter_reader/core/logging/log_level.dart';
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

/// The folder user-picked images are stored in (`ADR-0075` §决策 1).
const String backgroundImageFolder = 'backgrounds';

/// The log level new installs start with (`ADR-0082`).
const LogLevel defaultLogLevel = LogLevel.info;

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
    required this.allowPlainHttp,
    required this.seedColor,
    required this.backgroundImageName,
    required this.logLevel,
  });

  /// Creates settings, clamping every value into its documented range.
  factory AppSettings({
    AppThemeMode themeMode = AppThemeMode.system,
    double fontScale = 1,
    int maxConcurrentPerSource = defaultMaxConcurrentRequestsPerSource,
    bool allowPlainHttp = false,
    int? seedColor,
    String? backgroundImageName,
    LogLevel logLevel = defaultLogLevel,
  }) => AppSettings._(
    themeMode: themeMode,
    fontScale: fontScale.clamp(minFontScale, maxFontScale),
    maxConcurrentPerSource: maxConcurrentPerSource.clamp(
      minConcurrentBudget,
      maxConcurrentBudget,
    ),
    allowPlainHttp: allowPlainHttp,
    seedColor: seedColor,
    backgroundImageName: backgroundImageName,
    logLevel: logLevel,
  );

  /// The settings used before anything was stored and while the store is still loading.
  static const AppSettings defaults = AppSettings._(
    themeMode: AppThemeMode.system,
    fontScale: 1,
    maxConcurrentPerSource: defaultMaxConcurrentRequestsPerSource,
    allowPlainHttp: false,
    seedColor: null,
    backgroundImageName: null,
    logLevel: defaultLogLevel,
  );

  /// Which scheme the app follows.
  final AppThemeMode themeMode;

  /// Multiplier applied on top of the platform's own text scaling (1 = untouched).
  final double fontScale;

  /// Requests one book source may have in flight at once (`book-source.md` §8).
  final int maxConcurrentPerSource;

  /// The seed colour (ARGB) the theme is built from, or `null` for the project default
  /// (`ADR-0075` §决策 1).
  ///
  /// Stored as an `int` because `domain/` may not import Flutter (C-ARCH-7); the theme builder turns
  /// it into a `Color`. A platform that reports dynamic color still wins over this value.
  final int? seedColor;

  /// The file name of the theme background inside `backgrounds/`, or `null` for none.
  ///
  /// A **name**, never a path: the bytes were copied into the app's directory when the user picked
  /// them, so the setting survives the original file moving or an expired Android URI grant.
  final String? backgroundImageName;

  /// The verbosity of the application log (`ADR-0082`).
  ///
  /// A **runtime** choice: the settings page changes it and the façade applies it at once, so a
  /// user chasing a broken source does not need a special build.
  final LogLevel logLevel;

  /// Whether the user allows plaintext `http://` media (C-SEC-2's explicit opt-in).
  ///
  /// Page requests still go through `HttpPolicy` with the same flag; this value is shared by
  /// both lanes, so turning it on cannot silently make the reader fetch pages over http.
  final bool allowPlainHttp;

  /// Returns a copy with the given values, clamped the same way the factory does.
  AppSettings copyWith({
    AppThemeMode? themeMode,
    double? fontScale,
    int? maxConcurrentPerSource,
    bool? allowPlainHttp,
    int? seedColor,
    String? backgroundImageName,
    LogLevel? logLevel,
    bool clearSeedColor = false,
    bool clearBackgroundImage = false,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    fontScale: fontScale ?? this.fontScale,
    maxConcurrentPerSource:
        maxConcurrentPerSource ?? this.maxConcurrentPerSource,
    allowPlainHttp: allowPlainHttp ?? this.allowPlainHttp,
    logLevel: logLevel ?? this.logLevel,
    seedColor: clearSeedColor ? null : (seedColor ?? this.seedColor),
    backgroundImageName: clearBackgroundImage
        ? null
        : (backgroundImageName ?? this.backgroundImageName),
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.fontScale == fontScale &&
      other.maxConcurrentPerSource == maxConcurrentPerSource &&
      other.allowPlainHttp == allowPlainHttp &&
      other.seedColor == seedColor &&
      other.backgroundImageName == backgroundImageName &&
      other.logLevel == logLevel;

  @override
  int get hashCode => Object.hash(
    themeMode,
    fontScale,
    maxConcurrentPerSource,
    allowPlainHttp,
    seedColor,
    backgroundImageName,
    logLevel,
  );
}
