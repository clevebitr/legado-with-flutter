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

    return next as ResponseBody;
  }

  @override
  void close({bool force = false}) {}
}

/// A queued adapter failure.
final class _QueuedFailure {
  const _QueuedFailure(this.type, this.statusCode);

  final DioExceptionType type;
  final int? statusCode;
}
