import 'package:flutter_reader/core/platform/background_image_picker.dart';
import 'package:flutter_reader/core/platform/file_selector_background_image_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnsupportedBackgroundImagePicker', () {
    test('pick_givenNoDialog_answersNothingPicked', () async {
      expect(await const UnsupportedBackgroundImagePicker().pick(), isNull);
    });
  });

  group('FileSelectorBackgroundImagePicker', () {
    test('pick_givenAPickedImage_answersItsNameAndBytes', () async {
      // 不用 const：const 构造会在编译期折叠，core 层的构造行就没有执行点（ADR-0019）。
      // ignore: prefer_const_constructors
      final PickedBackgroundImage image = PickedBackgroundImage(
        name: 'sky.png',
        bytes: const <int>[1, 2],
      );
      final BackgroundImagePicker picker = FileSelectorBackgroundImagePicker(
        open: () async => image,
      );

      final PickedBackgroundImage? picked = await picker.pick();

      expect(picked?.name, 'sky.png');
      expect(picked?.bytes, <int>[1, 2]);
    });

    test('pick_givenACancelledDialog_answersNull', () async {
      final BackgroundImagePicker picker = FileSelectorBackgroundImagePicker(
        open: () async => null,
      );

      expect(await picker.pick(), isNull);
    });
  });
}
