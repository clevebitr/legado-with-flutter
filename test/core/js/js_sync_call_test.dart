import 'package:flutter_reader/core/js/js_sync_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeJsSyncRequest', () {
    test('decodeJsSyncRequest_givenEachVerb_decodesIt', () {
      // 每个动词都是沙箱里的一个拼写，漏一个就会退回「没有这个函数」。
      const Map<String, JsSyncOperation> cases = <String, JsSyncOperation>{
        'ajax': JsSyncOperation.ajax,
        'post': JsSyncOperation.post,
        'head': JsSyncOperation.head,
        'connect': JsSyncOperation.connect,
        'getCookie': JsSyncOperation.getCookie,
        'cookieGet': JsSyncOperation.cookieGet,
        'cookieSet': JsSyncOperation.cookieSet,
        'cookieRemove': JsSyncOperation.cookieRemove,
      };

      for (final MapEntry<String, JsSyncOperation> entry in cases.entries) {
        final JsSyncRequest? request = decodeJsSyncRequest(<String, Object?>{
          'operation': entry.key,
          'url': 'https://a.test/page',
        });

        expect(request?.operation, entry.value, reason: entry.key);
        expect(request?.url, 'https://a.test/page');
        expect(request?.headers, isEmpty);
      }
    });

    test('decodeJsSyncRequest_givenAnAjaxAll_keepsTheAddressList', () {
      // M25/S3b：`java.ajaxAll(urlList)` 带的是列表而不是单个地址。
      final JsSyncRequest? request = decodeJsSyncRequest(<String, Object?>{
        'operation': 'ajaxAll',
        'urls': <Object?>['https://a.test/1', 'https://a.test/2'],
      });

      expect(request?.operation, JsSyncOperation.ajaxAll);
      expect(request?.urls, <String>['https://a.test/1', 'https://a.test/2']);
      expect(request?.url, isEmpty);
    });

    test('decodeJsSyncRequest_givenAnAjaxAllWithoutAddresses_isNull', () {
      // 空列表取不到任何页面，拼错了就明确拒绝，而不是答一个空数组。
      expect(
        decodeJsSyncRequest(<String, Object?>{
          'operation': 'ajaxAll',
          'urls': const <Object?>[],
        }),
        isNull,
      );
      expect(
        decodeJsSyncRequest(<String, Object?>{
          'operation': 'ajaxAll',
          'urls': const <Object?>['https://a.test/1', 7],
        }),
        isNull,
      );
    });

    test('decodeJsSyncRequest_givenAPost_keepsBodyAndHeaders', () {
      final JsSyncRequest? request = decodeJsSyncRequest(<String, Object?>{
        'operation': 'post',
        'url': 'https://a.test/sscc/',
        'body': 'keyword=x',
        'headers': <String, Object?>{'Referer': 'https://a.test/'},
      });

      expect(request?.body, 'keyword=x');
      expect(request?.headers, <String, String>{'Referer': 'https://a.test/'});
    });

    test('decodeJsSyncRequest_givenUnusableArguments_answersNull', () {
      // 畸形信封一律拒绝：猜一个动词等于让规则读到错页（C-SRC-4）。
      const List<Object?> malformed = <Object?>[
        null,
        'ajax',
        <String, Object?>{},
        <String, Object?>{'operation': 'fetch', 'url': 'https://a.test'},
        <String, Object?>{'operation': 'ajax'},
        <String, Object?>{'operation': 'ajax', 'url': ''},
        <String, Object?>{'operation': 'ajax', 'url': 7},
        <String, Object?>{
          'operation': 'ajax',
          'url': 'https://a.test',
          'body': 1,
        },
        <String, Object?>{
          'operation': 'ajax',
          'url': 'https://a.test',
          'key': 1,
        },
        <String, Object?>{
          'operation': 'ajax',
          'url': 'https://a.test',
          'headers': <String, Object?>{'a': 1},
        },
        <String, Object?>{
          'operation': 'ajax',
          'url': 'https://a.test',
          'headers': 'a=1',
        },
        // 只有 post 有 body：其余动词带 body 说明信封拼错了。
        <String, Object?>{
          'operation': 'ajax',
          'url': 'https://a.test',
          'body': 'x',
        },
      ];

      for (final Object? args in malformed) {
        expect(decodeJsSyncRequest(args), isNull, reason: '$args');
      }
    });

    test('decodeJsSyncRequest_givenAKeyedCall_keepsTheCookieName', () {
      final JsSyncRequest? request = decodeJsSyncRequest(<String, Object?>{
        'operation': 'cookieGet',
        'url': 'https://a.test/',
        'key': 'g3jy9sqo0ws',
      });

      expect(request?.key, 'g3jy9sqo0ws');
      expect(request?.toJson(), <String, Object?>{
        'operation': 'cookieGet',
        'url': 'https://a.test/',
        'body': null,
        'headers': const <String, String>{},
        'key': 'g3jy9sqo0ws',
        'urls': const <String>[],
      });
    });
  });

  group('JsSyncRequest.cacheKey', () {
    test('cacheKey_givenTheSameCall_answersTheSameKey', () {
      // 同一次调用在下一趟必须命中同一条缓存，否则重放永远追不上。
      final JsSyncRequest first = _request();
      final JsSyncRequest second = _request();

      expect(first.cacheKey, second.cacheKey);
    });

    test('cacheKey_givenADifferentBodyOrCookieName_differs', () {
      final String base = _request().cacheKey;

      expect(_request(body: 'keyword=b').cacheKey, isNot(base));
      expect(_request(key: 'token').cacheKey, isNot(base));
      expect(_request(operation: JsSyncOperation.head).cacheKey, isNot(base));
      // 空 body 与「没有 body」是同一次调用：信封里两者都写成 null / ''。
      expect(_request(body: '').cacheKey, base);
    });

    test('cacheKey_givenDifferentAjaxAllLists_differs', () {
      // 一次 `ajaxAll` 是一个整体答案，所以缓存键必须带整张表。
      const JsSyncRequest one = JsSyncRequest(
        operation: JsSyncOperation.ajaxAll,
        url: '',
        urls: <String>['https://a.test/1', 'https://a.test/2'],
      );
      const JsSyncRequest two = JsSyncRequest(
        operation: JsSyncOperation.ajaxAll,
        url: '',
        urls: <String>['https://a.test/1'],
      );

      expect(one.cacheKey, isNot(two.cacheKey));
      expect(one.cacheKey, one.cacheKey);
    });

    test('cacheKey_givenTwoUrlsThatOnlyDifferInSeparatorPosition_differs', () {
      // 分隔符是 NUL，URL 里不会出现，所以拼接不会让两次不同的调用撞成一条。
      final JsSyncRequest first = decodeJsSyncRequest(<String, Object?>{
        'operation': 'post',
        'url': 'https://a.test/a',
        'body': null,
        'key': 'b',
      })!;
      final JsSyncRequest second = decodeJsSyncRequest(<String, Object?>{
        'operation': 'post',
        'url': 'https://a.test/a',
        'body': 'b',
        'key': '',
      })!;

      expect(first.cacheKey, isNot(second.cacheKey));
    });
  });

  group('JsSyncCache', () {
    test('JsSyncCache_givenAFreshCache_answersNothing', () {
      expect(JsSyncCache().lookup(_request()), isNull);
    });

    test('JsSyncCache_givenAStoredValue_answersItOnTheNextPass', () {
      final JsSyncCache cache = JsSyncCache();
      cache.store(_request(), const JsSyncEntry.value('<html>'));

      final JsSyncEntry? entry = cache.lookup(_request());

      expect(entry?.isSuccess, isTrue);
      expect(entry?.value, '<html>');
      expect(entry?.toEnvelope(), <String, Object?>{
        'ok': true,
        'value': '<html>',
      });
    });

    test('JsSyncCache_givenAStoredFailure_answersTheEnvelopeTheRuleThrows', () {
      final JsSyncCache cache = JsSyncCache();
      cache.store(_request(), const JsSyncEntry.failure('networkFailed'));

      final JsSyncEntry? entry = cache.lookup(_request());

      expect(entry?.isSuccess, isFalse);
      expect(entry?.value, isNull);
      expect(entry?.toEnvelope(), <String, Object?>{
        'ok': false,
        'message': 'networkFailed',
      });
    });

    test('JsSyncCache_givenMoreCallsThanItRemembers_dropsTheOldest', () {
      final JsSyncCache cache = JsSyncCache(maxEntries: 2);
      final JsSyncRequest first = _request(url: 'https://a.test/1');
      final JsSyncRequest second = _request(url: 'https://a.test/2');
      final JsSyncRequest third = _request(url: 'https://a.test/3');
      cache.store(first, const JsSyncEntry.value('1'));
      cache.store(second, const JsSyncEntry.value('2'));
      cache.store(third, const JsSyncEntry.value('3'));

      expect(cache.length, 2);
      expect(cache.lookup(first), isNull);
      expect(cache.lookup(second)?.value, '2');
      expect(cache.lookup(third)?.value, '3');
    });

    test('JsSyncCache_givenARepeatedStore_countsOnce', () {
      final JsSyncCache cache = JsSyncCache(maxEntries: 1);
      cache.store(_request(), const JsSyncEntry.value('a'));
      cache.store(_request(), const JsSyncEntry.value('b'));

      expect(cache.length, 1);
      expect(cache.lookup(_request())?.value, 'b');
    });

    test('JsSyncCache_givenClear_forgetsEveryAnswer', () {
      final JsSyncCache cache = JsSyncCache();
      cache.store(_request(), const JsSyncEntry.value('a'));
      cache.clear();

      expect(cache.length, 0);
      expect(cache.lookup(_request()), isNull);
    });
  });

  group('cookieValueOf', () {
    test('cookieValueOf_givenTheHeader_answersTheNamedCookie', () {
      expect(cookieValueOf('a=1; b=2', 'b'), '2');
      expect(cookieValueOf('a=1;b=2', 'b'), '2');
      expect(cookieValueOf('a=1; b = 2 ', 'b'), '2');
    });

    test('cookieValueOf_givenAValueWithEquals_keepsTheRest', () {
      // base64 填充里带 '='，只按第一个切分。
      expect(cookieValueOf('token=ab==', 'token'), 'ab==');
    });

    test('cookieValueOf_givenAnAbsentCookie_answersNull', () {
      expect(cookieValueOf('a=1', 'b'), isNull);
      expect(cookieValueOf(null, 'b'), isNull);
      expect(cookieValueOf('', 'b'), isNull);
      expect(cookieValueOf('; ;', 'b'), isNull);
    });

    test('cookieValueOf_givenAnEmptyValue_answersAnEmptyString', () {
      // 空值与「没有这个 cookie」不同：上游据此区分「清空」与「未登录」。
      expect(cookieValueOf('a=', 'a'), '');
    });
  });
}

JsSyncRequest _request({
  JsSyncOperation operation = JsSyncOperation.ajax,
  String url = 'https://a.test/page',
  String? body,
  String? key,
}) => JsSyncRequest(operation: operation, url: url, body: body, key: key);
