import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_candidate.dart';
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShelfCandidate', () {
    test('new_givenBothIdentityParts_isAccepted', () {
      final ShelfCandidate candidate = ShelfCandidate(
        sourceUrl: 'https://source.test',
        bookUrl: 'https://source.test/book/1',
        name: '剑来',
      );

      expect(candidate.name, '剑来');
      expect(candidate.author, isNull);
    });

    test('new_givenAnEmptySourceUrl_throws', () {
      // 身份由 (sourceUrl, bookUrl) 组成，空的 identity 是编程错误而不是可恢复失败（C-ERR-1）。
      expect(
        () => ShelfCandidate(sourceUrl: '', bookUrl: 'b', name: 'n'),
        throwsArgumentError,
      );
    });

    test('new_givenAnEmptyBookUrl_throws', () {
      expect(
        () => ShelfCandidate(sourceUrl: 's', bookUrl: '', name: 'n'),
        throwsArgumentError,
      );
    });
  });

  group('ShelfStatus', () {
    test('fromStorage_givenOne_answersRead', () {
      expect(ShelfStatus.fromStorage(1), ShelfStatus.read);
    });

    test('fromStorage_givenAnUnknownValue_answersTracking', () {
      // 更高版本写进来的值不能让书架消失；「在追」是安全方向。
      expect(ShelfStatus.fromStorage(7), ShelfStatus.tracking);
    });

    test('storageValue_whenRead_roundTripsThroughFromStorage', () {
      for (final ShelfStatus status in ShelfStatus.values) {
        expect(ShelfStatus.fromStorage(status.storageValue), status);
      }
    });
  });
}
