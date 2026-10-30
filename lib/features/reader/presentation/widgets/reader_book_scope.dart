import 'package:flutter/widgets.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';

/// Publishes the book the reader currently shows to the wrapper that owns the exit guard.
///
/// 换源会把阅读器的 `_book` 换掉；退出时问「要不要加入书架」必须按**新身份**判断，
/// 否则会拿换源前的 URL 再加一本。这个 scope 归 reader 自己的展示层，装配根负责套在页面外。
final class ReaderBookScope extends InheritedWidget {
  /// Publishes [book] to the descendants.
  const ReaderBookScope({required this.book, required super.child, super.key});

  /// The notifier the reader updates after a source switch.
  final ValueNotifier<ReaderBook> book;

  /// The notifier above [context], or `null` when the reader runs without the guard (tests).
  static ValueNotifier<ReaderBook>? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ReaderBookScope>()?.book;

  @override
  bool updateShouldNotify(ReaderBookScope oldWidget) => oldWidget.book != book;
}
