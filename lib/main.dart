import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application entry point.
void main() {
  runApp(
    ProviderScope(
      // 跨 feature 端口的绑定只发生在装配根（ADR-0041 §决策 2、ADR-0042）。
      overrides: appProviderOverrides(),
      child: const ReaderApp(),
    ),
  );
}
