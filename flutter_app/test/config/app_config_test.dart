import 'package:flutter_test/flutter_test.dart';
import 'package:nurio_mobile/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('resolves app paths from base host', () {
      final config = AppConfig.fromEnvironment();

      expect(config.baseUri.host, 'nurio.kr');
      expect(config.eventsUri.path, '/events');
      expect(config.profileUri.path, '/settings/profile/edit');
    });

    test('resolves relative uri to configured host', () {
      final config = AppConfig.fromEnvironment();
      final resolved = config.resolveUri(Uri.parse('/orders/new'));

      expect(resolved.host, config.baseUri.host);
      expect(resolved.path, '/orders/new');
    });
  });
}
