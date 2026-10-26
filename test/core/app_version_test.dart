import 'dart:io';

import 'package:flutter_reader/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appVersion_withoutABuildDefine_matchesPubspecVersion', () {
    // CI 用 `--dart-define=APP_VERSION=…` 注入渠道版本号（ADR-0067 §决策 2）；没有定义时用的
    // 回退值必须与 `pubspec.yaml` 一致，否则「关于」页与备份 manifest 会报一个不存在的版本。
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(
      const String.fromEnvironment('APP_VERSION', defaultValue: ''),
      isEmpty,
      reason: 'unit tests run without the CI define',
    );
    expect(appVersion, match?.group(1));
  });
}
