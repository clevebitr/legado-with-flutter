import 'dart:io';

import 'package:flutter_reader/core/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appVersion_matchesPubspecVersion', () {
    // `appVersion` 是 pubspec 的镜像（备份 manifest 要写它），这条测试保证两处不会悄悄分叉。
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(appVersion, match?.group(1));
  });
}
