import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_token_storage.dart';
import '../models/account_summary.dart';
import '../models/auth_session.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required AuthTokenStorage storage,
  }) : _apiClient = apiClient,
       _storage = storage;

  final ApiClient _apiClient;
  final AuthTokenStorage _storage;

  Future<AuthSession> login({
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final json = await _apiClient.postJson(
      '/api/v1/auth/login',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'device_id': deviceId,
      },
    );

    final session = AuthSession.fromJson(json);
    _apiClient.accessToken = session.accessToken;

    await _storage.save(
      StoredAuthTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessTokenExpiresAt: session.accessTokenExpiresAt,
        refreshTokenExpiresAt: session.refreshTokenExpiresAt,
      ),
    );

    return session;
  }

  Future<AuthSession?> restoreSession() async {
    final stored = await _storage.read();
    if (stored == null) {
      return null;
    }

    _apiClient.accessToken = stored.accessToken;

    if (stored.accessTokenExpiresAt.isAfter(DateTime.now().toUtc())) {
      final account = await currentAccount();
      if (account == null) {
        return null;
      }

      return AuthSession(
        accessToken: stored.accessToken,
        accessTokenExpiresAt: stored.accessTokenExpiresAt,
        refreshToken: stored.refreshToken,
        refreshTokenExpiresAt: stored.refreshTokenExpiresAt,
        account: account,
      );
    }

    if (stored.refreshTokenExpiresAt.isBefore(DateTime.now().toUtc())) {
      await clearSession();
      return null;
    }

    return refreshSession(stored.refreshToken);
  }

  Future<AuthSession> refreshSession(String refreshToken) async {
    final json = await _apiClient.postJson(
      '/api/v1/auth/refresh',
      body: <String, dynamic>{'refresh_token': refreshToken},
    );

    final session = AuthSession.fromJson(json);
    _apiClient.accessToken = session.accessToken;

    await _storage.save(
      StoredAuthTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        accessTokenExpiresAt: session.accessTokenExpiresAt,
        refreshTokenExpiresAt: session.refreshTokenExpiresAt,
      ),
    );

    return session;
  }

  Future<AccountSummary?> currentAccount() async {
    final json = await _apiClient.getJson(
      '/api/v1/auth/me',
      authenticated: true,
    );

    final accountJson = json['account'];
    if (accountJson is! Map<String, dynamic>) {
      return null;
    }

    return AccountSummary.fromJson(accountJson);
  }

  Future<void> logout({String? refreshToken}) async {
    try {
      await _apiClient.delete('/api/v1/auth/logout', authenticated: true);
    } catch (_) {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.postJson(
          '/api/v1/auth/logout',
          body: <String, dynamic>{'refresh_token': refreshToken},
        );
      }
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    _apiClient.accessToken = null;
    await _storage.clear();
  }
}
