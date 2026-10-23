import 'package:flutter_reader/features/settings/presentation/settings_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsRoute', () {
    test('path_whenSettings_isTheSettingsPath', () {
      expect(const SettingsRoute.settings().path, '/settings');
    });
  });
}
