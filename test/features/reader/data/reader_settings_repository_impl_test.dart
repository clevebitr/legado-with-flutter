import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/features/reader/data/reader_settings_repository_impl.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds the repository on a mocked `shared_preferences` store.
Future<ReaderSettingsRepositoryImpl> _repository([
  Map<String, Object> values = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(values);

  return ReaderSettingsRepositoryImpl(
    store: PreferenceStore(await SharedPreferences.getInstance()),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderSettingsRepositoryImpl', () {
    test('load_givenNothingStored_answersTheDefaults', () async {
      expect(await (await _repository()).load(), ReaderSettings.defaults);
    });

    test('save_thenLoad_roundTripsEveryAxis', () async {
      final ReaderSettingsRepositoryImpl repository = await _repository();
      final ReaderSettings settings = ReaderSettings(
        fontScale: 1.4,
        lineHeight: 2,
        brightness: 0.6,
        background: ReaderBackground.sepia,
        pageMode: ReaderPageMode.paged,
        keepScreenAwake: false,
        eyeProtection: 40,
        showReaderStatus: false,
      );

      await repository.save(settings);

      expect(await repository.load(), settings);
    });

    test('save_thenLoad_roundTripsTheSpeechAxes', () async {
      final ReaderSettingsRepositoryImpl repository = await _repository();
      final ReaderSettings settings = ReaderSettings(
        ttsRate: 1.5,
        ttsPitch: 0.75,
        ttsVoiceName: 'Microsoft Huihui',
        ttsVoiceLocale: 'zh-CN',
        stopTtsOnExit: false,
      );

      await repository.save(settings);

      final ReaderSettings loaded = await repository.load();
      expect(loaded.ttsRate, 1.5);
      expect(loaded.ttsPitch, 0.75);
      expect(loaded.ttsVoiceName, 'Microsoft Huihui');
      expect(loaded.ttsVoiceLocale, 'zh-CN');
      expect(loaded.stopTtsOnExit, isFalse);
    });

    test('save_givenNoVoice_storesTheSystemDefaultAsNull', () async {
      // 「系统默认」= 没选：存空串，读回来仍是 null（PreferenceStore 没有删除）。
      final ReaderSettingsRepositoryImpl repository = await _repository();
      await repository.save(ReaderSettings.defaults);

      final ReaderSettings loaded = await repository.load();

      expect(loaded.ttsVoiceName, isNull);
      expect(loaded.ttsVoiceLocale, isNull);
    });

    test('load_givenOutOfRangeValues_clampsThem', () async {
      // 手改过的存储不能让正文变得不可读：钳制在实体工厂里，读回来就是 UI 能表示的范围。
      final ReaderSettingsRepositoryImpl repository = await _repository(
        <String, Object>{'reader.fontScale': 9.0, 'reader.lineHeight': 0.1},
      );

      final ReaderSettings settings = await repository.load();

      expect(settings.fontScale, maxReaderFontScale);
      expect(settings.lineHeight, minReaderLineHeight);
    });

    test('load_givenAnOutOfRangeBrightness_clampsIt', () async {
      final ReaderSettingsRepositoryImpl repository = await _repository(
        <String, Object>{'reader.brightness': 0.1},
      );

      expect((await repository.load()).brightness, minReaderBrightness);
    });

    test('load_givenAnUnknownEnumIndex_fallsBackToTheDefault', () async {
      // 新版写入的索引 / 手改的越界值：不索引越界（那会是 RangeError，越过 ParseResult 契约）。
      final ReaderSettingsRepositoryImpl repository = await _repository(
        <String, Object>{'reader.background': 7, 'reader.pageMode': -1},
      );

      final ReaderSettings settings = await repository.load();

      expect(settings.background, ReaderBackground.system);
      expect(settings.pageMode, ReaderPageMode.scroll);
    });

    test('load_givenAValueOfAnotherType_fallsBackToTheDefault', () async {
      final ReaderSettingsRepositoryImpl repository = await _repository(
        <String, Object>{
          'reader.fontScale': 'big',
          'reader.background': 'sepia',
        },
      );

      final ReaderSettings settings = await repository.load();

      expect(settings.fontScale, defaultReaderFontScale);
      expect(settings.background, ReaderBackground.system);
    });
  });
}
