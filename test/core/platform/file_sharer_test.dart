import 'dart:typed_data';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:flutter_reader/core/platform/share_plus_file_sharer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

/// A plain [Exception] stand-in (the adapter catches `Exception`, not `Error`).
final class _ShareFailure implements Exception {
  const _ShareFailure();
}

void main() {
  group('UnsupportedFileSharer', () {
    test('share_givenNoShareSheet_answersNotShared', () async {
      const FileSharer sharer = UnsupportedFileSharer();

      expect(sharer.isSupported, isFalse);
      final ParseResult<bool> shared = await sharer.share(<ShareableFile>[
        ShareableFile.inMemory(
          name: 'a.json',
          mimeType: 'application/json',
          bytes: <int>[1],
        ),
      ]);

      expect((shared as ParseSuccess<bool>).data, isFalse);
    });
  });

  group('SharePlusFileSharer', () {
    test('share_givenOnDiskAndInMemoryFiles_handsBothToThePlugin', () async {
      ShareParams? captured;
      final FileSharer sharer = SharePlusFileSharer(
        share: (ShareParams params) async {
          captured = params;

          return const ShareResult('ok', ShareResultStatus.success);
        },
      );

      final ParseResult<bool> shared = await sharer.share(<ShareableFile>[
        const ShareableFile.onDisk(
          name: 'app-2026-10-27.log',
          mimeType: 'text/plain',
          path: '/tmp/app-2026-10-27.log',
        ),
        ShareableFile.inMemory(
          name: 'sources.json',
          mimeType: 'application/json',
          bytes: <int>[123, 125],
        ),
      ], subject: 'Log files');

      expect((shared as ParseSuccess<bool>).data, isTrue);
      final ShareParams params = captured ?? (throw StateError('no params'));
      expect(params.subject, 'Log files');
      expect(params.files, hasLength(2));
      expect(params.fileNameOverrides, <String>[
        'app-2026-10-27.log',
        'sources.json',
      ]);
      expect(params.files?.first.path, '/tmp/app-2026-10-27.log');
      expect(
        await params.files?.elementAt(1).readAsBytes(),
        Uint8List.fromList(<int>[123, 125]),
      );
    });

    test('share_givenTheSheetWasDismissed_answersNotShared', () async {
      final FileSharer sharer = SharePlusFileSharer(
        share: (ShareParams params) async =>
            const ShareResult('', ShareResultStatus.dismissed),
      );

      final ParseResult<bool> shared = await sharer.share(<ShareableFile>[
        ShareableFile.inMemory(
          name: 'a.json',
          mimeType: 'application/json',
          bytes: <int>[1],
        ),
      ]);

      expect((shared as ParseSuccess<bool>).data, isFalse);
    });

    test('share_givenThePlatformCannotReportAResult_answersShared', () async {
      // `unavailable` 只表示结果不可知，分享面板已经出现过（ADR-0083 §决策 3）。
      final FileSharer sharer = SharePlusFileSharer(
        share: (ShareParams params) async => ShareResult.unavailable,
      );

      final ParseResult<bool> shared = await sharer.share(<ShareableFile>[
        ShareableFile.inMemory(
          name: 'a.json',
          mimeType: 'application/json',
          bytes: <int>[1],
        ),
      ]);

      expect((shared as ParseSuccess<bool>).data, isTrue);
    });

    test('share_givenThePluginThrows_answersTheShareMarker', () async {
      bool called = false;
      final FileSharer sharer = SharePlusFileSharer(
        share: (ShareParams params) async {
          called = true;

          throw const _ShareFailure();
        },
      );

      final ParseResult<bool> shared = await sharer.share(<ShareableFile>[
        ShareableFile.inMemory(
          name: 'a.json',
          mimeType: 'application/json',
          bytes: <int>[1],
        ),
      ]);

      expect(called, isTrue);
      expect(shared, isA<ParseFailure<bool>>());
      expect((shared as ParseFailure<bool>).rulePath, 'share');
    });

    test(
      'share_givenNoFiles_answersNotSharedWithoutCallingThePlugin',
      () async {
        bool called = false;
        final FileSharer sharer = SharePlusFileSharer(
          share: (ShareParams params) async {
            called = true;

            return const ShareResult('ok', ShareResultStatus.success);
          },
        );

        final ParseResult<bool> shared = await sharer.share(
          const <ShareableFile>[],
        );

        expect(called, isFalse);
        expect((shared as ParseSuccess<bool>).data, isFalse);
      },
    );
  });
}
