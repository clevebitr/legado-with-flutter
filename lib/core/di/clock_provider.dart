import 'package:flutter_reader/core/utils/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// Provides the clock every time-dependent component reads (C-NET-6,
/// `docs/dev/testing.md` §4).
///
/// Tests override it with a fixed clock instead of sleeping.
@riverpod
Clock clock(Ref ref) => const SystemClock();
