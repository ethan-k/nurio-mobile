import 'package:flutter_test/flutter_test.dart';
import 'package:nurio_mobile/features/auth/models/auth_session.dart';

void main() {
  test('parses auth session payload', () {
    final payload = <String, dynamic>{
      'access_token': 'access-token',
      'access_token_expires_at': '2026-02-22T10:00:00Z',
      'refresh_token': 'refresh-token',
      'refresh_token_expires_at': '2026-03-22T10:00:00Z',
      'account': {
        'id': 1,
        'email': 'test@example.com',
        'display_name': 'Tester',
      },
    };

    final session = AuthSession.fromJson(payload);

    expect(session.accessToken, 'access-token');
    expect(session.refreshToken, 'refresh-token');
    expect(session.account.displayName, 'Tester');
  });
}
