import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_client.dart';
import '../../support/offline_corpus.dart';

void main() {
  group('StateMessage', () {
    testWidgets('build_givenAMessage_centresIt', (WidgetTester tester) async {
      await pumpBookSourcePage(
        tester,
        page: const Scaffold(body: StateMessage(message: 'nothing here')),
        source: null,
        http: FakeHttpClient(),
      );

      expect(find.text('nothing here'), findsOneWidget);
      expect(find.byType(Center), findsWidgets);
    });
  });
}
