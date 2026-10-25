import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/network/web_dav_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with whatever [respond] decides, so no socket is involved.
final class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  /// The answer for one request; throwing a [DioException] simulates a failure.
  final FutureOr<ResponseBody> Function(RequestOptions options) respond;

  /// Every request the client made, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioOf(_FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;

const WebDavCredentials _credentials = WebDavCredentials(
  collectionUrl: 'https://dav.test/backups',
  username: 'user',
  password: 'secret',
);

/// A `PROPFIND` answer with one folder, two files and one unreadable entry.
const String _propfindAnswer = '''
<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response><D:href>/backups/</D:href><D:propstat><D:prop>
    <D:resourcetype><D:collection/></D:resourcetype>
  </D:prop></D:propstat></D:response>
  <D:response><D:href>/backups/backup2026-10-24.zip</D:href><D:propstat><D:prop>
    <D:getcontentlength>100</D:getcontentlength>
    <D:getlastmodified>Sat, 24 Oct 2026 10:00:00 GMT</D:getlastmodified>
  </D:prop></D:propstat></D:response>
  <D:response><D:href>/backups/backup2026-10-25.zip.enc</D:href><D:propstat><D:prop>
    <D:getcontentlength>200</D:getcontentlength>
    <D:getlastmodified>Sun, 25 Oct 2026 10:00:00 GMT</D:getlastmodified>
  </D:prop></D:propstat></D:response>
  <D:response><D:href>/backups/backup2026-10-23.zip</D:href><D:propstat><D:prop>
    <D:getcontentlength>50</D:getcontentlength>
    <D:getlastmodified>Sun, 25 Oct 2026 10:00:00 GMT</D:getlastmodified>
  </D:prop></D:propstat></D:response>
  <D:response><D:href>/backups/backup2026-10-22.zip</D:href><D:propstat><D:prop>
    <D:getlastmodified>2026-10-22T09:00:00Z</D:getlastmodified>
  </D:prop></D:propstat></D:response>
  <D:response><D:href>/backups/nolength.zip</D:href><D:propstat><D:prop>
    <D:getlastmodified>nonsense</D:getlastmodified>
  </D:prop></D:propstat></D:response>
  <D:response><D:propstat><D:prop></D:prop></D:propstat></D:response>
  <D:response><D:href>/backups/</D:href><D:propstat><D:prop></D:prop></D:propstat></D:response>
</D:multistatus>
''';

ResponseBody _text(String body, [int statusCode = 207]) =>
    ResponseBody.fromString(
      body,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/xml'],
      },
    );

ResponseBody _bytes(List<int> body, [int statusCode = 200]) =>
    ResponseBody.fromBytes(body, statusCode);

DioException _failure(DioExceptionType type, {int? statusCode}) => DioException(
  requestOptions: RequestOptions(path: 'https://dav.test/backups'),
  type: type,
  response: statusCode == null
      ? null
      : Response<dynamic>(
          requestOptions: RequestOptions(path: 'https://dav.test/backups'),
          statusCode: statusCode,
        ),
);

