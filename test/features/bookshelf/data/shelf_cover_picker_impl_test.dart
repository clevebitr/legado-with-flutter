import 'dart:io';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/cover_file_picker.dart';
import 'package:flutter_reader/features/bookshelf/data/shelf_cover_picker_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_cover_file_picker.dart';
import '../../../support/fake_log_printer.dart';

void main() {
  group('ShelfCoverPickerImpl', () {
    late Directory root;
    late FakeCoverFilePicker picker;
    late FakeLogPrinter printer;
    late ShelfCoverPickerImpl store;

    setUp(() {
      root = Directory.systemTemp.createTempSync('shelf_cover_test');
      picker = FakeCoverFilePicker();
      printer = FakeLogPrinter();
      store = ShelfCoverPickerImpl(
        () async => root,
        picker,
        AppLogger(level: LogLevel.debug, printer: printer),
      );
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('pickAndStore_whenTheDialogIsCancelled_answersNull', () async {
      expect(await store.pickAndStore(), isNull);
      expect(picker.calls, 1);
    });

    test(
      'pickAndStore_whenAnImageIsPicked_copiesItIntoTheCoverDirectory',
      () async {
        picker.next = const PickedCoverFile(
          name: 'cover.JPG',
          bytes: <int>[1, 2, 3, 4],
        );

        final String? path = await store.pickAndStore();

        expect(path, isNotNull);
        expect(path, endsWith('.jpg'));
        expect(File(path!).existsSync(), isTrue);
        expect(File(path).readAsBytesSync(), <int>[1, 2, 3, 4]);
        expect(path, contains('covers'));
      },
    );

    test('pickAndStore_whenTheSameImageIsPickedTwice_reusesTheFile', () async {
      picker.next = const PickedCoverFile(name: 'a.png', bytes: <int>[7, 7]);

      final String? first = await store.pickAndStore();
      final String? second = await store.pickAndStore();

      expect(first, second);
      expect(
        Directory('${root.path}${Platform.pathSeparator}covers')
            .listSync()
            .length,
        1,
      );
    });

    test('pickAndStore_whenTheNameHasNoExtension_appendsImg', () async {
      picker.next = const PickedCoverFile(name: 'cover', bytes: <int>[9]);

      expect(await store.pickAndStore(), endsWith('.img'));
    });

    test('pickAndStore_whenTheFileIsTooLarge_refusesItAndWarns', () async {
      picker.next = PickedCoverFile(
        name: 'huge.jpg',
        bytes: List<int>.filled(maxCoverBytes + 1, 0),
      );

      expect(await store.pickAndStore(), isNull);
      expect(printer.events.single.message, contains('larger than the limit'));
    });

    test('delete_whenTheFileExists_removesIt', () async {
      picker.next = const PickedCoverFile(name: 'a.jpg', bytes: <int>[1]);
      final String path = (await store.pickAndStore())!;

      await store.delete(path);

      expect(File(path).existsSync(), isFalse);
    });

    test('delete_whenTheFileIsGone_doesNothing', () async {
      await store.delete('${root.path}${Platform.pathSeparator}missing.jpg');

      expect(printer.events, isEmpty);
    });
  });
}
