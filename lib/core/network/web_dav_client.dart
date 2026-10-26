import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate, HttpException;

import 'package:dio/dio.dart';
import 'package:flutter_reader/core/error/parse_result.dart';

/// One file in a WebDAV collection (`docs/dev/roadmap.md` M22, ADR-0074 §决策 6).
final class WebDavEntry {
  /// Creates an entry.
  const WebDavEntry({
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  /// The file name (the last path segment of its `href`).
  final String name;

  /// The size the server reported, `0` when it did not say.
  final int sizeBytes;

  /// The modification time the server reported, or the epoch when it did not say.
  final DateTime modifiedAt;
}

/// Where one WebDAV collection lives and how to authenticate against it
/// (`docs/dev/roadmap.md` M22, ADR-0074 §决策 6).
final class WebDavCredentials {
  /// Creates the credentials.
  const WebDavCredentials({
    required this.collectionUrl,
    required this.username,
    required this.password,
  });

  /// The collection URL the backups live in, with or without a trailing slash.
  final String collectionUrl;

  /// The Basic-auth user name.
  final String username;

  /// The Basic-auth password, from the platform key store.
  final String password;
}

/// The four WebDAV actions the backup needs: list, upload, download, delete.
///
/// Nothing else — no book progress sync, no remote book store. Every method answers a [ParseResult]
/// so the page can separate 「没配置」 from 「服务器拒绝」.
abstract interface class WebDavClient {
  /// Lists the files directly inside the collection.
  Future<ParseResult<List<WebDavEntry>>> list({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
  });

  /// Uploads [bytes] as [name] into the collection.
  Future<ParseResult<void>> upload({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
    required List<int> bytes,
  });

  /// Downloads [name] from the collection.
  Future<ParseResult<List<int>>> download({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
    required int maxBytes,
  });

  /// Deletes [name] from the collection.
  Future<ParseResult<void>> delete({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
  });
}

/// [WebDavClient] on top of `dio` (C-NET-1: only `core/network/` may touch the HTTP library).
///
/// The XML of a `PROPFIND` answer is read with a tolerant regular expression on purpose: WebDAV
/// servers spell namespaces differently (`d:`, `D:`, none), and the three values needed here are
/// flat. An entry that cannot be read is skipped instead of failing the whole listing.
final class DioWebDavClient implements WebDavClient {
  /// Creates the client.
  const DioWebDavClient({required this._dio});

  final Dio _dio;

  /// The `PROPFIND` body: exactly the three properties this feature reads.
  static const String _propfindBody =
      '<?xml version="1.0" encoding="utf-8"?>'
      '<d:propfind xmlns:d="DAV:"><d:prop>'
      '<d:getcontentlength/><d:getlastmodified/><d:resourcetype/>'
      '</d:prop></d:propfind>';

  static final RegExp _responsePattern = RegExp(
    r'<[a-zA-Z0-9]*:?response[^>]*>(.*?)</[a-zA-Z0-9]*:?response>',
    dotAll: true,
    caseSensitive: false,
  );
  static final RegExp _hrefPattern = RegExp(
    r'<[a-zA-Z0-9]*:?href[^>]*>(.*?)</[a-zA-Z0-9]*:?href>',
    dotAll: true,
    caseSensitive: false,
  );
  static final RegExp _lengthPattern = RegExp(
    r'<[a-zA-Z0-9]*:?getcontentlength[^>]*>\s*(\d+)\s*<',
    caseSensitive: false,
  );
  static final RegExp _modifiedPattern = RegExp(
    r'<[a-zA-Z0-9]*:?getlastmodified[^>]*>(.*?)<',
    dotAll: true,
    caseSensitive: false,
  );
  static final RegExp _collectionPattern = RegExp(
    r'<[a-zA-Z0-9]*:?collection',
    caseSensitive: false,
  );

  @override
  Future<ParseResult<List<WebDavEntry>>> list({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
  }) async {
    final ParseResult<Uri> uri = _collectionUriOf(credentials, allowPlainHttp);
    if (uri case ParseFailure<Uri>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<List<WebDavEntry>>(kind: kind, rulePath: rulePath);
    }
    final Uri collection = (uri as ParseSuccess<Uri>).data;

    try {
      final Response<String> response = await _dio.request<String>(
        collection.toString(),
        options: Options(
          method: 'PROPFIND',
          headers: <String, Object?>{
            ..._authHeader(credentials),
            'Depth': '1',
            'Content-Type': 'application/xml; charset=utf-8',
          },
          responseType: ResponseType.plain,
        ),
        data: _propfindBody,
      );

      return ParseSuccess<List<WebDavEntry>>(
        _entriesOf(response.data ?? '', collection),
      );
    } on DioException catch (error) {
      return _failureOf<List<WebDavEntry>>(error, 'backup.webdav.list');
    }
  }

  @override
  Future<ParseResult<void>> upload({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
    required List<int> bytes,
  }) async {
    final ParseResult<Uri> target = _fileUriOf(
      credentials,
      name,
      allowPlainHttp,
    );
    if (target case ParseFailure<Uri>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<void>(kind: kind, rulePath: rulePath);
    }

    try {
      await _dio.put<void>(
        (target as ParseSuccess<Uri>).data.toString(),
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: <String, Object?>{
            ..._authHeader(credentials),
            Headers.contentLengthHeader: bytes.length,
            Headers.contentTypeHeader: 'application/octet-stream',
          },
        ),
      );

      return const ParseSuccess<void>(null);
    } on DioException catch (error) {
      return _failureOf<void>(error, 'backup.webdav.upload');
    }
  }

  @override
  Future<ParseResult<List<int>>> download({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
    required int maxBytes,
  }) async {
    final ParseResult<Uri> target = _fileUriOf(
      credentials,
      name,
      allowPlainHttp,
    );
    if (target case ParseFailure<Uri>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<List<int>>(kind: kind, rulePath: rulePath);
    }

    try {
      final Response<List<int>> response = await _dio.get<List<int>>(
        (target as ParseSuccess<Uri>).data.toString(),
        options: Options(
          headers: _authHeader(credentials),
          responseType: ResponseType.bytes,
        ),
      );
      final List<int> body = response.data ?? const <int>[];
      if (body.length > maxBytes) {
        return failureAt<List<int>>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'backup.read.sizeLimit',
        );
      }

      return ParseSuccess<List<int>>(body);
    } on DioException catch (error) {
      return _failureOf<List<int>>(error, 'backup.webdav.download');
    }
  }

