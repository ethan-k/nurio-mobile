import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/account_summary.dart';
import '../models/auth_session.dart';

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepository repository})
    : _repository = repository;

  final AuthRepository _repository;

  AuthSession? _session;
  bool _isInitializing = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthSession? get session => _session;
  AccountSummary? get account => _session?.account;
  String? get accessToken => _session?.accessToken;
  bool get isAuthenticated => _session != null;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    notifyListeners();

    try {
      _session = await _repository.restoreSession();
      _errorMessage = null;
    } catch (error) {
      _session = null;
      _errorMessage = error.toString();
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _session = await _repository.login(
        email: email,
        password: password,
        deviceId: _generatedDeviceId(),
      );
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (_session == null) {
      return;
    }

    try {
      final account = await _repository.currentAccount();
      if (account == null) {
        return;
      }

      _session = AuthSession(
        accessToken: _session!.accessToken,
        accessTokenExpiresAt: _session!.accessTokenExpiresAt,
        refreshToken: _session!.refreshToken,
        refreshTokenExpiresAt: _session!.refreshTokenExpiresAt,
        account: account,
      );
      notifyListeners();
    } catch (_) {
      // Keep existing session if profile refresh fails.
    }
  }

  Future<void> logout() async {
    final refreshToken = _session?.refreshToken;
    _session = null;
    _errorMessage = null;
    notifyListeners();

    await _repository.logout(refreshToken: refreshToken);
  }

  String _generatedDeviceId() {
    final random = Random();
    final randomBits = List<int>.generate(12, (_) => random.nextInt(36));

    final buffer = StringBuffer('flutter-');
    for (final value in randomBits) {
      if (value < 10) {
        buffer.write(value);
      } else {
        buffer.writeCharCode(87 + value); // 10 -> 'a'
      }
    }

    return buffer.toString();
  }
}
