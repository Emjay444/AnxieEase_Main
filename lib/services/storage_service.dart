import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';
import 'dart:async';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  static const String _rememberMeKey = 'remember_me';
  static const String _emailKey = 'user_email';
  static const String _passwordKey = 'user_password';

  Future<void> init() async {
    if (_isInitialized) {
      AppLogger.d('StorageService already initialized');
      return;
    }

    if (_isInitializing) {
      AppLogger.d('StorageService initialization in progress, waiting...');
      return _initCompleter.future;
    }

    _isInitializing = true;

    try {
      await _initializeStorage();
      _isInitialized = true;
      _isInitializing = false;
      _initCompleter.complete();
      AppLogger.d('StorageService initialized successfully');
    } catch (e) {
      _isInitializing = false;
      _initCompleter.completeError(e);
      AppLogger.e('Error initializing StorageService', e);
    }
  }

  Future<void> _initializeStorage() async {
    _prefs = await SharedPreferences.getInstance();
    AppLogger.d('StorageService preferences loaded');
  }

  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(_rememberMeKey, value);
    AppLogger.d('StorageService - Remember Me set to: $value');

    if (!value) {
      await clearCredentials();
      AppLogger.d(
          'StorageService - Credentials cleared because Remember Me was disabled');
    } else {
      AppLogger.d(
          'StorageService - Credentials preserved because Remember Me is enabled');
    }
  }

  Future<bool> getRememberMe() async {
    final value = _prefs.getBool(_rememberMeKey) ?? false;
    AppLogger.d('StorageService - getRememberMe() returning: $value');
    return value;
  }

  Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      AppLogger.d('Credentials saved securely');
    } catch (e) {
      AppLogger.e('Failed to save credentials', e);
    }
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      AppLogger.d(
          'StorageService - Retrieved credentials: email=${email != null ? '[saved]' : 'null'}, password=${password != null ? '[saved]' : 'null'}');

      return {
        'email': email,
        'password': password,
      };
    } catch (e) {
      AppLogger.e('Failed to retrieve credentials', e);
      return {
        'email': null,
        'password': null,
      };
    }
  }

  Future<void> clearCredentials() async {
    try {
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _passwordKey);
      AppLogger.d('Credentials cleared');
    } catch (e) {
      AppLogger.e('Failed to clear credentials', e);
    }
  }
}
