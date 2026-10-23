import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/core/widgets/cover_image.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 1×1 transparent PNG: the smallest image that really decodes.
final Uint8List _tinyPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

/// Bytes that are not an image at all, so the provider reports an error.
final Uint8List _notAnImage = Uint8List.fromList(<int>[1, 2, 3, 4]);

/// Pumps [cover] inside the app theme, the way every list does.
Future<void> _pump(WidgetTester tester, Widget cover) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildReaderTheme(fallbackLightColorScheme()),
      home: Scaffold(body: Center(child: cover)),
    ),
  );
  await tester.pump();
}

void main() {
  group('CoverImage', () {
    testWidgets('CoverImage_givenNoUrl_rendersThePlaceholder', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const CoverImage(url: null, width: 48, height: 64));

      // 占位块自带书本图形；没有 URL 时**不**发起任何图片请求。
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('CoverImage_givenAnEmptyUrl_treatsItLikeNoUrl', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const CoverImage(url: '', width: 48, height: 64));

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets(
      'CoverImage_givenAnImage_paintsItAndStaysSilentForScreenReaders',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pump(
          tester,
          CoverImage(
            url: 'https://covers.test/1.jpg',
            width: 48,
            height: 64,
            image: MemoryImage(_tinyPng),
          ),
        );
        await tester.pumpAndSettle();

        // C-UI-7：封面是装饰，书名就在旁边，读屏不应重复播报一个“图片”。
        expect(
          find.descendant(
            of: find.byType(CoverImage),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );
        // 解出第一帧之后占位图标就让位给图片本身。
        expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('CoverImage_givenUndecodableBytes_fallsBackToThePlaceholder', (
      WidgetTester tester,
    ) async {
      // 站点返回 404 / 一张坏图：与「没有封面」同一个占位，而不是红屏或空白。
      await _pump(
        tester,
        CoverImage(
          url: 'https://covers.test/broken.jpg',
          width: 48,
          height: 64,
          image: MemoryImage(_notAnImage),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('CoverImage_givenASize_keepsIt', (WidgetTester tester) async {
      await _pump(tester, const CoverImage(url: null, width: 40, height: 54));

      final Size size = tester.getSize(find.byType(CoverImage));
      expect(size.width, 40);
      expect(size.height, 54);
    });
  });
}
