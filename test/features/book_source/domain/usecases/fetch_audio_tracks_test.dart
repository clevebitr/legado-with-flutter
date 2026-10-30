import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_variables.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/features/book_source/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/chapter_request.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/fetch_audio_tracks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_http_client.dart';
import '../../../../support/fake_js_bridge.dart';
import '../../../../support/fake_log_printer.dart';

/// The chapter every case reads.
const String _chapterUrl = 'https://audio.test/chapter/1';

/// Builds an audio book source whose content rule is [content] (ADR-0054 §决策 2).
BookSource _source({String content = r'$.data.urls', String? next}) =>
    BookSource.fromLegadoJson(<String, Object?>{
      'bookSourceName': '音频源',
      'bookSourceUrl': 'https://audio.test',
      'bookSourceType': 1,
      'header': '{"User-Agent":"fixture"}',
      'ruleSearch': <String, Object?>{},
      'ruleToc': <String, Object?>{},
      'ruleContent': <String, Object?>{
        'content': content,
        'nextContentUrl': ?next,
      },
    });

/// Builds the page service under test.
PageFetchService _service(FakeHttpClient http, [FakeJsBridge? bridge]) {
  final AppLogger logger = AppLogger(
    level: LogLevel.debug,
    printer: FakeLogPrinter(),
  );

  return PageFetchService(
    engine: RuleEngine(
      logger: logger,
      jsBridge: bridge ?? FakeJsBridge(),
      variables: JsVariableStore(),
    ),
    http: http,
    logger: logger,
  );
}

/// Returns the failure of [result], failing the test when it succeeded.
ParseFailure<Never> _failure<T>(ParseResult<T> result) => switch (result) {
  ParseFailure<T>(:final ParseFailureKind kind, :final String rulePath) =>
    ParseFailure<Never>(kind: kind, rulePath: rulePath),
  ParseSuccess<T>() => fail('Expected a failure.'),
};

/// Returns the data of [result], failing the test when it failed.
T _data<T>(ParseResult<T> result) => switch (result) {
  ParseSuccess<T>(:final T data) => data,
  ParseFailure<T>(:final ParseFailureKind kind) => fail(
    'Expected a success but got $kind.',
  ),
};

