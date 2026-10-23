import 'dart:io';

import 'package:flutter_reader/features/shell/presentation/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appVersion', () {
    test('appVersion_whenComparedWithPubspec_matches', () {
      // 版本号是手写常量（不引平台插件），这里直接读 pubspec 兜底（ADR-0055 §决策 4）。
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final RegExp version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true);

      expect(version.firstMatch(pubspec)?.group(1), appVersion);
    });
  });
}
