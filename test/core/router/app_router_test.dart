import 'package:flutter/material.dart';
import 'package:flutter_reader/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRouter', () {
    testWidgets('onGenerateRoute_givenAnInitialRoute_buildsThePageOfTheTable', (
      WidgetTester tester,
    ) async {
      const AppRouter router = AppRouter();

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/typed',
          onGenerateRoute: (RouteSettings settings) => router.onGenerateRoute(
            settings,
            pageFor: (Object? arguments) => Text('page:$arguments'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 初始路由没有参数，页面表拿到的就是 `null`（`lib/app.dart` 的回退分支）。
      expect(find.text('page:null'), findsOneWidget);
    });

    testWidgets('push_givenTypedArguments_deliversThemToThePageTable', (
      WidgetTester tester,
    ) async {
      const AppRouter router = AppRouter();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () =>
                  AppRouter.push(context, path: '/typed', arguments: 42),
              child: const Text('go'),
            ),
          ),
          onGenerateRoute: (RouteSettings settings) => router.onGenerateRoute(
            settings,
            pageFor: (Object? arguments) => Text('page:$arguments'),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      // 类型化参数原样到达页面表（ADR-0011 §2），路径由路由对象提供。
      expect(find.text('page:42'), findsOneWidget);
    });

    test('homePath_givenTheLandingRoute_isTheRootPath', () {
      expect(AppRouter.homePath, '/');
    });
  });
}
