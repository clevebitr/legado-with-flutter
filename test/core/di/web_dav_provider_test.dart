import 'package:flutter_reader/core/di/web_dav_provider.dart';
import 'package:flutter_reader/core/network/web_dav_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

void main() {
  test('webDavClient_whenRead_answersTheDioClient', () {
    final ProviderContainer container = ProviderContainer.test();

    expect(container.read(webDavClientProvider), isA<DioWebDavClient>());
  });
}
