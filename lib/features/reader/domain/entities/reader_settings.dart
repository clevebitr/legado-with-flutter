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
    required this.background,
    required this.pageMode,
  });

  /// Creates reader settings, clamping both numeric values into their documented ranges.
  factory ReaderSettings({
    double fontScale = defaultReaderFontScale,
    double lineHeight = defaultReaderLineHeight,
    ReaderBackground background = ReaderBackground.system,
    ReaderPageMode pageMode = ReaderPageMode.scroll,
  }) => ReaderSettings._(
    fontScale: fontScale.clamp(minReaderFontScale, maxReaderFontScale),
    lineHeight: lineHeight.clamp(minReaderLineHeight, maxReaderLineHeight),
    background: background,
    pageMode: pageMode,
  );

  /// What a reader that has stored nothing yet uses.
  static const ReaderSettings defaults = ReaderSettings._(
    fontScale: defaultReaderFontScale,
    lineHeight: defaultReaderLineHeight,
    background: ReaderBackground.system,
    pageMode: ReaderPageMode.scroll,
  );

  /// Body text multiplier, on top of the app's accessibility scale.
  final double fontScale;

  /// Line height multiplier for the body text.
  final double lineHeight;

  /// Which derived surface the page paints.
  final ReaderBackground background;

  /// Whether the body scrolls or is split into pages.
  final ReaderPageMode pageMode;

  /// Returns a copy with the given values, clamped the same way the factory does.
  ReaderSettings copyWith({
    double? fontScale,
    double? lineHeight,
    ReaderBackground? background,
    ReaderPageMode? pageMode,
  }) => ReaderSettings(
    fontScale: fontScale ?? this.fontScale,
    lineHeight: lineHeight ?? this.lineHeight,
    background: background ?? this.background,
    pageMode: pageMode ?? this.pageMode,
  );

  @override
  bool operator ==(Object other) =>
      other is ReaderSettings &&
      other.fontScale == fontScale &&
      other.lineHeight == lineHeight &&
      other.background == background &&
      other.pageMode == pageMode;

  @override
  int get hashCode => Object.hash(fontScale, lineHeight, background, pageMode);
}
