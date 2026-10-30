/// The smallest body text scale the reader offers.
const double minReaderFontScale = 0.8;

/// The largest body text scale the reader offers.
const double maxReaderFontScale = 2;

/// The body text scale a reader starts with.
const double defaultReaderFontScale = 1;

/// The smallest line spacing multiplier the reader offers.
const double minReaderLineHeight = 1.2;

/// The largest line spacing multiplier the reader offers.
const double maxReaderLineHeight = 2.4;

/// The line spacing multiplier a reader starts with.
const double defaultReaderLineHeight = 1.6;

/// The darkest the in-page dimming overlay may go (`ADR-0075 §决策 2`).
const double minReaderBrightness = 0.4;

/// The brightest the in-page dimming overlay may go (no dimming).
const double maxReaderBrightness = 1;

/// The brightness a reader starts with (no dimming).
const double defaultReaderBrightness = 1;

/// The strongest warm (blue-light reducing) filter the reader offers.
const int maxReaderEyeProtection = 100;

/// The warm filter a reader starts with (off).
const int defaultReaderEyeProtection = 0;

/// The shortest auto-page interval, in seconds (ADR-0093 §决策 1).
const int minReaderAutoPageSeconds = 3;

/// The longest auto-page interval, in seconds.
const int maxReaderAutoPageSeconds = 60;

/// The auto-page interval a reader starts with (ADR-0093 §决策 1).
const int defaultReaderAutoPageSeconds = 15;

/// How the reader turns pages (`docs/dev/roadmap.md` 5.3, ADR-0044 §决策 4).
enum ReaderPageMode {
  /// One vertically scrolling body.
  scroll,

  /// Horizontally split pages, sized to the viewport.
  paged,
}

/// The reader's own background palette (`docs/dev/roadmap.md` 5.3).
///
/// It is a **choice among derived surfaces**, not a colour: the page takes its surface from the
/// scheme and shifts it, so the reader still follows the theme and dynamic colour (C-UI-1).
enum ReaderBackground {
  /// The theme's own surface — the reader looks like the rest of the app.
  system,

  /// A warm paper tone for daylight reading.
  paper,

  /// A sepia tone, the classic low-contrast option.
  sepia,

  /// A dark surface for night reading, independent of the theme mode.
  dark,
}

/// The body font family the reader offers (`docs/dev/roadmap.md` §3.9-R4, ADR-0051 §决策 4).
///
/// It maps onto the **platform's** generic family names instead of bundling fonts: a CJK webfont is
/// 10+ MB and would need its own licence review, while `serif` / `sans-serif` / `monospace` exist on
/// every shipped target and fall back to the system font when the family is missing.
enum ReaderFontFamily {
  /// Whatever the theme's text style uses (the app's own font).
  theme,

  /// Serif — the classic reading face.
  serif,

  /// Sans-serif — the system UI face.
  sans,

  /// Monospace.
  mono,
}

/// Page padding presets, in logical pixels (`ADR-0051 §决策 4`).
enum ReaderPagePadding {
  /// 16 px — dense, for small screens.
  narrow,

  /// 24 px — the default.
  medium,

  /// 32 px — airy, for tablets and desktops.
  wide,
}

/// Paragraph spacing presets, as a multiple of the font size (`ADR-0051 §决策 4`).
const List<double> readerParagraphSpacingSteps = <double>[0, 0.5, 1];

/// First-line indent presets, in `em` (`ADR-0051 §决策 4`).
const List<double> readerFirstLineIndentSteps = <double>[0, 1, 2];

/// The slowest speech rate the TTS sheet offers (ADR-0054 §决策 5).
const double minTtsRate = 0.5;

/// The fastest speech rate the TTS sheet offers (ADR-0054 §决策 5).
const double maxTtsRate = 2;

/// The lowest TTS pitch the sheet offers (ADR-0054 §决策 5).
const double minTtsPitch = 0.5;

/// The highest TTS pitch the sheet offers (ADR-0054 §决策 5).
const double maxTtsPitch = 2;

/// What the reading experience looks like (`docs/dev/roadmap.md` 5.3, ADR-0044 §决策 1).
///
/// Every value is **clamped in the factory**, not asserted: an assertion is stripped in release
/// builds, and a hand-edited store must not be able to produce an unreadable body (the same
/// reasoning `AppSettings` records for the concurrency budget).
///
/// These axes are the **reader's**, not the app's: the settings page's text scale is the
/// accessibility multiplier for the whole app, and the reader's [fontScale] multiplies the body on
/// top of it (ADR-0044 §决策 1).
final class ReaderSettings {
  const ReaderSettings._({
    required this.fontScale,
    required this.lineHeight,
    required this.brightness,
    required this.background,
    required this.pageMode,
    required this.fontFamily,
    required this.paragraphSpacing,
    required this.firstLineIndent,
    required this.pagePadding,
    required this.ttsRate,
    required this.ttsPitch,
    required this.ttsVoiceName,
    required this.ttsVoiceLocale,
    required this.stopTtsOnExit,
    required this.keepScreenAwake,
    required this.eyeProtection,
    required this.showReaderStatus,
    required this.autoPageSeconds,
  });