void main() {
  group('FetchAudioTracks', () {
    test(
      'execute_givenAnHtmlPageAsTheValue_failsInsteadOfFakingAUrl',
      () async {
        // webView 源的 content 规则可能把整页 HTML 当结果：不能拼成假 URL 交给播放器。
        final FakeHttpClient http = FakeHttpClient()
          ..serve(
            _chapterUrl,
            '{"data":{"urls":["<!DOCTYPE html><html><body>no media</body></html>"]}}',
          );

        final ParseFailure<Never> failure = _failure(
          await FetchAudioTracks(pages: _service(http))
              .execute(_source(), const ChapterRequest(url: _chapterUrl)),
        );

        expect(failure.kind, ParseFailureKind.parseFailed);
        expect(failure.rulePath, 'contentRule.content');
      },
    );

    test('execute_givenAChapterUrlWithOptions_requestsTheCleanUrl', () async {
      // 与正文同一口径：章节地址的 `,{webView:…}` 在取页时切掉，不进入请求路径。
      const String withOptions =
          'https://audio.test/chapter/1,{webView:“true”}';
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '{"data":{"urls":["https://cdn.test/a.mp3"]}}');

      final List<AudioTrack> tracks = _data(
        await FetchAudioTracks(pages: _service(http))
            .execute(_source(), const ChapterRequest(url: withOptions)),
      );

      expect(tracks.single.url, 'https://cdn.test/a.mp3');
      expect(http.requestedUrls, <String>[_chapterUrl]);
    });

    test('execute_givenAListRule_returnsOneTrackPerHttpValue', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '{"data":{"urls":["https://cdn.test/a.mp3","/b.mp3",'
          '"ftp://cdn.test/c.mp3","https://cdn.test/a.mp3",""]}}',
        );

      final List<AudioTrack> tracks = _data(
        await FetchAudioTracks(pages: _service(http))
            .execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      // 一项 = 一轨；相对地址按章节页解析；非 http(s) 与空值丢弃；重复地址只留一次。
      expect(tracks.map((AudioTrack track) => track.url), <String>[
        'https://cdn.test/a.mp3',
        'https://audio.test/b.mp3',
      ]);
      expect(tracks.first.headers, <String, String>{'User-Agent': 'fixture'});
      expect(http.requestedRulePaths, <String>['ruleContent']);
    });

    test('execute_givenASingleAddressRule_returnsOneTrack', () async {
      // 真实听书源的形状：`RuleContent.content = $.data.SeriesUrl`，值是单个字符串。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '{"data":{"SeriesUrl":"https://cdn.test/a.m4a?sign=abc"}}',
        );

      final List<AudioTrack> tracks = _data(
        await FetchAudioTracks(pages: _service(http)).execute(
          _source(content: r'$.data.SeriesUrl'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(tracks.single.url, 'https://cdn.test/a.m4a?sign=abc');
    });

    test('execute_givenAnItemScript_keepsThePagesBaseUrl', () async {
      // JSON 条目上的 `@js:` 字段必须看得到**页面**的 baseUrl（ADR-0049 的上下文传播）：
      // 真实听书源用它拼章节地址，丢掉它会让 `id=` 变空（M17 真源抽查发现）。
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '{"data":{"series":[{"id":"7"}]}}');
      final FakeJsBridge bridge = FakeJsBridge()
        ..result = 'https://audio.test/media/7.mp3';

      final List<AudioTrack> tracks = _data(
        await FetchAudioTracks(pages: _service(http, bridge)).execute(
          _source(content: r'@js:baseUrl + "/media/7.mp3"'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(tracks.single.url, 'https://audio.test/media/7.mp3');
      expect(bridge.jobs.single.baseUrl, _chapterUrl);
    });

    test('execute_givenAnEmptyList_failsTheChapter', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '{"data":{"urls":[]}}');

      final ParseFailure<Never> failure = _failure(
        await FetchAudioTracks(pages: _service(http))
            .execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      // 空播放器比失败更糟：用户分不清「静音」和「规则失效」（C-SRC-4）。
      expect(failure.kind, ParseFailureKind.parseFailed);
      expect(failure.rulePath, 'contentRule.content');
    });

    test('execute_givenOnlyNonHttpValues_failsTheChapter', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '{"data":{"urls":["magnet:?xt=urn:btih:1","file:///tmp/a.mp3"]}}',
        );

      final ParseFailure<Never> failure = _failure(
        await FetchAudioTracks(pages: _service(http))
            .execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      expect(failure.kind, ParseFailureKind.parseFailed);
    });

    test('execute_givenAPagingRule_keepsTheTracksOfEveryPage', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '{"data":{"urls":["https://cdn.test/a.mp3"]},'
          '"next":"https://audio.test/chapter/2"}',
        )
        ..serve(
          'https://audio.test/chapter/2',
          '{"data":{"urls":["https://cdn.test/b.mp3"]},"next":""}',
        );

      final List<AudioTrack> tracks = _data(
        await FetchAudioTracks(pages: _service(http)).execute(
          _source(next: r'$.next'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(tracks.map((AudioTrack track) => track.url), <String>[
        'https://cdn.test/a.mp3',
        'https://cdn.test/b.mp3',
      ]);
      expect(http.requestedUrls, <String>[
        _chapterUrl,
        'https://audio.test/chapter/2',
      ]);
    });

    test('execute_givenALaterPagingPageThatFails_failsTheChapter', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(
          _chapterUrl,
          '{"data":{"urls":["https://cdn.test/a.mp3"]},'
          '"next":"https://audio.test/chapter/2"}',
        )
        ..failWith(
          'https://audio.test/chapter/2',
          ParseFailureKind.networkFailed,
        );

      final ParseFailure<Never> failure = _failure(
        await FetchAudioTracks(pages: _service(http)).execute(
          _source(next: r'$.next'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      // 只播第一段不是「可用的章节」，与正文缺页同一条口径（book-source.md §9）。
      expect(failure.kind, ParseFailureKind.networkFailed);
    });

    test('execute_givenAnUnsupportedRule_propagatesTheRejection', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..serve(_chapterUrl, '{"data":{"urls":[]}}');

      final ParseFailure<Never> failure = _failure(
        await FetchAudioTracks(pages: _service(http)).execute(
          _source(content: '@webJs:'),
          const ChapterRequest(url: _chapterUrl),
        ),
      );

      expect(failure.kind, ParseFailureKind.unsupportedRule);
    });

    test('execute_givenAChapterPageThatFails_failsTheChapter', () async {
      final FakeHttpClient http = FakeHttpClient()
        ..failWith(_chapterUrl, ParseFailureKind.notFound);

      final ParseFailure<Never> failure = _failure(
        await FetchAudioTracks(pages: _service(http))
            .execute(_source(), const ChapterRequest(url: _chapterUrl)),
      );

      expect(failure.kind, ParseFailureKind.notFound);
      expect(failure.rulePath, 'ruleContent');
    });
  });
}
