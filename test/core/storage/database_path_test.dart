import 'dart:io';

import 'package:flutter_reader/core/storage/database_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('databasePathIn', () {
    test('databasePathIn_whenGivenADirectory_placesReaderDbInsideIt', () {
      final Directory directory = Directory.systemTemp.createTempSync(
        'reader_path_test',
      );
      addTearDown(() => directory.deleteSync(recursive: true));

      final String path = databasePathIn(directory);

      expect(File(path).parent.path, directory.path);
      expect(path, endsWith(databaseFileName));
      expect(databaseFileName, 'reader.db');
    });
  });
}