  /// Creates reader settings, clamping both numeric values into their documented ranges.
  factory ReaderSettings({
    double fontScale = defaultReaderFontScale,
    double lineHeight = defaultReaderLineHeight,
    double brightness = defaultReaderBrightness,
    ReaderBackground background = ReaderBackground.system,
    ReaderPageMode pageMode = ReaderPageMode.scroll,
    ReaderFontFamily fontFamily = ReaderFontFamily.theme,
    double paragraphSpacing = 0.5,
    double firstLineIndent = 2,
    ReaderPagePadding pagePadding = ReaderPagePadding.medium,
    double ttsRate = 1,
    double ttsPitch = 1,
    String? ttsVoiceName,
    String? ttsVoiceLocale,
    bool stopTtsOnExit = true,
    bool keepScreenAwake = true,
    int eyeProtection = defaultReaderEyeProtection,
    bool showReaderStatus = true,
    int autoPageSeconds = defaultReaderAutoPageSeconds,
  }) => ReaderSettings._(
    fontScale: fontScale.clamp(minReaderFontScale, maxReaderFontScale),
    lineHeight: lineHeight.clamp(minReaderLineHeight, maxReaderLineHeight),
    brightness: brightness.clamp(minReaderBrightness, maxReaderBrightness),
    background: background,
    pageMode: pageMode,
    fontFamily: fontFamily,
    // 段距与缩进只在预设台阶上：读回来的是 UI 能表示的取值（与字号 / 行距同一条理由）。
    paragraphSpacing: _nearest(readerParagraphSpacingSteps, paragraphSpacing),
    firstLineIndent: _nearest(readerFirstLineIndentSteps, firstLineIndent),
    pagePadding: pagePadding,
    ttsRate: ttsRate.clamp(minTtsRate, maxTtsRate),
    ttsPitch: ttsPitch.clamp(minTtsPitch, maxTtsPitch),
    ttsVoiceName: ttsVoiceName,
    ttsVoiceLocale: ttsVoiceLocale,
    stopTtsOnExit: stopTtsOnExit,
    keepScreenAwake: keepScreenAwake,
    eyeProtection: eyeProtection.clamp(0, maxReaderEyeProtection),
    showReaderStatus: showReaderStatus,
    autoPageSeconds: autoPageSeconds.clamp(
      minReaderAutoPageSeconds,
      maxReaderAutoPageSeconds,
    ),
  );

  /// What a reader that has stored nothing yet uses.
  static const ReaderSettings defaults = ReaderSettings._(
    fontScale: defaultReaderFontScale,
    lineHeight: defaultReaderLineHeight,
    brightness: defaultReaderBrightness,
    background: ReaderBackground.system,
    pageMode: ReaderPageMode.scroll,
    fontFamily: ReaderFontFamily.theme,
    paragraphSpacing: 0.5,
    firstLineIndent: 2,
    pagePadding: ReaderPagePadding.medium,
    ttsRate: 1,
    ttsPitch: 1,
    ttsVoiceName: null,
    ttsVoiceLocale: null,
    stopTtsOnExit: true,
    keepScreenAwake: true,
    eyeProtection: defaultReaderEyeProtection,
    showReaderStatus: true,
    autoPageSeconds: defaultReaderAutoPageSeconds,
  );

  /// Body text multiplier, on top of the app's accessibility scale.
  final double fontScale;

  /// Line height multiplier for the body text.
  final double lineHeight;

  /// The opacity of the in-page dimming overlay (`ADR-0075 §决策 2`), 0.4–1.
  ///
  /// It is an **app-level mask**, not the system brightness: the reader can only dim, and leaving
  /// the page restores the system untouched.
  final double brightness;

  /// Which derived surface the page paints.
  final ReaderBackground background;

  /// Whether the body scrolls or is split into pages.
  final ReaderPageMode pageMode;

  /// Which family the body text uses (`ADR-0051 §决策 4`).
  final ReaderFontFamily fontFamily;

  /// Space between paragraphs, as a multiple of the font size.
  final double paragraphSpacing;

  /// First-line indent, in `em`.
  final double firstLineIndent;

  /// Which page-padding preset the body uses.
  final ReaderPagePadding pagePadding;

  /// Speech rate multiplier for the TTS reader (1.0 = normal, ADR-0054 §决策 5).
  final double ttsRate;

  /// Speech pitch for the TTS reader (1.0 = normal, ADR-0054 §决策 5).
  final double ttsPitch;

  /// The system voice the reader picked, or `null` for the platform default.
  final String? ttsVoiceName;

