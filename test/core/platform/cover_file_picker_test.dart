import 'package:flutter_reader/core/platform/cover_file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a picked file at runtime: parameters keep the constructor invocation non-constant, and a
/// `const` constructor is folded by the compiler so its line never reaches the coverage report (the
/// pitfall recorded after M14).
PickedCoverFile _file(String name, List<int> bytes) =>
    PickedCoverFile(name: name, bytes: bytes);

/// Builds the fallback at runtime, for the same coverage reason as [_file].
CoverFilePicker _fallback() =>
    // ignore: prefer_const_constructors  const folding hides the constructor line from lcov
    UnsupportedCoverFilePicker();

void main() {
  group('PickedCoverFile', () {
    test('new_whenCalled_keepsTheNameAndBytes', () {
      final PickedCoverFile file = _file('cover.jpg', <int>[1, 2]);

      expect(file.name, 'cover.jpg');
      expect(file.bytes, <int>[1, 2]);
    });
  });

  group('UnsupportedCoverFilePicker', () {
    test('pick_whenThePlatformHasNoDialog_answersNull', () async {
      // 「没有对话框」与「用户取消」是同一个答案（platform.md §2）：调用方什么都不做。
      expect(await _fallback().pick(), isNull);
    });
  });
}
