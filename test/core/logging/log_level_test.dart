import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogLevel', () {
    test('parse_whenValueMatchesEnumName_returnsThatLevel', () {
      expect(LogLevel.parse('debug'), LogLevel.debug);
      expect(LogLevel.parse('info'), LogLevel.info);
      expect(LogLevel.parse('warning'), LogLevel.warning);
      expect(LogLevel.parse('error'), LogLevel.error);
      expect(LogLevel.parse('off'), LogLevel.off);
    });

    test('parse_whenValueDiffersInCaseOrWhitespace_returnsThatLevel', () {
      expect(LogLevel.parse(' INFO '), LogLevel.info);
      expect(LogLevel.parse('Warning'), LogLevel.warning);
    });

    test('parse_whenValueIsUnrecognised_fallsBackToInfo', () {
      expect(LogLevel.parse('verbose'), LogLevel.info);
      expect(LogLevel.parse(''), LogLevel.info);
    });
  });
}