  /// The locale of [ttsVoiceName], which the platform needs to resolve the voice.
  final String? ttsVoiceLocale;

  /// Whether leaving the reader stops speech (ADR-0054 §决策 5).
  final bool stopTtsOnExit;

  /// Whether the display stays on while the reader is open (ADR-0086 §决策 1).
  final bool keepScreenAwake;

  /// How strong the warm (blue-light reducing) filter is, 0–100 (ADR-0086 §决策 2).
  final int eyeProtection;

  /// Whether the reading view shows the status line: chapter, progress, time, charge
  /// (ADR-0086 §决策 6).
  final bool showReaderStatus;

  /// Seconds between two automatic page turns (ADR-0093 §决策 1).
  final int autoPageSeconds;

  /// Returns a copy with the given values, clamped the same way the factory does.
  ReaderSettings copyWith({
    double? fontScale,
    double? lineHeight,
    double? brightness,
    ReaderBackground? background,
    ReaderPageMode? pageMode,
    ReaderFontFamily? fontFamily,
    double? paragraphSpacing,
    double? firstLineIndent,
    ReaderPagePadding? pagePadding,
    double? ttsRate,
    double? ttsPitch,
    String? ttsVoiceName,
    String? ttsVoiceLocale,
    bool? stopTtsOnExit,
    bool? keepScreenAwake,
    int? eyeProtection,
    bool? showReaderStatus,
    int? autoPageSeconds,
    bool clearTtsVoice = false,
  }) => ReaderSettings(
    fontScale: fontScale ?? this.fontScale,
    lineHeight: lineHeight ?? this.lineHeight,
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    pageMode: pageMode ?? this.pageMode,
    fontFamily: fontFamily ?? this.fontFamily,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    firstLineIndent: firstLineIndent ?? this.firstLineIndent,
    pagePadding: pagePadding ?? this.pagePadding,
    ttsRate: ttsRate ?? this.ttsRate,
    ttsPitch: ttsPitch ?? this.ttsPitch,
    ttsVoiceName: clearTtsVoice ? null : ttsVoiceName ?? this.ttsVoiceName,
    ttsVoiceLocale: clearTtsVoice
        ? null
        : ttsVoiceLocale ?? this.ttsVoiceLocale,
    stopTtsOnExit: stopTtsOnExit ?? this.stopTtsOnExit,
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    eyeProtection: eyeProtection ?? this.eyeProtection,
    showReaderStatus: showReaderStatus ?? this.showReaderStatus,
    autoPageSeconds: autoPageSeconds ?? this.autoPageSeconds,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.fontScale == fontScale &&
      other.lineHeight == lineHeight &&
      other.brightness == brightness &&
      other.background == background &&
      other.pageMode == pageMode &&
      other.fontFamily == fontFamily &&
      other.paragraphSpacing == paragraphSpacing &&
      other.firstLineIndent == firstLineIndent &&
      other.pagePadding == pagePadding &&
      other.ttsRate == ttsRate &&
      other.ttsPitch == ttsPitch &&
      other.ttsVoiceName == ttsVoiceName &&
      other.ttsVoiceLocale == ttsVoiceLocale &&
      other.stopTtsOnExit == stopTtsOnExit &&
      other.keepScreenAwake == keepScreenAwake &&
      other.eyeProtection == eyeProtection &&
      other.showReaderStatus == showReaderStatus;

  @override
  int get hashCode => Object.hash(
    fontScale,
    lineHeight,
    brightness,
    background,
    pageMode,
    fontFamily,
    paragraphSpacing,
    firstLineIndent,
    pagePadding,
    ttsRate,
    ttsPitch,
    ttsVoiceName,
    ttsVoiceLocale,
    stopTtsOnExit,
    keepScreenAwake,
    eyeProtection,
    showReaderStatus,
  );
}

/// The step in [steps] closest to [value] (ties go to the smaller one).
double _nearest(List<double> steps, double value) {
  var best = steps.first;
  for (final double step in steps) {
    if ((step - value).abs() < (best - value).abs()) {
      best = step;
    }
  }

  return best;
}

/// The page padding preset's logical pixels (`ADR-0051 §决策 4`).
double readerPagePaddingOf(ReaderPagePadding padding) => switch (padding) {
  ReaderPagePadding.narrow => 16,
  ReaderPagePadding.medium => 24,
  ReaderPagePadding.wide => 32,
};

/// The platform font family name of [family], or `null` for “the theme's own”.
///
/// The same generic names Flutter documents for `TextStyle.fontFamily`, which resolve to a real
/// face on every shipped target and fall back to the system font otherwise (ADR-0051 §决策 4).
String? readerFontFamilyName(ReaderFontFamily family) => switch (family) {
  ReaderFontFamily.theme => null,
  ReaderFontFamily.serif => 'serif',
  ReaderFontFamily.sans => 'sans-serif',
  ReaderFontFamily.mono => 'monospace',
};
