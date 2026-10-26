import 'package:dio/dio.dart';
import 'package:flutter_reader/core/network/web_dav_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'web_dav_provider.g.dart';

/// Provides the WebDAV client the backup feature uploads to (`ADR-0074` §决策 6).
///
/// Its own `Dio` instance rather than `httpClientProvider`: the page-fetching client carries charset
/// detection, per-source budgets and rule headers, none of which apply to a WebDAV collection, and
/// its timeouts are tuned for reading pages. Auth and the plaintext switch are passed per call.
@Riverpod(keepAlive: true)
WebDavClient webDavClient(Ref ref) => DioWebDavClient(
  dio: Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 2),
      // 3xx 由调用方看见（PROPFIND 的目标是一个确定的目录）：不自动跟随，避免把 PUT 变成 GET。
      followRedirects: false,
    ),
  ),
);
