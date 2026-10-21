import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderSettings', () {
    test('ReaderSettings_whenDefault_isReadableAndScrolls', () {
      const ReaderSettings settings = ReaderSettings.defaults;

      expect(settings.fontScale, defaultReaderFontScale);
      expect(settings.lineHeight, defaultReaderLineHeight);
      expect(settings.background, ReaderBackground.system);
      expect(settings.pageMode, ReaderPageMode.scroll);
    });

    test('ReaderSettings_givenOutOfRangeNumbers_clampsThem', () {
      // 工厂钳制而不是断言：release 会剥掉 assert，手改的存储不能让正文不可读。
      final ReaderSettings high = ReaderSettings(fontScale: 5, lineHeight: 9);
      final ReaderSettings low = ReaderSettings(
        fontScale: 0.1,
        lineHeight: 0.2,
      );

      expect(high.fontScale, maxReaderFontScale);
      expect(high.lineHeight, maxReaderLineHeight);
      expect(low.fontScale, minReaderFontScale);
      expect(low.lineHeight, minReaderLineHeight);
    });

    test('copyWith_givenNewValues_replacesOnlyThem', () {
      const ReaderSettings settings = ReaderSettings.defaults;

      final ReaderSettings updated = settings.copyWith(
        background: ReaderBackground.dark,
        pageMode: ReaderPageMode.paged,
      );

      expect(updated.background, ReaderBackground.dark);
      expect(updated.pageMode, ReaderPageMode.paged);
      expect(updated.fontScale, settings.fontScale);
      expect(updated.lineHeight, settings.lineHeight);
    });

    test('copyWith_givenNothing_keepsEveryValue', () {
      const ReaderSettings settings = ReaderSettings.defaults;

      expect(settings.copyWith(), settings);
    });

    test('equality_givenTheSameValues_isEqual', () {
      final ReaderSettings left = ReaderSettings(fontScale: 1.2);
      final ReaderSettings right = ReaderSettings(fontScale: 1.2);

      expect(left, right);
      expect(left.hashCode, right.hashCode);
      expect(left == left.copyWith(pageMode: ReaderPageMode.paged), isFalse);
      expect(left == Object(), isFalse);
    });
  });
}
