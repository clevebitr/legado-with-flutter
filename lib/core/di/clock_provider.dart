import 'package:flutter_reader/core/utils/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// Provides the clock every time-dependent component reads.
///
/// Tests override it with a fixed clock instead of sleeping.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();
