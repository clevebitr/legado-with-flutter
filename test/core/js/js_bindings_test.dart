import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyCryptoOperation', () {
    test('applyCryptoOperation_givenMd5_returnsTheHexDigest', () {
      // `md5('abc')` 是 RFC 1321 的公开测试向量。
      expect(
        applyCryptoOperation('md5', 'abc'),
        '900150983cd24fb0d6963f7d28e17f72',
      );
    });

    test('applyCryptoOperation_givenSha1_returnsTheHexDigest', () {
      expect(
        applyCryptoOperation('sha1', 'abc'),
        'a9993e364706816aba3e25717850c26c9cd0d89d',
      );
    });

    test('applyCryptoOperation_givenUtf8Text_encodesAndDecodesBase64', () {
      final String? encoded = applyCryptoOperation('base64Encode', '剑来');

      expect(encoded, isNotNull);
      // 非 ASCII 先按 UTF-8 编码，再 base64；解码走同一条路，因此能原样往返。
      expect(applyCryptoOperation('base64Decode', encoded as String), '剑来');
      expect(applyCryptoOperation('base64Decode', ''), isEmpty);
    });

    test('applyCryptoOperation_givenUnusableInput_returnsNull', () {
      // 未知操作、非 base64、base64 后不是 UTF-8：都是「没有值」，由 prelude 变成 JS Error。
      expect(applyCryptoOperation('sha256', 'abc'), isNull);
      expect(applyCryptoOperation('base64Decode', 'not base64!'), isNull);
      expect(applyCryptoOperation('base64Decode', '/w=='), isNull);
    });
  });

  group('JsHostCall', () {
    test('JsHostCall_toJsonAndFromJson_roundTrip', () {
      final Map<String, Object?> envelope = const JsHostCall(
        callId: 3,
        binding: jsHttpBinding,
        args: <String, Object?>{'url': 'https://a.test/'},
      ).toJson();

      expect(envelope['type'], 'host');
      final JsHostCall? decoded = JsHostCall.fromJson(envelope);
      expect(decoded?.callId, 3);
      expect(decoded?.binding, jsHttpBinding);
      expect(decoded?.args, <String, Object?>{'url': 'https://a.test/'});
    });

    test('JsHostCall_fromJson_givenNoCallId_returnsNull', () {
      // `callId` 是脚本等待的那条 Promise 的唯一凭据，缺了它就无法归属，必须当成畸形。
      expect(JsHostCall.fromJson(<String, Object?>{'binding': 'http'}), isNull);
      expect(
        JsHostCall.fromJson(<String, Object?>{
          'callId': '3',
          'binding': 'http',
        }),
        isNull,
      );
    });
  });

  group('JsHostReply', () {
    test('JsHostReply_toJsonAndFromJson_roundTripEveryShape', () {
      final Map<String, Object?> success = const JsHostReply.success(
        1,
        'body',
      ).toJson();
      expect(success['type'], 'hostResult');
      expect(JsHostReply.fromJson(success)?.value, 'body');

      final Map<String, Object?> rejected = const JsHostReply.rejected(
        2,
        'networkTimeout',
      ).toJson();
      final JsHostReply? decodedRejected = JsHostReply.fromJson(rejected);
      expect(decodedRejected?.isSuccess, isFalse);
      expect(decodedRejected?.fatal, isFalse);
      expect(decodedRejected?.message, 'networkTimeout');
      expect(decodedRejected?.kind, isNull);

      final Map<String, Object?> fatal = const JsHostReply.fatal(
        callId: 3,
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'contentRule.content:js:parse-scope',
        message: 'parse.* needs the page scope',
      ).toJson();
      expect(fatal['kind'], 'unsupportedRule');
      final JsHostReply? decodedFatal = JsHostReply.fromJson(fatal);
      expect(decodedFatal?.fatal, isTrue);
      expect(decodedFatal?.kind, ParseFailureKind.unsupportedRule);
      expect(decodedFatal?.rulePath, 'contentRule.content:js:parse-scope');
    });

    test('JsHostReply_fromJson_givenAUsableFailureWithoutAFatalFlag', () {
      // 没有 `fatal` 的失败是「只拒绝这次调用」，`message` 缺失时也要有可读的回退。
      final JsHostReply? decoded = JsHostReply.fromJson(<String, Object?>{
        'callId': 1,
        'ok': false,
      });

      expect(decoded?.fatal, isFalse);
      expect(decoded?.message, 'unknown host failure');
    });

    test('JsHostReply_fromJson_givenAnUnusableEnvelope_returnsNull', () {
      // 致命的答复必须自带 kind 与 rulePath：worker 不会自己编一个失败类型出来。
      expect(JsHostReply.fromJson(<String, Object?>{'ok': true}), isNull);
      expect(
        JsHostReply.fromJson(<String, Object?>{
          'callId': 1,
          'ok': false,
          'fatal': true,
          'kind': 'notAKind',
          'rulePath': 'x',
        }),
        isNull,
      );
      expect(
        JsHostReply.fromJson(<String, Object?>{
          'callId': 1,
          'ok': false,
          'fatal': true,
          'kind': 'parseFailed',
        }),
        isNull,
      );
    });
  });

  group('decodeJsHttpRequest', () {
    test('decodeJsHttpRequest_givenAGetWithHeaders_readsThem', () {
      final JsHttpRequest? request = decodeJsHttpRequest(<String, Object?>{
        'operation': 'get',
        'url': 'https://a.test/x',
        'options': <String, Object?>{
          'headers': <String, Object?>{'X-A': '1'},
        },
      });

      expect(request?.method, JsHttpMethod.get);
      expect(request?.url, 'https://a.test/x');
      expect(request?.headers, <String, String>{'X-A': '1'});
      expect(request?.body, isNull);
    });

    test('decodeJsHttpRequest_givenAPostWithABody_readsIt', () {
      final JsHttpRequest? request = decodeJsHttpRequest(<String, Object?>{
        'operation': 'post',
        'url': 'https://a.test/x',
        'options': <String, Object?>{'body': 'q=1'},
      });

      expect(request?.method, JsHttpMethod.post);
      expect(request?.body, 'q=1');
      expect(request?.headers, isEmpty);
    });

    test('decodeJsHttpRequest_givenNoOptions_answersWithDefaults', () {
      final JsHttpRequest? request = decodeJsHttpRequest(<String, Object?>{
        'operation': 'get',
        'url': 'https://a.test/x',
        'options': null,
      });

      expect(request?.headers, isEmpty);
      expect(request?.body, isNull);
    });

    test('decodeJsHttpRequest_givenUnusableArguments_returnsNull', () {
      // 每一项都是「无法诚实回答」的情形，由桥变成 rejected Promise，而不是空正文。
      expect(decodeJsHttpRequest('nonsense'), isNull);
      expect(decodeJsHttpRequest(<String, Object?>{'url': 'x'}), isNull);
      expect(
        decodeJsHttpRequest(<String, Object?>{'operation': 'get', 'url': ''}),
        isNull,
      );
      expect(
        decodeJsHttpRequest(<String, Object?>{'operation': 'get', 'url': 7}),
        isNull,
      );
      expect(
        decodeJsHttpRequest(<String, Object?>{
          'operation': 'get',
          'url': 'x',
          'options': 'nope',
        }),
        isNull,
      );
      expect(
        decodeJsHttpRequest(<String, Object?>{
          'operation': 'get',
          'url': 'x',
          'options': <String, Object?>{'headers': 'nope'},
        }),
        isNull,
      );
      expect(
        decodeJsHttpRequest(<String, Object?>{
          'operation': 'get',
          'url': 'x',
          'options': <String, Object?>{
            'headers': <Object?, Object?>{'X': 1},
          },
        }),
        isNull,
      );
      expect(
        decodeJsHttpRequest(<String, Object?>{
          'operation': 'post',
          'url': 'x',
          'options': <String, Object?>{'body': 1},
        }),
        isNull,
      );
      // 非字符串键的 JSON 对象不是这里的契约（`jsonDecode` 只会给出字符串键）。
      expect(decodeJsHttpRequest(<Object?, Object?>{1: 'x'}), isNull);
    });
  });

  group('decodeJsParseRequest', () {
    test('decodeJsParseRequest_givenGetString_readsTheFirstValueShape', () {
      final JsParseRequest? request = decodeJsParseRequest(<String, Object?>{
        'operation': 'getString',
        'rule': 'id.c@text',
        'doc': '<html></html>',
      });

      expect(request?.rule, 'id.c@text');
      expect(request?.wantsList, isFalse);
      expect(request?.doc, '<html></html>');
    });

    test('decodeJsParseRequest_givenGetElementsAndNoDoc_readsTheListShape', () {
      final JsParseRequest? request = decodeJsParseRequest(<String, Object?>{
        'operation': 'getElements',
        'rule': 'class.odd',
      });

      expect(request?.wantsList, isTrue);
      expect(request?.doc, isNull);
    });

    test('decodeJsParseRequest_givenUnusableArguments_returnsNull', () {
      expect(decodeJsParseRequest('nonsense'), isNull);
      expect(decodeJsParseRequest(<String, Object?>{'operation': 'x'}), isNull);
      expect(
        decodeJsParseRequest(<String, Object?>{
          'operation': 'getString',
          'rule': 1,
        }),
        isNull,
      );
      expect(
        decodeJsParseRequest(<String, Object?>{
          'operation': 'getString',
          'rule': 'a',
          'doc': 1,
        }),
        isNull,
      );
    });
  });

  group('decodeJsJavaRequest', () {
    test('decodeJsJavaRequest_givenAPut_returnsItsKeyAndValue', () {
      final JsJavaRequest? call = decodeJsJavaRequest(<String, Object?>{
        'operation': 'put',
        'key': 'token',
        'value': 'abc',
      });

      expect(call?.operation, JsJavaOperation.put);
      expect(call?.key, 'token');
      expect(call?.value, 'abc');
    });

    test('decodeJsJavaRequest_givenAGet_returnsANullValue', () {
      final JsJavaRequest? call = decodeJsJavaRequest(<String, Object?>{
        'operation': 'get',
        'key': 'token',
      });

      expect(call?.operation, JsJavaOperation.get);
      expect(call?.value, isNull);
    });

    test('decodeJsJavaRequest_givenAWriteThatClears_keepsTheNullValue', () {
      final JsJavaRequest? call = decodeJsJavaRequest(<String, Object?>{
        'operation': 'put',
        'key': 'token',
        'value': null,
      });

      // `java.put(key, null)` 是“清掉这个变量”（RuleDataInterface.kt:8-14），不能被当成缺失值。
      expect(call?.operation, JsJavaOperation.put);
      expect(call?.value, isNull);
    });

    test('decodeJsJavaRequest_givenAMalformedCall_returnsNull', () {
      // 未知动词、非对象参数、非字符串键与错类型的值都是畸形，由前奏变成 JS `Error`。
      expect(
        decodeJsJavaRequest(<String, Object?>{
          'operation': 'remove',
          'key': 'token',
        }),
        isNull,
      );
      expect(decodeJsJavaRequest('put'), isNull);
      expect(
        decodeJsJavaRequest(<String, Object?>{'operation': 'get', 'key': 1}),
        isNull,
      );
      expect(
        decodeJsJavaRequest(<String, Object?>{
          'operation': 'put',
          'key': 'token',
          'value': 1,
        }),
        isNull,
      );
    });
  });

  group('applyJsJavaCall', () {
    test('applyJsJavaCall_givenAWrite_reportsSuccessAndStoresIt', () {
      final Map<String, String?> variables = <String, String?>{};

      final String envelope = applyJsJavaCall(variables, <String, Object?>{
        'operation': 'put',
        'key': 'token',
        'value': 'abc',
      });

      // 写没有可回的值，所以信封的 ok 必须是**显式**的：裸 null 会被前奏当成失败。
      expect(envelope, '{"ok":true}');
      expect(variables, <String, String?>{'token': 'abc'});
    });

    test('applyJsJavaCall_givenARead_answersTheValue', () {
      expect(
        applyJsJavaCall(
          <String, String?>{'token': 'abc'},
          <String, Object?>{'operation': 'get', 'key': 'token'},
        ),
        '{"ok":true,"value":"abc"}',
      );
    });

    test('applyJsJavaCall_givenAnUnknownKey_readsAnEmptyString', () {
      // 上游 `AnalyzeRule.get` 对没写过的键给空串（AnalyzeRule.kt:812-825），不是 null。
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'get',
          'key': 'missing',
        }),
        '{"ok":true,"value":""}',
      );
    });

    test('applyJsJavaCall_givenAWriteWithANullValue_clearsTheVariable', () {
      final Map<String, String?> variables = <String, String?>{'token': 'abc'};

      applyJsJavaCall(variables, <String, Object?>{
        'operation': 'put',
        'key': 'token',
      });

      // 清空用 null 表达（RuleDataInterface.kt:8-14），桥据此把宿主侧的键删掉。
      expect(variables, <String, String?>{'token': null});
    });

    test('applyJsJavaCall_givenAMalformedCall_reportsFailure', () {
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'remove',
          'key': 'token',
        }),
        '{"ok":false}',
      );
      expect(applyJsJavaCall(<String, String?>{}, 'put'), '{"ok":false}');
    });
  });

  group('mergeJsHttpHeaders', () {
    test('mergeJsHttpHeaders_givenSourceAndRuleHeaders_letsTheRuleWin', () {
      expect(
        mergeJsHttpHeaders(
          <String, String>{
            'Referer': 'https://book.test/',
            'User-Agent': 'source',
          },
          <String, String>{'User-Agent': 'rule'},
        ),
        <String, String>{'Referer': 'https://book.test/', 'User-Agent': 'rule'},
      );
      expect(
        mergeJsHttpHeaders(null, <String, String>{'X': '1'}),
        <String, String>{'X': '1'},
      );
    });
  });
}