void main() {
  group('DioWebDavClient list', () {
    test('list_givenAPropfindAnswer_answersTheFilesNewestFirst', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async => _text(_propfindAnswer),
      );

      final ParseResult<List<WebDavEntry>> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).list(credentials: _credentials, allowPlainHttp: false);

      final List<WebDavEntry> entries =
          (result as ParseSuccess<List<WebDavEntry>>).data;
      // 同一时间戳的按名字倒序；长度缺失记 0；时间解析不了退回 epoch。
      expect(entries.map((WebDavEntry entry) => entry.name), <String>[
        'backup2026-10-25.zip.enc',
        'backup2026-10-23.zip',
        'backup2026-10-24.zip',
        'backup2026-10-22.zip',
        'nolength.zip',
      ]);
      expect(entries.first.sizeBytes, 200);
      expect(entries.last.sizeBytes, 0);
      expect(entries.last.modifiedAt, DateTime.utc(1970));
      // 目录自身不算备份文件；解析不出 href 的条目被跳过。
      expect(adapter.requests.single.method, 'PROPFIND');
      expect(adapter.requests.single.headers['Depth'], '1');
      expect(
        adapter.requests.single.uri.toString(),
        // 集合地址没有斜杠时补上一个：否则 PROPFIND 的目标是父目录。
        'https://dav.test/backups/',
      );
      expect(
        adapter.requests.single.headers['Authorization'],
        'Basic dXNlcjpzZWNyZXQ=',
      );
    });

    test('list_givenAnUnauthorizedServer_answersForbidden', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.badResponse, statusCode: 401),
      );

      final ParseResult<List<WebDavEntry>> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).list(credentials: _credentials, allowPlainHttp: false);

      expect(
        (result as ParseFailure<List<WebDavEntry>>).kind,
        ParseFailureKind.networkForbidden,
      );
    });

    test('list_givenAMissingCollection_answersNotFound', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.badResponse, statusCode: 404),
      );

      final ParseResult<List<WebDavEntry>> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).list(credentials: _credentials, allowPlainHttp: false);

      expect(
        (result as ParseFailure<List<WebDavEntry>>).kind,
        ParseFailureKind.notFound,
      );
    });

    test('list_givenAServerError_answersNetworkFailed', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.badResponse, statusCode: 500),
      );

      final ParseResult<List<WebDavEntry>> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).list(credentials: _credentials, allowPlainHttp: false);

      expect(
        (result as ParseFailure<List<WebDavEntry>>).kind,
        ParseFailureKind.networkFailed,
      );
    });

    test('list_givenATimeout_answersTimeout', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.connectionTimeout),
      );

      final ParseResult<List<WebDavEntry>> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).list(credentials: _credentials, allowPlainHttp: false);

      expect(
        (result as ParseFailure<List<WebDavEntry>>).kind,
        ParseFailureKind.networkTimeout,
      );
    });

    test('list_givenACancelledRequest_answersCancelled', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.cancel),
      );

      final ParseResult<List<WebDavEntry>> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).list(credentials: _credentials, allowPlainHttp: false);

      expect(
        (result as ParseFailure<List<WebDavEntry>>).kind,
        ParseFailureKind.cancelled,
      );
    });

    test('list_givenAPlainHttpUrlWithoutTheOptIn_refusesIt', () async {
      // C-SEC-2：明文 http 只有用户显式打开 allowPlainHttp 才允许。
      final ParseResult<List<WebDavEntry>> result =
          await DioWebDavClient(
            dio: _dioOf(
              _FakeAdapter((RequestOptions options) async => _text('')),
            ),
          ).list(
            credentials: const WebDavCredentials(
              collectionUrl: 'http://dav.test/backups',
              username: 'u',
              password: 'p',
            ),
            allowPlainHttp: false,
          );

      expect(
        (result as ParseFailure<List<WebDavEntry>>).rulePath,
        'backup.webdav.plainHttp',
      );
    });

    test('list_givenAPlainHttpUrlWithTheOptIn_allowsIt', () async {
      final ParseResult<List<WebDavEntry>> result =
          await DioWebDavClient(
            dio: _dioOf(
              _FakeAdapter((RequestOptions options) async => _text('')),
            ),
          ).list(
            credentials: const WebDavCredentials(
              collectionUrl: 'http://dav.test/backups',
              username: 'u',
              password: 'p',
            ),
            allowPlainHttp: true,
          );

      expect(result, isA<ParseSuccess<List<WebDavEntry>>>());
    });

    test('list_givenAnInvalidUrl_refusesIt', () async {
      final ParseResult<List<WebDavEntry>> result =
          await DioWebDavClient(
            dio: _dioOf(
              _FakeAdapter((RequestOptions options) async => _text('')),
            ),
          ).list(
            credentials: const WebDavCredentials(
              collectionUrl: 'not a url',
              username: 'u',
              password: 'p',
            ),
            allowPlainHttp: true,
          );

      expect(
        (result as ParseFailure<List<WebDavEntry>>).rulePath,
        'backup.webdav.url',
      );
    });
  });

  group('DioWebDavClient upload/download/delete', () {
    test('upload_givenAByteArray_putsItUnderTheCollection', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async => _bytes(<int>[], 201),
      );

      final ParseResult<void> result =
          await DioWebDavClient(dio: _dioOf(adapter)).upload(
            credentials: _credentials,
            allowPlainHttp: false,
            name: 'backup2026-10-25.zip',
            bytes: <int>[1, 2, 3],
          );

      expect(result, isA<ParseSuccess<void>>());
      expect(adapter.requests.single.method, 'PUT');
      expect(
        adapter.requests.single.uri.toString(),
        'https://dav.test/backups/backup2026-10-25.zip',
      );
    });

    test('upload_givenAServerError_answersNetworkFailed', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.badResponse, statusCode: 507),
      );

      final ParseResult<void> result =
          await DioWebDavClient(dio: _dioOf(adapter)).upload(
            credentials: _credentials,
            allowPlainHttp: false,
            name: 'a.zip',
            bytes: <int>[1],
          );

      expect(
        (result as ParseFailure<void>).kind,
        ParseFailureKind.networkFailed,
      );
    });

    test('upload_givenAPlainHttpUrlWithoutTheOptIn_refusesIt', () async {
      final ParseResult<void> result =
          await DioWebDavClient(
            dio: _dioOf(
              _FakeAdapter((RequestOptions options) async => _bytes(<int>[])),
            ),
          ).upload(
            credentials: const WebDavCredentials(
              collectionUrl: 'http://dav.test/backups',
              username: 'u',
              password: 'p',
            ),
            allowPlainHttp: false,
            name: 'a.zip',
            bytes: <int>[1],
          );

      expect(
        (result as ParseFailure<void>).rulePath,
        'backup.webdav.plainHttp',
      );
    });

    test('download_givenAnArchive_answersItsBytes', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async => _bytes(<int>[80, 75, 3, 4]),
      );

      final ParseResult<List<int>> result =
          await DioWebDavClient(dio: _dioOf(adapter)).download(
            credentials: _credentials,
            allowPlainHttp: false,
            name: 'a.zip',
            maxBytes: 10,
          );

      expect((result as ParseSuccess<List<int>>).data, <int>[80, 75, 3, 4]);
      expect(adapter.requests.single.method, 'GET');
    });

    test('download_givenAnOversizedBody_answersTheSizeLimit', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async => _bytes(<int>[1, 2, 3, 4]),
      );

      final ParseResult<List<int>> result =
          await DioWebDavClient(dio: _dioOf(adapter)).download(
            credentials: _credentials,
            allowPlainHttp: false,
            name: 'a.zip',
            maxBytes: 2,
          );

      expect(
        (result as ParseFailure<List<int>>).rulePath,
        'backup.read.sizeLimit',
      );
    });

    test('download_givenAPlainHttpUrlWithoutTheOptIn_refusesIt', () async {
      final ParseResult<List<int>> result =
          await DioWebDavClient(
            dio: _dioOf(
              _FakeAdapter((RequestOptions options) async => _bytes(<int>[])),
            ),
          ).download(
            credentials: const WebDavCredentials(
              collectionUrl: 'http://dav.test/backups',
              username: 'u',
              password: 'p',
            ),
            allowPlainHttp: false,
            name: 'a.zip',
            maxBytes: 10,
          );

      expect(
        (result as ParseFailure<List<int>>).rulePath,
        'backup.webdav.plainHttp',
      );
    });

    test('download_givenAServerError_answersNetworkFailed', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.badResponse, statusCode: 503),
      );

      final ParseResult<List<int>> result =
          await DioWebDavClient(dio: _dioOf(adapter)).download(
            credentials: _credentials,
            allowPlainHttp: false,
            name: 'a.zip',
            maxBytes: 10,
          );

      expect(
        (result as ParseFailure<List<int>>).kind,
        ParseFailureKind.networkFailed,
      );
    });

    test('download_givenAnUnknownDioFailure_answersNetworkFailed', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.unknown),
      );

      final ParseResult<List<int>> result =
          await DioWebDavClient(dio: _dioOf(adapter)).download(
            credentials: _credentials,
            allowPlainHttp: false,
            name: 'a.zip',
            maxBytes: 10,
          );

      expect(
        (result as ParseFailure<List<int>>).kind,
        ParseFailureKind.networkFailed,
      );
    });

    test('delete_givenAFile_deletesIt', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async => _bytes(<int>[], 204),
      );

      final ParseResult<void> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).delete(credentials: _credentials, allowPlainHttp: false, name: 'a.zip');

      expect(result, isA<ParseSuccess<void>>());
      expect(adapter.requests.single.method, 'DELETE');
    });

    test('delete_givenAMissingFile_answersNotFound', () async {
      final _FakeAdapter adapter = _FakeAdapter(
        (RequestOptions options) async =>
            throw _failure(DioExceptionType.badResponse, statusCode: 404),
      );

      final ParseResult<void> result = await DioWebDavClient(
        dio: _dioOf(adapter),
      ).delete(credentials: _credentials, allowPlainHttp: false, name: 'a.zip');

      expect((result as ParseFailure<void>).kind, ParseFailureKind.notFound);
    });

    test('delete_givenAPlainHttpUrlWithoutTheOptIn_refusesIt', () async {
      final ParseResult<void> result =
          await DioWebDavClient(
            dio: _dioOf(
              _FakeAdapter((RequestOptions options) async => _bytes(<int>[])),
            ),
          ).delete(
            credentials: const WebDavCredentials(
              collectionUrl: 'http://dav.test/backups',
              username: 'u',
              password: 'p',
            ),
            allowPlainHttp: false,
            name: 'a.zip',
          );

      expect(
        (result as ParseFailure<void>).rulePath,
        'backup.webdav.plainHttp',
      );
    });
  });
}
