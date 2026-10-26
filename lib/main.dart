import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application entry point.
///
/// The cookie jar is hydrated **before** `runApp` (ADR-0068 §决策 4): the first request has to see
/// the stored login, and the HTTP client reads the jar synchronously (C-NET-5). It is one awaited
/// call, so bootstrap stays bootstrap: no widget, no route, no business logic.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ProviderContainer container = ProviderContainer(
    // 跨 feature 端口的绑定只发生在装配根（ADR-0041 §决策 2、ADR-0042）。
    overrides: appProviderOverrides(),
  );
  await container.read(cookieManagerProvider).hydrate();

  runApp(
    UncontrolledProviderScope(container: container, child: const ReaderApp()),
  );
}
