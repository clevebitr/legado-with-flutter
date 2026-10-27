import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_reader/core/di/http_client_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/di/preference_store_provider.dart';
import 'package:flutter_reader/core/platform/install_id.dart';
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
  // 安装 id 同理：`java.androidId` 在规则里是同步读的，生成 + 落库必须在第一帧之前完成
  // （M25/S3b；值存在轻量开关里，一次读一次写）。
  await container
      .read(installIdProvider)
      .hydrate(
        PreferenceInstallIdStore(
          await container.read(preferenceStoreProvider.future),
        ),
      );

  runApp(
    UncontrolledProviderScope(container: container, child: const ReaderApp()),
  );
}
