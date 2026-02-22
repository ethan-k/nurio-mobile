import 'account_summary.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.account,
  });

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final AccountSummary account;

  bool get isAccessTokenExpired =>
      accessTokenExpiresAt.isBefore(DateTime.now().toUtc());

  bool get canRefresh => refreshTokenExpiresAt.isAfter(DateTime.now().toUtc());

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      accessTokenExpiresAt: DateTime.parse(
        json['access_token_expires_at'] as String,
      ).toUtc(),
      refreshToken: json['refresh_token'] as String,
      refreshTokenExpiresAt: DateTime.parse(
        json['refresh_token_expires_at'] as String,
      ).toUtc(),
      account: AccountSummary.fromJson(json['account'] as Map<String, dynamic>),
    );
  }
}
