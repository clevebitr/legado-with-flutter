import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Hand-written dio adapter double: replays queued outcomes and records the
/// requests it received, so no test touches the network (`docs/dev/testing.md`
/// §4).
///
/// Only dio's public adapter interface is faked; dio internals are never
/// mocked.
final class FakeHttpAdapter implements HttpClientAdapter {
  /// Requests seen by the adapter, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  /// Awaited before the next outcome is delivered, when set.
  ///
  /// The hook lets a test hold requests open and observe how many the client really
  /// has in flight (`docs/dev/book-source.md` §8) without a wall-clock wait: the
  /// request is recorded first, then the hook decides when it may answer.
  Future<void> Function()? onFetch;

  final List<Object> _queue = <Object>[];

  /// Queues a response with [statusCode] and optional raw [bytes].
  void enqueueResponse({
    int statusCode = 200,
    List<int>? bytes,
    Map<String, List<String>>? headers,
  }) {
    _queue.add(
      ResponseBody.fromBytes(
        bytes ?? const <int>[],
        statusCode,
        headers: headers ?? const <String, List<String>>{},
      ),
    );
  }

  /// Queues a failure of [type], optionally with a [statusCode] response.
  void enqueueFailure(DioExceptionType type, {int? statusCode}) {
    _queue.add(_QueuedFailure(type, statusCode));
  }

  /// Queues a redirect the **adapter follows itself**, the way a real one does.
  ///
  /// dio never follows a redirect: `IOHttpClientAdapter` does, and reports the chain back on
  /// `ResponseBody.redirects`. The double mirrors that so a test can pin what the client reads
  /// out of the chain — the final address of a `302` hand-off is the only way a rule learns where
  /// an ASP search moved to (`http_response.dart`).
  void enqueueRedirect({required String location, int statusCode = 302}) {
    _queue.add(_QueuedRedirect(location, statusCode));
  }

  /// Queues a 200 whose **body stream** fails with [type] after one chunk.
  ///
  /// The request itself succeeds and the failure arrives while the body is being read —
  /// which is where dio reports `receiveTimeout` for a slow site (`C-PERF-5` reads bodies as
  /// streams). It is a different code path from [enqueueFailure], which fails the request.
  void enqueueStreamFailure(DioExceptionType type) {
    _queue.add(_QueuedStreamFailure(type));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    final Future<void> Function()? hook = onFetch;
    if (hook != null) {
      await hook();
    }

    final Object next = _queue.isEmpty
        ? ResponseBody.fromBytes(const <int>[], 200)
        : _queue.removeAt(0);

    if (next is _QueuedStreamFailure) {
      final DioException error = DioException(
        requestOptions: options,
        type: next.type,
      );

      final StreamController<Uint8List> body = StreamController<Uint8List>();
      body.add(Uint8List.fromList(<int>[0x7B]));
      scheduleMicrotask(() {
        body.addError(error);
        unawaited(body.close());
      });

      return ResponseBody(body.stream, 200);
    }

    if (next is _QueuedFailure) {
      throw DioException(
        requestOptions: options,
        type: next.type,
        response: next.statusCode == null
            ? null
            : Response<Object?>(
                requestOptions: options,
                statusCode: next.statusCode,
              ),
      );
    }

    if (next is _QueuedRedirect) {
      // 跟随重定向是适配器的职责（dio 只读它报的链）：这里把下一条队列当成结果，
      // 并把这一次跳转放进 `redirects`。
      final Object following = _queue.isEmpty
          ? ResponseBody.fromBytes(const <int>[], 200)
          : _queue.removeAt(0);
      final ResponseBody body = following as ResponseBody;

      return ResponseBody(
        body.stream,
        body.statusCode,
        headers: body.headers,
        isRedirect: true,
        redirects: <RedirectRecord>[
          RedirectRecord(
            next.statusCode,
            options.method,
            Uri.parse(next.location),
          ),
        ],
      );
    }

    return next as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}

/// A queued failure that only surfaces while the response body is read.
final class _QueuedStreamFailure {
  const _QueuedStreamFailure(this.type);

  final DioExceptionType type;
}

/// A queued adapter failure.
final class _QueuedFailure {
  const _QueuedFailure(this.type, this.statusCode);

  final DioExceptionType type;
  final int? statusCode;
}

/// A queued redirect the adapter follows on its own (`ResponseBody.redirects`).
final class _QueuedRedirect {
  const _QueuedRedirect(this.location, this.statusCode);

  final String location;
  final int statusCode;
}
