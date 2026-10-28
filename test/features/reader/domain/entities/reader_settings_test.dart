import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('typography presets', () {
    test('ReaderSettings_givenAnOffStepSpacing_snapsToTheNearestStep', () {
      // 段距与缩进只有预设台阶（ADR-0051 §决策 4）：读回来的永远是 UI 能表示的取值。
      final ReaderSettings settings = ReaderSettings(
        paragraphSpacing: 0.7,
        firstLineIndent: 1.4,
      );

      expect(settings.paragraphSpacing, 0.5);
      expect(settings.firstLineIndent, 1);
    });

    test('ReaderSettings_givenNegativePresets_snapToZero', () {
      final ReaderSettings settings = ReaderSettings(
        paragraphSpacing: -1,
        firstLineIndent: -3,
      );

      expect(settings.paragraphSpacing, 0);
      expect(settings.firstLineIndent, 0);
    });

    test('readerPagePaddingOf_whenAsked_answersThePresetPixels', () {
      expect(readerPagePaddingOf(ReaderPagePadding.narrow), 16);
      expect(readerPagePaddingOf(ReaderPagePadding.medium), 24);
      expect(readerPagePaddingOf(ReaderPagePadding.wide), 32);
    });

    test('readerFontFamilyName_whenAsked_answersThePlatformFamily', () {
      expect(readerFontFamilyName(ReaderFontFamily.theme), isNull);
      expect(readerFontFamilyName(ReaderFontFamily.serif), 'serif');
      expect(readerFontFamilyName(ReaderFontFamily.sans), 'sans-serif');
      expect(readerFontFamilyName(ReaderFontFamily.mono), 'monospace');
    });
  });

  group('ReaderSettings', () {
    test('ReaderSettings_whenDefault_isReadableAndScrolls', () {
      const ReaderSettings settings = ReaderSettings.defaults;

      expect(settings.fontScale, defaultReaderFontScale);
      expect(settings.lineHeight, defaultReaderLineHeight);
      expect(settings.brightness, defaultReaderBrightness);
      expect(settings.background, ReaderBackground.system);
      expect(settings.pageMode, ReaderPageMode.scroll);
    });

    test('ReaderSettings_whenDefault_hasNormalSpeechAxes', () {
      const ReaderSettings settings = ReaderSettings.defaults;

      expect(settings.ttsRate, 1);
      expect(settings.ttsPitch, 1);
      expect(settings.ttsVoiceName, isNull);
      expect(settings.ttsVoiceLocale, isNull);
      expect(settings.stopTtsOnExit, isTrue);
    });

    test('ReaderSettings_givenOutOfRangeSpeechAxes_clampsThem', () {
      final ReaderSettings high = ReaderSettings(ttsRate: 9, ttsPitch: 9);
      final ReaderSettings low = ReaderSettings(ttsRate: 0.1, ttsPitch: 0.1);

      expect(high.ttsRate, maxTtsRate);
      expect(high.ttsPitch, maxTtsPitch);
      expect(low.ttsRate, minTtsRate);
      expect(low.ttsPitch, minTtsPitch);
    });

    test('ReaderSettings_givenOutOfRangeBrightness_clampsIt', () {
      expect(ReaderSettings(brightness: 0).brightness, minReaderBrightness);
      expect(ReaderSettings(brightness: 2).brightness, maxReaderBrightness);
    });

    test('copyWith_givenABrightness_keepsTheOtherAxes', () {
      final ReaderSettings dimmed = ReaderSettings.defaults.copyWith(
        brightness: 0.6,
      );

      expect(dimmed.brightness, 0.6);
      expect(dimmed.fontScale, ReaderSettings.defaults.fontScale);
      expect(dimmed.background, ReaderSettings.defaults.background);
    });

    test('copyWith_givenClearTtsVoice_dropsTheStoredVoice', () {
      final ReaderSettings withVoice = ReaderSettings(
        ttsVoiceName: 'Microsoft Huihui',
        ttsVoiceLocale: 'zh-CN',
      );

      final ReaderSettings cleared = withVoice.copyWith(clearTtsVoice: true);

      expect(cleared.ttsVoiceName, isNull);
      expect(cleared.ttsVoiceLocale, isNull);
    });

    test('ReaderSettings_whenOnlyTtsAxesDiffer_areNotEqual', () {
      expect(
        ReaderSettings.defaults,
        isNot(ReaderSettings.defaults.copyWith(ttsRate: 1.5)),
      );
      expect(
        ReaderSettings.defaults,
        isNot(ReaderSettings.defaults.copyWith(stopTtsOnExit: false)),
      );
    });

    test('ReaderSettings_defaults_keepTheDisplayOnAndTheStatusLineVisible', () {
      // 默认：常亮开、护眼关、状态栏开（ADR-0086 §决策 1/2/6）。
      expect(ReaderSettings.defaults.keepScreenAwake, isTrue);
      expect(ReaderSettings.defaults.eyeProtection, 0);
      expect(ReaderSettings.defaults.showReaderStatus, isTrue);
    });

    test('ReaderSettings_givenAnOutOfRangeEyeProtection_clampsIt', () {
      expect(ReaderSettings(eyeProtection: 400).eyeProtection, 100);
      expect(ReaderSettings(eyeProtection: -20).eyeProtection, 0);
    });

    test('ReaderSettings_whenOnlyTheStatusAxesDiffer_areNotEqual', () {
      expect(
        ReaderSettings.defaults,
        isNot(ReaderSettings.defaults.copyWith(keepScreenAwake: false)),
      );
      expect(
        ReaderSettings.defaults,
        isNot(ReaderSettings.defaults.copyWith(eyeProtection: 40)),
      );
      expect(
        ReaderSettings.defaults,
        isNot(ReaderSettings.defaults.copyWith(showReaderStatus: false)),
      );
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
  });
}
