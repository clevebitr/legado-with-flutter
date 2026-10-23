/// How the app picks its light / dark scheme (`docs/dev/roadmap.md` 5.6).
///
/// The enum stays Flutter-free (C-ARCH-7): the mapping to `ThemeMode` is one `switch` in
/// `presentation/`, so `domain/` never imports the UI framework.
enum AppThemeMode {
  /// Follow the platform.
  system(0),

  /// Always the light scheme.
  light(1),

  /// Always the dark scheme.
  dark(2);

  const AppThemeMode(this.storageValue);

  /// The value stored in `shared_preferences` (`features/settings/data/`).
  final int storageValue;

  /// Reads a stored value back; an unknown number falls back to [system].
  ///
  /// Falling back rather than throwing keeps a value written by a newer build from turning the
  /// app into an error screen — "follow the platform" is the harmless direction.
  static AppThemeMode fromStorage(int value) => switch (value) {
    1 => light,
    2 => dark,
    _ => system,
  };
}
