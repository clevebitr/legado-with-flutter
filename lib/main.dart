import 'package:flutter/material.dart';
import 'package:flutter_reader/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application entry point.
void main() {
  runApp(const ProviderScope(child: ReaderApp()));
}
