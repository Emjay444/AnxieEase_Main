import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Secure storage for sensitive data
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Shared preferences for non-sensitive settings
  late SharedPreferences _prefs;
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  // Keys
  static const String _rememberMeKey = 'remember_me';
  static const String _emailKey = 'user_email';
  static const String _passwordKey = 'user_password';

  // Initialize shared preferences
  Future<void> init() async {
    // If already initialized, return immediately
    if (_isInitialized) {
      debugPrint('StorageService already initialized');
      return;
    }

    // If initialization is in progress, wait for it to complete
    if (_isInitializing) {
      debugPrint('StorageService initialization in progress, waiting...');
      return _initCompleter.future;
    }

    _isInitializing = true;

    try {
      // Set a timeout for initialization
      await Future.any([
        _initializeStorage(),
        Future.delayed(const Duration(seconds: 2), () {
          debugPrint(
              '⚠️ StorageService initialization timed out, continuing anyway');
          // Don't throw exception, just continue
        })
      ]);

      _isInitialized = true;
      _isInitializing = false;
      _initCompleter.complete();
      debugPrint('✅ StorageService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing StorageService: $e');
      _isInitializing = false;
      _initCompleter.completeError(e);
      // Don't rethrow - allow the app to continue even if storage fails
    }
  }

  Future<void> _initializeStorage() async {
    _prefs = await SharedPreferences.getInstance();
    Logger.debug('StorageService initialized');
  }

  // Remember Me
  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(_rememberMeKey, value);
    Logger.debug('Remember Me set to: $value');

    // If "Remember Me" is turned off, clear stored credentials
    if (!value) {
      await clearCredentials();
    }
  }

  Future<bool> getRememberMe() async {
    return _prefs.getBool(_rememberMeKey) ?? false;
  }

  // Save credentials securely
  Future<void> saveCredentials(String email, String password) async {
    try {
      await _secureStorage.write(key: _emailKey, value: email);
      await _secureStorage.write(key: _passwordKey, value: password);
      Logger.debug('Credentials saved securely');
    } catch (e) {
      Logger.error('Failed to save credentials', e);
    }
  }

  // Retrieve saved credentials
  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final email = await _secureStorage.read(key: _emailKey);
      final password = await _secureStorage.read(key: _passwordKey);
      return {
        'email': email,
        'password': password,
      };
    } catch (e) {
      Logger.error('Failed to retrieve credentials', e);
      return {
        'email': null,
        'password': null,
      };
    }
  }

  // Clear saved credentials
  Future<void> clearCredentials() async {
    try {
      await _secureStorage.delete(key: _emailKey);
      await _secureStorage.delete(key: _passwordKey);
      Logger.debug('Credentials cleared');
    } catch (e) {
      Logger.error('Failed to clear credentials', e);
    }
  }
}
