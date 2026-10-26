import 'dart:convert';

import 'dart:io';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/export_book_sources.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_book_source_repository.dart';

/// One valid book source from the offline corpus, renamed so a test can tell two apart.
Map<String, Object?> _source(String name, String url) {
  final Map<String, Object?> fixture = jsonDecode(
    File('test/fixtures/book_sources/legado_default_rules_source.json')
        .readAsStringSync(),
  ) as Map<String, Object?>;

  return <String, Object?>{
    ...fixture,
    'bookSourceName': name,
    'bookSourceUrl': url,
  };
}

/// The decoded document of a successful export.
List<Object?> _decode(ParseResult<BookSourceExport> export) => switch (export) {
  ParseSuccess<BookSourceExport>(:final BookSourceExport data) =>
    jsonDecode(data.contents) as List<Object?>,
  ParseFailure<BookSourceExport>(:final ParseFailureKind kind) => fail(
    'the export should succeed ($kind)',
  ),
};

void main() {
  group('ExportBookSources', () {
    test('execute_givenStoredSources_writesThemAsOneArray', () async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      await repository.saveAll(<Map<String, Object?>>[
        _source('甲', 'https://a.test'),
        _source('乙', 'https://b.test'),
      ]);

      final ParseResult<BookSourceExport> export = await ExportBookSources(
        repository: repository,
      ).execute();

      final BookSourceExport document =
          (export as ParseSuccess<BookSourceExport>).data;
      expect(document.count, 2);
      expect(document.fileName, 'bookSources-2.json');
      expect(
        _decode(export).map(
          (Object? entry) => (entry! as Map<String, Object?>)['bookSourceName'],
        ),
        <String>['甲', '乙'],
      );
    });

    test('execute_givenIds_exportsOnlyThoseSources', () async {
      final FakeBookSourceRepository repository = FakeBookSourceRepository();
      await repository.saveAll(<Map<String, Object?>>[
        _source('甲', 'https://a.test'),
        _source('乙', 'https://b.test'),
      ]);
      final int chosen = (await repository.getAll()).last.id;

      final ParseResult<BookSourceExport> export = await ExportBookSources(
        repository: repository,
      ).execute(ids: <int>{chosen});

      expect(
        _decode(export).map(
          (Object? entry) => (entry! as Map<String, Object?>)['bookSourceName'],
        ),
        <String>['乙'],
      );
    });

    test(
      'execute_givenNoStoredSource_failsInsteadOfWritingAnEmptyFile',
      () async {
        final ParseResult<BookSourceExport> export = await ExportBookSources(
          repository: FakeBookSourceRepository(),
        ).execute();

        expect(
          export,
          isA<ParseFailure<BookSourceExport>>().having(
            (ParseFailure<BookSourceExport> failure) => failure.rulePath,
            'rulePath',
            'bookSource.export.empty',
          ),
        );
      },
    );
  });
}