  @override
  Future<ParseResult<void>> delete({
    required WebDavCredentials credentials,
    required bool allowPlainHttp,
    required String name,
  }) async {
    final ParseResult<Uri> target = _fileUriOf(
      credentials,
      name,
      allowPlainHttp,
    );
    if (target case ParseFailure<Uri>(
      :final ParseFailureKind kind,
      :final String rulePath,
    )) {
      return failureAt<void>(kind: kind, rulePath: rulePath);
    }

    try {
      await _dio.delete<void>(
        (target as ParseSuccess<Uri>).data.toString(),
        options: Options(headers: _authHeader(credentials)),
      );

      return const ParseSuccess<void>(null);
    } on DioException catch (error) {
      return _failureOf<void>(error, 'backup.webdav.delete');
    }
  }

  Map<String, String> _authHeader(
    WebDavCredentials credentials,
  ) => <String, String>{
    'Authorization':
        'Basic ${base64Encode(utf8.encode('${credentials.username}:${credentials.password}'))}',
  };

  /// [credentials]'s collection, normalised to end with a slash.
  ParseResult<Uri> _collectionUriOf(
    WebDavCredentials credentials,
    bool allowPlainHttp,
  ) {
    final Uri? uri = Uri.tryParse(credentials.collectionUrl.trim());
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      return failureAt<Uri>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'backup.webdav.url',
      );
    }
    if (uri.scheme != 'https' && !(allowPlainHttp && uri.scheme == 'http')) {
      // C-SEC-2：明文 http 只有用户显式打开 allowPlainHttp 才允许。
      return failureAt<Uri>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'backup.webdav.plainHttp',
      );
    }

    final String path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';

    return ParseSuccess<Uri>(uri.replace(path: path));
  }

  ParseResult<Uri> _fileUriOf(
    WebDavCredentials credentials,
    String name,
    bool allowPlainHttp,
  ) {
    final ParseResult<Uri> collection = _collectionUriOf(
      credentials,
      allowPlainHttp,
    );

    return switch (collection) {
      ParseSuccess<Uri>(:final Uri data) => ParseSuccess<Uri>(
        data.replace(path: '${data.path}${Uri.encodeComponent(name)}'),
      ),
      ParseFailure<Uri>(:final ParseFailureKind kind, :final String rulePath) =>
        failureAt<Uri>(kind: kind, rulePath: rulePath),
    };
  }

  /// Reads the entries out of one `PROPFIND` answer.
  List<WebDavEntry> _entriesOf(String xml, Uri collection) {
    final List<WebDavEntry> entries = <WebDavEntry>[];
    for (final RegExpMatch match in _responsePattern.allMatches(xml)) {
      final String block = match.group(1) ?? '';
      if (_collectionPattern.hasMatch(block)) {
        // 目录自身也是一条 response：它不是备份文件。
        continue;
      }
      final String? href = _firstGroup(_hrefPattern, block);
      if (href == null || href.endsWith('/')) {
        // 以斜杠结尾的路径就是集合（目录自身，或者服务器没标 resourcetype 的子目录）。
        continue;
      }
      final String name = Uri.decodeComponent(
        href
            .split('/')
            .lastWhere((String part) => part.isNotEmpty, orElse: () => ''),
      );
      if (name.isEmpty) {
        continue;
      }
      final String? modified = _firstGroup(_modifiedPattern, block);
      entries.add(
        WebDavEntry(
          name: name,
          sizeBytes:
              int.tryParse(_firstGroup(_lengthPattern, block) ?? '') ?? 0,
          modifiedAt:
              _dateOf(modified) ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );
    }
    entries.sort(
      (WebDavEntry a, WebDavEntry b) =>
          b.modifiedAt.compareTo(a.modifiedAt) != 0
          ? b.modifiedAt.compareTo(a.modifiedAt)
          : b.name.compareTo(a.name),
    );

    return entries;
  }

  /// Parses the RFC 1123 date a `PROPFIND` answers with (`Sat, 24 Oct 2026 10:00:00 GMT`).
  ///
  /// `DateTime.tryParse` does not accept that format, which used to make every entry fall back to the
  /// epoch and turn the listing into a name-sorted list. `HttpDate` is the standard parser for it;
  /// `tryParse` stays as the fallback for servers that answer ISO-8601.
  DateTime? _dateOf(String? text) {
    if (text == null) {
      return null;
    }
    try {
      return HttpDate.parse(text).toUtc();
    } on HttpException {
      // 不是 RFC 1123（有的服务器答 ISO-8601）：退回通用解析，仍不行就当没有时间。
      return DateTime.tryParse(text)?.toUtc();
    }
  }

  String? _firstGroup(RegExp pattern, String input) {
    final RegExpMatch? match = pattern.firstMatch(input);

    return match?.group(1)?.trim();
  }

  ParseFailure<T> _failureOf<T>(DioException error, String rulePath) =>
      failureAt<T>(kind: _kindOf(error), rulePath: rulePath, cause: error);

  ParseFailureKind _kindOf(DioException error) => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => ParseFailureKind.networkTimeout,
    DioExceptionType.badResponse => switch (error.response?.statusCode) {
      401 || 403 => ParseFailureKind.networkForbidden,
      404 => ParseFailureKind.notFound,
      _ => ParseFailureKind.networkFailed,
    },
    DioExceptionType.cancel => ParseFailureKind.cancelled,
    _ => ParseFailureKind.networkFailed,
  };
}
