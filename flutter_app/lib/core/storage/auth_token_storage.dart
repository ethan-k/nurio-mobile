import 'package:shared_preferences/shared_preferences.dart';

class StoredAuthTokens {
  const StoredAuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
}

class AuthTokenStorage {
  static const _accessTokenKey = 'api_access_token';
  static const _refreshTokenKey = 'api_refresh_token';
  static const _accessExpiryKey = 'api_access_expiry_iso8601';
  static const _refreshExpiryKey = 'api_refresh_expiry_iso8601';

  Future<void> save(StoredAuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_accessTokenKey, tokens.accessToken);
    await prefs.setString(_refreshTokenKey, tokens.refreshToken);
    await prefs.setString(
      _accessExpiryKey,
      tokens.accessTokenExpiresAt.toUtc().toIso8601String(),
    );
    await prefs.setString(
      _refreshExpiryKey,
      tokens.refreshTokenExpiresAt.toUtc().toIso8601String(),
    );
  }

  Future<StoredAuthTokens?> read() async {
    final prefs = await SharedPreferences.getInstance();

    final accessToken = prefs.getString(_accessTokenKey);
    final refreshToken = prefs.getString(_refreshTokenKey);
    final accessExpiry = prefs.getString(_accessExpiryKey);
    final refreshExpiry = prefs.getString(_refreshExpiryKey);

    if (accessToken == null ||
        refreshToken == null ||
        accessExpiry == null ||
        refreshExpiry == null) {
      return null;
    }

    final accessTokenExpiresAt = DateTime.tryParse(accessExpiry);
    final refreshTokenExpiresAt = DateTime.tryParse(refreshExpiry);

    if (accessTokenExpiresAt == null || refreshTokenExpiresAt == null) {
      return null;
    }

    return StoredAuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt.toUtc(),
      refreshTokenExpiresAt: refreshTokenExpiresAt.toUtc(),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_accessExpiryKey);
    await prefs.remove(_refreshExpiryKey);
  }
}
