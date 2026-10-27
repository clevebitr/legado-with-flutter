import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/js/js_bindings.dart';
import 'package:flutter_reader/core/js/js_bridge.dart';
import 'package:flutter_reader/core/js/js_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/synthetic_ttf.dart';

/// A base64 font whose private-use characters draw 剑 / 客 (glyph names carry the real code point).
String _errorFontBase64() => base64Encode(
  buildSyntheticFont(
    cmapOverride: buildSyntheticCmap(codes: <int, int>{0xE001: 1, 0xE002: 2}),
    includePost: true,
    postOverride: buildSyntheticPost(
      numGlyphs: 3,
      names: <int, String>{1: 'uni5251', 2: 'uni5BA2'},
    ),
  ),
);

/// A base64 font that draws the real characters themselves.
String _correctFontBase64() => base64Encode(
  buildSyntheticFont(
    cmapOverride: buildSyntheticCmap(codes: <int, int>{0x5251: 1, 0x5BA2: 2}),
    includePost: true,
    postOverride: buildSyntheticPost(
      numGlyphs: 3,
      names: <int, String>{1: 'uni5251', 2: 'uni5BA2'},
    ),
  ),
);

/// Reads the `value` of a successful envelope, or `null`.
Object? _valueOf(String envelope) {
  final Map<String, Object?> decoded =
      jsonDecode(envelope) as Map<String, Object?>;

  return decoded['ok'] == true ? decoded['value'] : null;
}

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
      // 默认只要正文；`response: true` 才是整个响应（book-source.md §6）。
      expect(request?.wantsResponse, isFalse);
    });

    test('decodeJsHttpRequest_givenAResponseFlag_readsIt', () {
      final JsHttpRequest? request = decodeJsHttpRequest(<String, Object?>{
        'operation': 'post',
        'url': 'https://a.test/x',
        'options': <String, Object?>{'body': 'q=1', 'response': true},
      });

      expect(request?.wantsResponse, isTrue);
      expect(request?.body, 'q=1');
    });

    test('decodeJsHttpRequest_givenANonBooleanResponseFlag_returnsNull', () {
      // 听不懂的标志位要让这次调用显式失败，而不是静默退回「只要正文」。
      expect(
        decodeJsHttpRequest(<String, Object?>{
          'operation': 'get',
          'url': 'https://a.test/x',
          'options': <String, Object?>{'response': 'yes'},
        }),
        isNull,
      );
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
      expect(
        decodeJsParseRequest(<String, Object?>{
          'operation': 'getString',
          'rule': 'a',
          'content': 1,
        }),
        isNull,
      );
    });

    test('decodeJsParseRequest_givenASetContent_keepsThePageOverride', () {
      // `java.setContent(html)` 之后，`parse.*` 带着替换后的正文来问宿主（ADR-0076 §决策 1）。
      final JsParseRequest? request = decodeJsParseRequest(<String, Object?>{
        'operation': 'getString',
        'rule': 'id.c@text',
        'content': '<html><div id="c">新</div></html>',
      });

      expect(request?.content, '<html><div id="c">新</div></html>');
      expect(request?.doc, isNull);
    });
  });

  group('decodeJsOpenUrlRequest', () {
    test('decodeJsOpenUrlRequest_givenAnAddress_readsIt', () {
      final JsOpenUrlRequest? request = decodeJsOpenUrlRequest(
        <String, Object?>{'url': ' https://a.test/book/1 '},
      );

      expect(request?.url, 'https://a.test/book/1');
      expect(request?.mimeType, isNull);
    });

    test('decodeJsOpenUrlRequest_givenAMimeType_keepsIt', () {
      expect(
        decodeJsOpenUrlRequest(<String, Object?>{
          'url': 'https://a.test/a',
          'mimeType': 'text/html',
        })?.mimeType,
        'text/html',
      );
    });

    test('decodeJsOpenUrlRequest_givenAnEmptyAddress_isNull', () {
      // 空地址弹窗没有意义，也开不出任何东西：调用方会明确拒绝而不是弹一个空框。
      expect(decodeJsOpenUrlRequest(<String, Object?>{'url': '   '}), isNull);
      expect(decodeJsOpenUrlRequest('nonsense'), isNull);
      expect(decodeJsOpenUrlRequest(<String, Object?>{'url': 7}), isNull);
    });

    test('decodeJsOpenUrlRequest_givenAnAddressPastTheBound_isNull', () {
      // 上游 `require(url.length < 64 * 1024)` 的同一道门。
      expect(
        decodeJsOpenUrlRequest(<String, Object?>{
          'url': 'https://a.test/${'a' * maxJsOpenUrlLength}',
        }),
        isNull,
      );
    });
  });

  group('applyJsSourceCall', () {
    test('applyJsSourceCall_givenAGet_answersTheStoredValue', () {
      final Map<String, String?> variables = <String, String?>{'token': 'abc'};

      expect(
        jsonDecode(
          applyJsSourceCall(variables, <String, Object?>{
            'operation': 'get',
            'key': 'token',
          }),
        ),
        <String, Object?>{'ok': true, 'value': 'abc'},
      );
    });

    test('applyJsSourceCall_givenAnUnwrittenKey_answersAnEmptyString', () {
      // 上游 `getVariable` 不区分「没有」与「空」。
      expect(
        jsonDecode(
          applyJsSourceCall(<String, String?>{}, <String, Object?>{
            'operation': 'get',
            'key': 'missing',
          }),
        ),
        <String, Object?>{'ok': true, 'value': ''},
      );
    });

    test('applyJsSourceCall_givenAPut_writesTheMap', () {
      final Map<String, String?> variables = <String, String?>{};

      expect(
        applyJsSourceCall(variables, <String, Object?>{
          'operation': 'put',
          'key': 'token',
          'value': 'abc',
        }),
        '{"ok":true}',
      );
      expect(variables, <String, String?>{'token': 'abc'});
    });

    test('applyJsSourceCall_givenANullValue_clearsTheKey', () {
      final Map<String, String?> variables = <String, String?>{'token': 'abc'};

      applyJsSourceCall(variables, <String, Object?>{
        'operation': 'put',
        'key': 'token',
      });

      expect(variables['token'], isNull);
    });

    test('applyJsSourceCall_givenAGetLoginHeader_answersTheSeededValue', () {
      // M25/S3b：登录头随 job 下传，读它是纯粹的本地读取。
      final JsLoginHeaderSlot slot = JsLoginHeaderSlot('{"Token":"t"}');

      expect(
        jsonDecode(
          applyJsSourceCall(<String, String?>{}, <String, Object?>{
            'operation': 'getLoginHeader',
          }, loginHeader: slot),
        ),
        <String, Object?>{'ok': true, 'value': '{"Token":"t"}'},
      );
    });

    test('applyJsSourceCall_givenNoSeededLoginHeader_answersNull', () {
      // 上游 `getLoginHeader()` 没有值时返回 null，而 `getVariable` 返回空串。
      expect(
        jsonDecode(
          applyJsSourceCall(<String, String?>{}, <String, Object?>{
            'operation': 'getLoginHeader',
          }, loginHeader: JsLoginHeaderSlot(null)),
        ),
        <String, Object?>{'ok': true, 'value': null},
      );
    });

    test('applyJsSourceCall_givenAPutLoginHeader_writesAndMarksItTouched', () {
      final JsLoginHeaderSlot slot = JsLoginHeaderSlot(null);

      expect(
        applyJsSourceCall(<String, String?>{}, <String, Object?>{
          'operation': 'putLoginHeader',
          'value': '{"Token":"t"}',
        }, loginHeader: slot),
        '{"ok":true}',
      );
      expect(slot.value, '{"Token":"t"}');
      expect(slot.touched, isTrue);
    });

    test('applyJsSourceCall_givenAReadOnlySlot_leavesItUntouched', () {
      final JsLoginHeaderSlot slot = JsLoginHeaderSlot('{"Token":"t"}');

      applyJsSourceCall(<String, String?>{}, <String, Object?>{
        'operation': 'getLoginHeader',
      }, loginHeader: slot);

      expect(slot.touched, isFalse);
    });

    test('applyJsSourceCall_givenANonStringLoginHeader_fails', () {
      // 上游签名是 `putLoginHeader(header: String)`：给别的类型就是规则写错了，必须响亮。
      expect(
        applyJsSourceCall(<String, String?>{}, <String, Object?>{
          'operation': 'putLoginHeader',
          'value': 1,
        }, loginHeader: JsLoginHeaderSlot(null)),
        '{"ok":false}',
      );
    });

    test('applyJsSourceCall_withoutASlot_failsTheLoginHeaderOperations', () {
      // 没播种就当作「这条规则跑过的 job 不该用登录头」，读和写都响亮失败（C-SRC-4 的同一立场）。
      expect(
        applyJsSourceCall(<String, String?>{}, <String, Object?>{
          'operation': 'getLoginHeader',
        }),
        '{"ok":false}',
      );
      expect(
        applyJsSourceCall(<String, String?>{}, <String, Object?>{
          'operation': 'putLoginHeader',
          'value': '{"Token":"t"}',
        }),
        '{"ok":false}',
      );
    });

    test('applyJsSourceCall_givenUnusableArguments_answersAFailure', () {
      expect(
        applyJsSourceCall(<String, String?>{}, 'nonsense'),
        '{"ok":false}',
      );
      expect(
        applyJsSourceCall(<String, String?>{}, <String, Object?>{
          'operation': 'get',
        }),
        '{"ok":false}',
      );
      expect(
        applyJsSourceCall(<String, String?>{}, <String, Object?>{
          'operation': 'delete',
          'key': 'a',
        }),
        '{"ok":false}',
      );
      expect(
        applyJsSourceCall(<String, String?>{}, <String, Object?>{
          'operation': 'put',
          'key': 'a',
          'value': 1,
        }),
        '{"ok":false}',
      );
    });
  });

  group('decodeJsToastRequest', () {
    test('decodeJsToastRequest_givenAMessage_readsItAndTheLength', () {
      expect(
        decodeJsToastRequest(<String, Object?>{'message': '请先登录', 'long': true})
            ?.message,
        '请先登录',
      );
      expect(
        decodeJsToastRequest(<String, Object?>{'message': '请先登录', 'long': true})
            ?.isLong,
        isTrue,
      );
      expect(
        decodeJsToastRequest(<String, Object?>{'message': 'x'})?.isLong,
        isFalse,
      );
    });

    test('decodeJsToastRequest_givenUnusableArguments_returnsNull', () {
      expect(decodeJsToastRequest(null), isNull);
      expect(decodeJsToastRequest(<String, Object?>{'message': 1}), isNull);
      expect(decodeJsToastRequest(<String, Object?>{'message': '   '}), isNull);
      expect(
        decodeJsToastRequest(<String, Object?>{'message': 'x', 'long': 'yes'}),
        isNull,
      );
    });
  });

  group('jsResponsePayload', () {
    test('jsResponsePayload_givenAHeadersMap_joinsRepeatedValues', () {
      // 与 `loginCheckJs` 看到的 result 同形：头名保持原样、多值用逗号拼。
      final Map<String, Object?> payload = jsResponsePayload(
        url: 'https://a.test/next',
        body: '<html></html>',
        code: 200,
        headers: <String, List<String>>{
          'set-cookie': <String>['a=1', 'b=2'],
        },
      );

      expect(payload[jsResponseMarker], isTrue);
      expect(payload['body'], '<html></html>');
      expect(payload['__url'], 'https://a.test/next');
      expect(payload['__code'], 200);
      expect(payload['__headers'], <String, String>{'set-cookie': 'a=1, b=2'});
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

    test('applyJsJavaCall_givenABookName_answersItBeforeTheVariables', () {
      // M12-A5 / ADR-0049：`java.get('bookName')` 是上游的**内置键**，变量表里的同名变量
      // 不许抢答（`AnalyzeRule.get` 的 `when (key)` 拦截）。
      expect(
        applyJsJavaCall(
          <String, String?>{'bookName': '变量里的书名'},
          <String, Object?>{'operation': 'get', 'key': 'bookName'},
          named: <String, String>{'bookName': '真书名'},
        ),
        '{"ok":true,"value":"真书名"}',
      );
      expect(
        applyJsJavaCall(
          <String, String?>{},
          <String, Object?>{'operation': 'get', 'key': 'title'},
          named: <String, String>{'title': '第一章'},
        ),
        '{"ok":true,"value":"第一章"}',
      );
    });

    test('applyJsJavaCall_givenNoNamedContext_fallsThroughToTheVariables', () {
      // 拿不到上下文的阶段（搜索 / 目录）不能被“内置键”这一层吃掉变量：键名就是普通变量。
      expect(
        applyJsJavaCall(
          <String, String?>{'title': '变量里的章节'},
          <String, Object?>{'operation': 'get', 'key': 'title'},
        ),
        '{"ok":true,"value":"变量里的章节"}',
      );
    });

    test('decodeJsNamedContext_givenBlankOrMissingFields_keepsThemAbsent', () {
      expect(decodeJsNamedContext(const <String, Object?>{}), isEmpty);
      expect(
        decodeJsNamedContext(<String, Object?>{
          'bookName': '',
          'chapterTitle': '第一章',
        }),
        <String, String>{'title': '第一章'},
      );
      // 非字符串（畸形信封）同样当作缺失，不让它进 `named`。
      expect(
        decodeJsNamedContext(<String, Object?>{
          'bookName': 1,
          'chapterTitle': '',
        }),
        isEmpty,
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

  group('decodeJsVariables', () {
    test('decodeJsVariables_givenAReportedTable_keepsStringsAndNulls', () {
      // 两端用同一个读法：job 的快照与 worker 的回报只差方向（ADR-0034 §决策 1）。
      expect(
        decodeJsVariables(<String, Object?>{'token': 'abc', 'gone': null}),
        <String, String?>{'token': 'abc', 'gone': null},
      );
    });

    test('decodeJsVariables_givenAnUnusableValue_dropsIt', () {
      // 值不是字符串也不是 null 时丢弃而不是强制转换（`3` 与 `"3"` 不是一回事）。
      expect(
        decodeJsVariables(<String, Object?>{'n': 3, 'ok': 'x'}),
        <String, String?>{'ok': 'x'},
      );
      expect(decodeJsVariables('token'), isEmpty);
      expect(decodeJsVariables(null), isEmpty);
    });
  });

  group('formatJsTimestamp / formatTimestamp (M1-b1)', () {
    test('formatTimestamp_givenAnInstant_writesTheFixedPattern', () {
      // §6 的 pattern 是固定的 `yyyy/MM/dd HH:mm`，零截断到两位；月 / 日 / 时 / 分都补零。
      expect(
        formatTimestamp(DateTime.utc(2026, 10, 13, 9, 5)),
        '2026/10/13 09:05',
      );
      expect(
        formatTimestamp(DateTime.utc(2026, 1, 2, 3, 4)),
        '2026/01/02 03:04',
      );
      expect(
        formatTimestamp(DateTime.utc(2026, 12, 31, 23, 59)),
        '2026/12/31 23:59',
      );
    });

    test('formatJsTimestamp_givenMilliseconds_usesTheLocalZone', () {
      // 入参是**毫秒**（不是秒），时区是设备本地（上游 FastDateFormat 取 JVM 默认时区）。
      // 断言用同一个本地换算构造期望值，所以这条测试不依赖跑测试的机器在哪个时区。
      expect(
        formatJsTimestamp(1700000000000),
        formatTimestamp(DateTime.fromMillisecondsSinceEpoch(1700000000000)),
      );
      expect(
        formatJsTimestamp(0),
        formatTimestamp(DateTime.fromMillisecondsSinceEpoch(0)),
      );
    });

    test('formatJsTimestamp_givenANumericString_readsItAsMilliseconds', () {
      // 上游收的是 `Long`，而 JS 里数字与数字串都可能传进来（§6 的入参说明）。
      expect(
        formatJsTimestamp('1700000000000'),
        formatTimestamp(DateTime.fromMillisecondsSinceEpoch(1700000000000)),
      );
      expect(
        formatJsTimestamp(' 1700000000000 '),
        formatTimestamp(DateTime.fromMillisecondsSinceEpoch(1700000000000)),
      );
    });

    test('formatJsTimestamp_givenAFraction_truncatesTowardsZero', () {
      // Java 的 `(long)` 转换就是向零截断；毫秒时间戳不会有小数位，所以这不隐藏任何数字。
      expect(
        formatJsTimestamp(1.9),
        formatTimestamp(DateTime.fromMillisecondsSinceEpoch(1)),
      );
      expect(
        formatJsTimestamp(-1.9),
        formatTimestamp(DateTime.fromMillisecondsSinceEpoch(-1)),
      );
    });

    test('formatJsTimestamp_givenAnUnusableValue_returnsNull', () {
      // 无法读成时间戳的入参一律 null（调用方转成 ok:false → JS `Error`，不是静默给错值）。
      expect(formatJsTimestamp(null), isNull);
      expect(formatJsTimestamp('abc'), isNull);
      expect(formatJsTimestamp(''), isNull);
      expect(formatJsTimestamp(true), isNull);
      expect(formatJsTimestamp(<int>[1]), isNull);
      expect(formatJsTimestamp(double.nan), isNull);
      expect(formatJsTimestamp(double.infinity), isNull);
      // 超出 Dart `DateTime` 范围的值：在这里就挡住，不去碰会抛 `Error` 的构造。
      expect(formatJsTimestamp(9000000000000000), isNull);
      expect(formatJsTimestamp(-9000000000000000), isNull);
    });
  });

  group('applyJsJavaCall timeFormat (M1-b1)', () {
    test('applyJsJavaCall_givenATimeFormatCall_answersTheFormattedValue', () {
      expect(
        jsonDecode(
          applyJsJavaCall(<String, String?>{}, <String, Object?>{
            'operation': 'timeFormat',
            'value': 1700000000000,
          }),
        ) as Map<String, Object?>,
        <String, Object?>{
          'ok': true,
          'value': formatTimestamp(
            DateTime.fromMillisecondsSinceEpoch(1700000000000),
          ),
        },
      );
    });

    test('applyJsJavaCall_givenAnUnusableTimestamp_reportsFailure', () {
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'timeFormat',
          'value': 'not-a-time',
        }),
        '{"ok":false}',
      );
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'timeFormat',
        }),
        '{"ok":false}',
      );
    });

    test('decodeJsJavaRequest_givenATimeFormatCall_keepsTheRawArgument', () {
      final JsJavaRequest? call = decodeJsJavaRequest(<String, Object?>{
        'operation': 'timeFormat',
        'value': 5,
      });

      expect(call?.operation, JsJavaOperation.timeFormat);
      expect(call?.key, isNull);
      // 参数不在这里强制成字符串：数字与数字串都合法，形状由 `formatJsTimestamp` 定（§6）。
      expect(call?.value, 5);
    });
  });

  group('javaEncodeUri (M1-b1b)', () {
    test('javaEncodeUri_givenText_encodesLikeAJavaFormEncoder', () {
      // 上游是 `URLEncoder.encode(str, "UTF-8")`（JsExtensions.kt:683-689）：空格 → `+`，
      // 保留 `A-Za-z0-9` 与 `-_.*`，其余按 UTF-8 字节 `%XX` 大写。
      expect(javaEncodeUri('abc-_.*123'), 'abc-_.*123');
      expect(javaEncodeUri('a b'), 'a+b');
      expect(
        javaEncodeUri('https://a.test/x?q=1&p=2'),
        'https%3A%2F%2Fa.test%2Fx%3Fq%3D1%26p%3D2',
      );
      expect(javaEncodeUri('剑来'), '%E5%89%91%E6%9D%A5');
    });

    test('javaEncodeUri_givenAnAlreadyEncodedValue_encodesThePercentAgain', () {
      // 与 url_template 的模板编码器不同：上游**总是**编码，没有再编一次的判断。
      expect(javaEncodeUri('%20'), '%2520');
      expect(javaEncodeUri('+'), '%2B');
    });

    test('applyJsJavaCall_givenAnEncodeUriCall_answersTheEncodedValue', () {
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'encodeUri',
          'value': 'a b',
        }),
        '{"ok":true,"value":"a+b"}',
      );
    });

    test(
      'decodeJsJavaRequest_givenAnEncodeUriCallWithABadValue_isMalformed',
      () {
        expect(
          decodeJsJavaRequest(<String, Object?>{
            'operation': 'encodeUri',
            'value': 1,
          }),
          isNull,
        );
      },
    );
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

  group('java.encodeURI charset (ADR-0069 G1)', () {
    test('javaEncodeUri_givenACharset_escapesItsBytes', () {
      // 美女图片网的 searchUrl 用 `java.encodeURI(key,"GBK")`：老 PHP 站点只认 GBK 字节。
      expect(javaEncodeUri('美女', charset: 'gbk'), '%C3%C0%C5%AE');
      expect(javaEncodeUri('剑来', charset: 'GBK'), '%BD%A3%C0%B4');
    });

    test('javaEncodeUri_givenNoCharset_staysUtf8', () {
      expect(javaEncodeUri('a b'), 'a+b');
      expect(javaEncodeUri('剑来'), '%E5%89%91%E6%9D%A5');
    });

    test('applyJsJavaCall_givenTheTwoArgumentForm_passesTheCharset', () {
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'encodeUri',
          'value': '美女',
          'charset': 'gbk',
        }),
        '{"ok":true,"value":"%C3%C0%C5%AE"}',
      );
    });

    test('decodeJsJavaRequest_givenANonStringCharset_returnsNull', () {
      expect(
        decodeJsJavaRequest(<String, Object?>{
          'operation': 'encodeUri',
          'value': 'a',
          'charset': 1,
        }),
        isNull,
      );
    });
  });

  group('applyJsJavaCall fonts (M21a)', () {
    late JsFontRegistry fonts;

    setUp(() => fonts = JsFontRegistry());

    /// Queries [base64] and answers the handle id.
    int query(String base64) {
      final Object? handle = _valueOf(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'queryTtf',
          'value': base64,
        }, fonts: fonts),
      );

      return (handle as Map<String, Object?>)['id'] as int;
    }

    test('queryTtf_givenAFontBase64_answersAHandle', () {
      final Object? handle = _valueOf(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'queryTtf',
          'value': _errorFontBase64(),
        }, fonts: fonts),
      );

      // 字体不进脚本：脚本只拿到一个不透明句柄，正文替换时再交回来。
      expect(handle, <String, Object?>{'__ttf': true, 'id': 1});
    });

    test('queryTtf_givenADataUrl_stripsThePrefix', () {
      final Object? handle = _valueOf(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'queryTtf',
          'value': 'data:font/ttf;base64,${_errorFontBase64()}',
        }, fonts: fonts),
      );

      expect(handle, isNotNull);
    });

    test('queryTtf_givenLineWrappedBase64_readsIt', () {
      final String wrapped = _errorFontBase64().replaceAllMapped(
        RegExp(r'.{20}'),
        (Match match) => '${match.group(0)}\n',
      );

      expect(
        _valueOf(
          applyJsJavaCall(<String, String?>{}, <String, Object?>{
            'operation': 'queryTtf',
            'value': wrapped,
          }, fonts: fonts),
        ),
        isNotNull,
      );
    });

    test('queryTtf_givenSomethingThatIsNotAFont_fails', () {
      // 不是字体时只回答「拿不到」：脚本可以 catch 后保留原正文，不必整条 job 死。
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'queryTtf',
          'value': base64Encode(utf8.encode('not a font')),
        }, fonts: fonts),
        '{"ok":false}',
      );
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'queryTtf',
          'value': '!!!',
        }, fonts: fonts),
        '{"ok":false}',
      );
    });

    test('queryTtf_givenNoRegistry_fails', () {
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'queryTtf',
          'value': _errorFontBase64(),
        }),
        '{"ok":false}',
      );
    });

    test('replaceFont_givenBothHandles_mapsTheText', () {
      final int errorFont = query(_errorFontBase64());
      final int correctFont = query(_correctFontBase64());

      final Object? replaced = _valueOf(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'replaceFont',
          'value': <String, Object?>{
            'text': '',
            'from': errorFont,
            'to': correctFont,
          },
        }, fonts: fonts),
      );

      expect(replaced, '剑客');
    });

    test('replaceFont_givenACodePointRange_replacesOnlyInsideIt', () {
      final int errorFont = query(_errorFontBase64());
      final int correctFont = query(_correctFontBase64());

      final Object? replaced = _valueOf(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'replaceFont',
          'value': <String, Object?>{
            'text': '',
            'from': errorFont,
            'to': correctFont,
            'start': 0xE001,
            'end': 0xE001,
          },
        }, fonts: fonts),
      );

      expect(replaced, '剑');
    });

    test('replaceFont_givenAnUnknownHandle_fails', () {
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'replaceFont',
          'value': <String, Object?>{'text': 'x', 'from': 99, 'to': 98},
        }, fonts: fonts),
        '{"ok":false}',
      );
    });

    test('replaceFont_givenOnlyOneHandle_fails', () {
      final int errorFont = query(_errorFontBase64());

      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'replaceFont',
          'value': <String, Object?>{'text': 'x', 'from': errorFont},
        }, fonts: fonts),
        '{"ok":false}',
      );
    });

    test('replaceFont_givenNoRegistry_fails', () {
      expect(
        applyJsJavaCall(<String, String?>{}, <String, Object?>{
          'operation': 'replaceFont',
          'value': <String, Object?>{'text': 'x', 'from': 1, 'to': 2},
        }),
        '{"ok":false}',
      );
    });

    test('decodeJsJavaRequest_givenMalformedFontCalls_returnsNull', () {
      expect(
        decodeJsJavaRequest(<String, Object?>{'operation': 'queryTtf'}),
        isNull,
      );
      expect(
        decodeJsJavaRequest(<String, Object?>{
          'operation': 'queryTtf',
          'value': '   ',
        }),
        isNull,
      );
      expect(
        decodeJsJavaRequest(<String, Object?>{'operation': 'replaceFont'}),
        isNull,
      );
      expect(
        decodeJsJavaRequest(<String, Object?>{
          'operation': 'replaceFont',
          'value': <String, Object?>{'text': 1},
        }),
        isNull,
      );
      expect(
        decodeJsJavaRequest(<String, Object?>{
          'operation': 'replaceFont',
          'value': <String, Object?>{'text': 'x', 'from': 'one'},
        }),
        isNull,
      );
    });

    test('decodeFontBase64_givenUnusableText_returnsNull', () {
      expect(decodeFontBase64('   '), isNull);
      expect(decodeFontBase64('!!!'), isNull);
    });

    test('decodeFontBase64_givenPlainOrNonBase64Data_readsWhatItCan', () {
      expect(decodeFontBase64(base64Encode(<int>[0, 1, 2])), <int>[0, 1, 2]);
      // 没有 `;base64` 的 data URL 是 URL 编码载荷，不是 base64：读不出来就是 null。
      expect(decodeFontBase64('data:font/ttf,AAAA'), isNull);
    });
  });
}
