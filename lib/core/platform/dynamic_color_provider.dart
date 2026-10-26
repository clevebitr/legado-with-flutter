import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';

/// Source of the operating system's dynamic color scheme.
///
/// Implementations never throw; a platform without dynamic color passes `null` to the builder and
/// the caller falls back to its seed color.
abstract interface class DynamicColorProvider {
  /// Wraps [builder] so it receives the system schemes, either of which may be `null`.
  Widget resolve(
    Widget Function(ColorScheme? light, ColorScheme? dark) builder,
  );
}

/// Resolves dynamic color through `dynamic_color`'s [DynamicColorBuilder].
final class SystemDynamicColorProvider implements DynamicColorProvider {
  /// Creates the system-backed implementation.
  const SystemDynamicColorProvider();

  @override
  Widget resolve(
    Widget Function(ColorScheme? light, ColorScheme? dark) builder,
  ) => DynamicColorBuilder(
    builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) =>
        builder(lightDynamic, darkDynamic),
  );
}

/// Returns the provider that fits [info], or `null` when the platform has no dynamic color.
DynamicColorProvider? resolveDynamicColorProvider(PlatformInfo info) =>
    info.isAndroid ? const SystemDynamicColorProvider() : null;
