import 'package:logger/logger.dart';

/// In-memory log collector: captures the `LogEvent` itself, so tests can assert
/// both the level and the content (`docs/dev/testing.md` §4).
final class FakeLogPrinter extends LogPrinter {
  /// Records received in order.
  final List<LogEvent> events = <LogEvent>[];

  @override
  List<String> log(LogEvent event) {
    events.add(event);
    return const <String>[];
  }
}
