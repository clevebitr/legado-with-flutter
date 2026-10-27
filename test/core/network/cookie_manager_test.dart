import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryCookieManager', () {
    test('cookieHeaderFor_whenNothingIsStored_returnsNull', () {
      final CookieManager cookies = InMemoryCookieManager();

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/a')),
        isNull,
      );
    });

    test('storeFromResponse_whenCookieIsSet_returnsItForTheSameHost', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/a'), <String>[
        'session=abc; Path=/',
      ]);

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/b')),
        'session=abc',
      );
      expect(cookies.cookieHeaderFor(Uri.parse('https://other.com/b')), isNull);
    });

    test(
      'storeFromResponse_whenSeveralCookiesMatch_joinsThemWithSemicolons',
      () {
        final CookieManager cookies = InMemoryCookieManager();

        cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
          'a=1; Path=/',
          'b=2; Path=/',
        ]);

        expect(
          cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
          'a=1; b=2',
        );
      },
    );

    test('storeFromResponse_whenValueContainsEquals_keepsTheWholeValue', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'session=YWJj==; Path=/',
      ]);

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        'session=YWJj==',
      );
    });

    test(
      'storeFromResponse_whenDomainAttributeMatches_appliesToSubdomains',
      () {
        final CookieManager cookies = InMemoryCookieManager();

        cookies.storeFromResponse(
          Uri.parse('https://www.example.com/'),
          <String>['session=abc; Domain=example.com; Path=/'],
        );

        expect(
          cookies.cookieHeaderFor(Uri.parse('https://api.example.com/')),
          'session=abc',
        );
      },
    );

    test('storeFromResponse_whenDomainAttributeIsForeign_isIgnored', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'session=abc; Domain=other.com; Path=/',
      ]);

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        'session=abc',
        reason: 'A foreign domain attribute falls back to the request host.',
      );
      expect(cookies.cookieHeaderFor(Uri.parse('https://other.com/')), isNull);
    });

    test('storeFromResponse_whenDomainAttributeIsASingleLabel_isIgnored', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'session=abc; Domain=com; Path=/',
      ]);

      expect(cookies.cookieHeaderFor(Uri.parse('https://other.com/')), isNull);
      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        'session=abc',
      );
    });

    test('storeFromResponse_whenPathAttributeIsSet_scopesTheCookie', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'session=abc; Path=/search',
      ]);

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/search/x')),
        'session=abc',
      );
      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/searchx')),
        isNull,
        reason: 'A path prefix must end on a segment boundary.',
      );
      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/other')),
        isNull,
      );
    });

    test(
      'storeFromResponse_whenPathAttributeEndsWithSlash_scopesTheCookie',
      () {
        final CookieManager cookies = InMemoryCookieManager();

        cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
          'session=abc; Path=/search/',
        ]);

        expect(
          cookies.cookieHeaderFor(Uri.parse('https://example.com/search/x')),
          'session=abc',
        );
      },
    );

    test('storeFromResponse_whenPathAttributeIsEmpty_keepsTheDefaultPath', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(
        Uri.parse('https://example.com/deep/page'),
        <String>['session=abc; Path='],
      );

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/anything')),
        'session=abc',
      );
    });

    test('cookieHeaderFor_whenCookieIsSecure_isNotSentOverPlainHttp', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'session=abc; Secure; Path=/',
      ]);

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        'session=abc',
      );
      expect(cookies.cookieHeaderFor(Uri.parse('http://example.com/')), isNull);
    });

    test('storeFromResponse_whenMaxAgeIsZero_removesTheCookie', () {
      final CookieManager cookies = InMemoryCookieManager();
      final Uri url = Uri.parse('https://example.com/');

      cookies.storeFromResponse(url, <String>['session=abc; Path=/']);
      cookies.storeFromResponse(url, <String>[
        'session=abc; Max-Age=0; Path=/',
      ]);

      expect(cookies.cookieHeaderFor(url), isNull);
    });

    test('storeFromResponse_whenMaxAgeIsPositive_keepsTheCookie', () {
      final CookieManager cookies = InMemoryCookieManager();
      final Uri url = Uri.parse('https://example.com/');

      cookies.storeFromResponse(url, <String>[
        'session=abc; Max-Age=3600; Path=/',
      ]);

      expect(cookies.cookieHeaderFor(url), 'session=abc');
    });

    test('storeFromResponse_whenValueIsEmpty_removesTheCookie', () {
      final CookieManager cookies = InMemoryCookieManager();
      final Uri url = Uri.parse('https://example.com/');

      cookies.storeFromResponse(url, <String>['session=abc; Path=/']);
      cookies.storeFromResponse(url, <String>['session=; Path=/']);

      expect(cookies.cookieHeaderFor(url), isNull);
    });

    test('storeFromResponse_whenHeaderHasNoPair_isIgnored', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'session',
        '=abc; Path=/',
      ]);

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        isNull,
      );
    });

    test('storeFromResponse_whenUnknownAttributeIsPresent_keepsTheCookie', () {
      final CookieManager cookies = InMemoryCookieManager();

      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'session=abc; HttpOnly; SameSite=Lax; Expires=Wed, 21 Oct 2036 07:28:00 GMT; Path=/',
      ]);

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        'session=abc',
      );
    });

    test('mergeCookieHeader_givenABareCookie_storesEveryPair', () {
      // `source.putLoginHeader` 里的 Cookie 走这里：上游把它并进宗，宗才是真正发它的地方。
      final InMemoryCookieManager cookies = InMemoryCookieManager();

      cookies.mergeCookieHeader(
        Uri.parse('https://example.com/'),
        'sid=1; token=ab; padding==',
      );

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/x')),
        allOf(contains('sid=1'), contains('token=ab'), contains('padding==')),
      );
    });

    test('mergeCookieHeader_replacesACookieWithTheSameName', () {
      final InMemoryCookieManager cookies = InMemoryCookieManager();
      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'sid=old',
      ]);

      cookies.mergeCookieHeader(Uri.parse('https://example.com/'), 'sid=new');

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        'sid=new',
      );
    });

    test('mergeCookieHeader_skipsPairsWithoutANameOrValue', () {
      final InMemoryCookieManager cookies = InMemoryCookieManager();

      cookies.mergeCookieHeader(
        Uri.parse('https://example.com/'),
        'sid=1; ; =broken; empty= ',
      );

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
        'sid=1',
      );
    });

    test('removeCookiesFor_givenTheSourceUrl_dropsWhatItWouldSend', () {
      // `source.removeLoginHeader`（M25/S5a）：上游删的是这个源二级域的整条记录。
      final InMemoryCookieManager cookies = InMemoryCookieManager();
      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'sid=1',
      ]);
      cookies.storeFromResponse(Uri.parse('https://www.example.com/'), <String>[
        'session=2',
      ]);
      cookies.storeFromResponse(Uri.parse('https://other.test/'), <String>[
        'keep=3',
      ]);

      // 子域登录后落在父域上的 cookie 也算「这个源会发出去的」。
      cookies.storeFromResponse(Uri.parse('https://sub.example.com/'), <String>[
        'parenthost=4; Domain=example.com',
      ]);

      cookies.removeCookiesFor(Uri.parse('https://www.example.com/book/1'));

      expect(
        cookies.cookieHeaderFor(Uri.parse('https://www.example.com/')),
        isNull,
      );
      expect(
        cookies.cookieHeaderFor(Uri.parse('https://sub.example.com/')),
        isNull,
      );
      // 反方向不算：`www.example.com` 自己的 cookie 不会被 `example.com` 的请求带上。
      expect(
        cookies.cookieHeaderFor(Uri.parse('https://www.example.com/')),
        isNull,
      );
      // 别的域不受影响：登出一个源不该顺手把别人的会话也清掉。
      expect(
        cookies.cookieHeaderFor(Uri.parse('https://other.test/')),
        'keep=3',
      );
    });

    test('domainsFor_givenASourceUrl_answersTheStoredDomains', () {
      // 持久宗只能按域删：域名得从宗里问，不能从 URL 推。
      final InMemoryCookieManager cookies = InMemoryCookieManager();
      cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
        'sid=1',
      ]);
      cookies.storeFromResponse(Uri.parse('https://other.test/'), <String>[
        'keep=3',
      ]);

      expect(cookies.domainsFor(Uri.parse('https://example.com/a')), <String>{
        'example.com',
      });
      expect(cookies.domainsFor(Uri.parse('https://nothing.test/')), isEmpty);
    });

    test('parseCookieHeader_storesThemForTheURLHostOnly', () {
      final List<StoredCookie> parsed = parseCookieHeader(
        Uri.parse('https://example.com/a'),
        'sid=1',
      );

      expect(parsed.single.domain, 'example.com');
      expect(parsed.single.path, '/');
      expect(parsed.single.isSecure, isFalse);
      expect(parsed.single.expiresAt, isNull);
    });

    test(
      'storeFromResponse_whenExpiresIsUnparsable_keepsItAsASessionCookie',
      () {
        // 解析不了的 Expires 当作「没有过期信息」：不丢 cookie，也不给出错误的过期时间。
        final CookieManager cookies = InMemoryCookieManager();

        cookies.storeFromResponse(Uri.parse('https://example.com/'), <String>[
          'session=abc; Expires=not-a-date',
        ]);

        expect(
          cookies.cookieHeaderFor(Uri.parse('https://example.com/')),
          'session=abc',
        );
      },
    );
  });
}
