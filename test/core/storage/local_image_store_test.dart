import 'dart:io';

import 'package:flutter_reader/core/storage/local_image_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory support;
  late LocalImageStore store;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('image_store_test');
    store = LocalImageStore(supportDirectory: () async => support);
  });

  tearDown(() => support.delete(recursive: true));

  test('save_givenBytes_writesThemAndAnswersTheName', () async {
    final String name = await store.save(
      folder: 'backgrounds',
      name: 'background.png',
      bytes: <int>[1, 2, 3],
    );

    expect(name, 'background.png');
    expect(
      File('${support.path}/backgrounds/background.png').existsSync(),
      isTrue,
    );
  });

  test('pathOf_givenAStoredImage_answersItsPath', () async {
    final String name = await store.save(
      folder: 'backgrounds',
      name: 'background.jpg',
      bytes: <int>[1],
    );

    expect(
      await store.pathOf(folder: 'backgrounds', name: name),
      '${support.path}/backgrounds/background.jpg'.replaceAll(
        '/',
        Platform.pathSeparator,
      ),
    );
  });

  test('pathOf_givenAMissingImage_answersNull', () async {
    // 备份恢复到新设备、或用户自己删了文件：调用方回落到纯色背景，不崩。
    expect(await store.pathOf(folder: 'backgrounds', name: 'gone.png'), isNull);
  });

  test('delete_givenAFile_removesIt', () async {
    final String name = await store.save(
      folder: 'backgrounds',
      name: 'background.png',
      bytes: <int>[1],
    );

    await store.delete(folder: 'backgrounds', name: name);

    expect(await store.pathOf(folder: 'backgrounds', name: name), isNull);
  });

  test('imageFileName_givenAnUnsafeName_keepsOnlySafeCharacters', () {
    // 名字来自文件对话框：路径分隔符不能穿越到目录之外。
    expect(imageFileName('../evil/name.png'), 'evil_name.png');
    expect(imageFileName('my cover.JPG'), 'my_cover.jpg');
    expect(imageFileName('.png'), 'image.png');
  });

  test('imageExtensionOf_givenANonWhitelistedSuffix_dropsIt', () {
    expect(imageExtensionOf('a.exe'), '');
    expect(imageExtensionOf('a.webp'), '.webp');
    expect(imageExtensionOf('noextension'), '');
  });
}
