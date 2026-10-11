import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reader/core/platform/platform_info.dart';

/// Source of the operating system's dynamic color scheme (C-UI-3, C-PLT-2).
///
/// Implementations never throw: a platform without dynamic color hands `null`
/// to the builder, and the caller falls back to the seed color (C-PLT-3/4,
/// `docs/dev/platform.md` §2). Callers must treat `null` as a normal branch and
/// never unwrap it (C-TYPE-2).
abstract interface class DynamicColorProvider {
  /// Wraps [builder] so it receives the system schemes.
  ///
  /// Either scheme is `null` when the platform does not support dynamic color
  /// or the OS has not answered yet.
  Widget resolve(
    Widget Function(ColorScheme? light, ColorScheme? dark) builder,
  );
}

/// Resolves dynamic color through `dynamic_color`'s [DynamicColorBuilder].
///
/// This is the only allowed color source (ADR-0004 §5, C-UI-3); the package
/// itself returns `null` below Android 12, so the seed color fallback needs no
/// version check here.
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

/// Returns the provider that fits [info], or `null` when the platform has no
/// dynamic color at all.
///
/// Windows and iOS always take the `null` branch (`docs/dev/platform.md` §3);
/// Android is routed to [SystemDynamicColorProvider], which yields `null` on
/// pre-Android 12 devices as well.
DynamicColorProvider? resolveDynamicColorProvider(PlatformInfo info) =>
    info.isAndroid ? const SystemDynamicColorProvider() : null;
