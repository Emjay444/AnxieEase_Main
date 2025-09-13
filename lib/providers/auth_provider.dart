import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final StorageService _storageService = StorageService();
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider() {
    // Don't check user immediately - wait for initialization
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    // Wait for Supabase to be initialized first
    await _supabaseService.initialize();

    // Set up authentication state listener before checking current user
    _setupAuthListener();

    // Wait a bit longer for Supabase to fully restore any existing session
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      // Check if there's a session available before manual check
      final currentSession = _supabaseService.client.auth.currentSession;
      if (currentSession != null) {
        debugPrint(
            '📱 Session found during initialization, skipping manual check');
        // Let the auth listener handle the session restoration
      } else {
        debugPrint('📱 No session found, performing manual check');
        await _checkCurrentUser();
      }
    } catch (e) {
      debugPrint('Error during provider initialization: $e');
    } finally {
      _isInitialized = true;
      notifyListeners(); // Notify that initialization is complete
    }
  }

  void _setupAuthListener() {
    try {
      debugPrint('🔧 Setting up auth state listener...');
      _authSubscription = _supabaseService.client.auth.onAuthStateChange.listen(
        (AuthState data) {
          debugPrint('🔔 Auth state changed: ${data.event}');
          debugPrint('🔔 Session exists: ${data.session != null}');
          debugPrint('🔔 User exists: ${data.session?.user != null}');

          switch (data.event) {
            case AuthChangeEvent.signedIn:
              debugPrint('✅ User signed in: ${data.session?.user.id}');
              _handleSignIn(data.session?.user);
              break;
            case AuthChangeEvent.signedOut:
              debugPrint('❌ User signed out');
              _handleSignOut();
              break;
            case AuthChangeEvent.tokenRefreshed:
              debugPrint(
                  '🔄 Token refreshed for user: ${data.session?.user.email}');
              // Token refresh doesn't require action, just log it
              break;
            case AuthChangeEvent.userUpdated:
              debugPrint('👤 User updated');
              if (data.session?.user != null) {
                _handleUserUpdate(data.session!.user);
              }
              break;
            case AuthChangeEvent.passwordRecovery:
              debugPrint('🔑 Password recovery initiated');
              break;
            case AuthChangeEvent.initialSession:
              debugPrint(
                  '🚀 Initial session restored: ${data.session?.user.email}');
              // This is fired when the app starts and finds an existing session
              if (data.session?.user != null) {
                debugPrint('📱 Processing initial session restoration...');
                _handleSignIn(data.session?.user);
              } else {
                debugPrint('📱 Initial session event but no session data');
              }
              break;
            default:
              debugPrint('🔄 Other auth event: ${data.event}');
          }
        },
        onError: (error) {
          debugPrint('❌ Auth state listener error: $error');
        },
      );
      debugPrint('✅ Auth state listener setup complete');
    } catch (e) {
      debugPrint('❌ Error setting up auth listener: $e');
    }
  }

  Future<void> _handleSignIn(User? user) async {
    if (user != null) {
      try {
        _setLoading(true);
        final userProfile = await _supabaseService.getUserProfile();
        if (userProfile != null) {
          // Ensure required fields exist (email may not be in user_profiles)
        final enriched = Map<String, dynamic>.from(userProfile);
        enriched['email'] ??=
            _supabaseService.client.auth.currentUser?.email ?? '';
        // If first_name is missing but full_name exists, derive first_name
        if ((enriched['first_name'] == null ||
                (enriched['first_name'] is String &&
                    (enriched['first_name'] as String).trim().isEmpty)) &&
            enriched['full_name'] is String &&
            (enriched['full_name'] as String).trim().isNotEmpty) {
          final parts = (enriched['full_name'] as String).trim().split(' ');
          if (parts.isNotEmpty) enriched['first_name'] = parts.first;
        }
        // created_at/updated_at should exist but set sane defaults if missing
        enriched['created_at'] ??= DateTime.now().toIso8601String();
        enriched['updated_at'] ??= DateTime.now().toIso8601String();
        // Ensure avatar_url is included
        enriched['avatar_url'] ??= userProfile['avatar_url'];          _currentUser = UserModel.fromJson(enriched);
          debugPrint(
              '✅ User profile loaded after sign in: ${_currentUser?.firstName}');
        }
      } catch (e) {
        debugPrint('❌ Error loading user profile after sign in: $e');
      } finally {
        _setLoading(false);
      }

      // Always notify listeners after handling sign in
      notifyListeners();
    }
  }

  void _handleSignOut() {
    _currentUser = null;
    debugPrint('🧹 User data cleared after sign out');
    notifyListeners();
  }

  Future<void> _handleUserUpdate(User user) async {
    // Reload user profile when user data is updated
    if (isAuthenticated) {
      try {
        final userProfile = await _supabaseService.getUserProfile();
        if (userProfile != null) {
          final enriched = Map<String, dynamic>.from(userProfile);
          enriched['email'] ??=
              _supabaseService.client.auth.currentUser?.email ?? '';
          // If first_name is missing but full_name exists, derive first_name
          if ((enriched['first_name'] == null ||
                  (enriched['first_name'] is String &&
                      (enriched['first_name'] as String).trim().isEmpty)) &&
              enriched['full_name'] is String &&
              (enriched['full_name'] as String).trim().isNotEmpty) {
            final parts = (enriched['full_name'] as String).trim().split(' ');
            if (parts.isNotEmpty) enriched['first_name'] = parts.first;
          }
          enriched['created_at'] ??= DateTime.now().toIso8601String();
          enriched['updated_at'] ??= DateTime.now().toIso8601String();
          // Ensure avatar_url is included
          enriched['avatar_url'] ??= userProfile['avatar_url'];

          _currentUser = UserModel.fromJson(enriched);
          debugPrint('✅ User profile updated: ${_currentUser?.firstName}');
          notifyListeners();
        }
      } catch (e) {
        debugPrint('❌ Error updating user profile: $e');
      }
    }
  }

  Future<void> _checkCurrentUser() async {
    try {
      debugPrint('🔍 AuthProvider - Starting _checkCurrentUser...');

      // First check if we have a Supabase session
      final currentSession = _supabaseService.client.auth.currentSession;
      debugPrint(
          '🔍 AuthProvider - Current session: ${currentSession != null ? 'Found' : 'None'}');

      if (currentSession != null) {
        debugPrint(
            '🔍 AuthProvider - Session user: ${currentSession.user.email}');
        debugPrint(
            '🔍 AuthProvider - Session expires: ${currentSession.expiresAt}');
      }

      final isAuth = _supabaseService.isAuthenticated;
      debugPrint('🔍 AuthProvider - _checkCurrentUser: isAuth = $isAuth');

      if (isAuth) {
        _setLoading(true);
        try {
          final userProfile = await _supabaseService.getUserProfile();
          debugPrint(
              '🔍 AuthProvider - getUserProfile result: ${userProfile != null ? 'Found' : 'null'}');

          if (userProfile != null) {
            final enriched = Map<String, dynamic>.from(userProfile);
            enriched['email'] ??=
                _supabaseService.client.auth.currentUser?.email ?? '';
            // If first_name is missing but full_name exists, derive first_name
            if ((enriched['first_name'] == null ||
                    (enriched['first_name'] is String &&
                        (enriched['first_name'] as String).trim().isEmpty)) &&
                enriched['full_name'] is String &&
                (enriched['full_name'] as String).trim().isNotEmpty) {
              final parts = (enriched['full_name'] as String).trim().split(' ');
              if (parts.isNotEmpty) enriched['first_name'] = parts.first;
            }
            enriched['created_at'] ??= DateTime.now().toIso8601String();
            enriched['updated_at'] ??= DateTime.now().toIso8601String();
            // Ensure avatar_url is included
            enriched['avatar_url'] ??= userProfile['avatar_url'];

            _currentUser = UserModel.fromJson(enriched);
            debugPrint(
                '✅ AuthProvider - User loaded: ${_currentUser?.firstName}');
          } else {
            debugPrint(
                '❌ AuthProvider - No user profile found despite authentication');
          }
        } catch (e) {
          debugPrint('❌ AuthProvider - Error loading user profile: $e');
        } finally {
          _setLoading(false);
        }
      } else {
        // Clear any existing state if not authenticated
        _currentUser = null;
        debugPrint(
            '❌ AuthProvider - User not authenticated, cleared currentUser');
      }

      // Always notify listeners after checking current user
      debugPrint('🔔 AuthProvider - Notifying listeners of state change');
      debugPrint(
          '🔔 AuthProvider - Final auth state: isAuth=$isAuth, hasUser=${_currentUser != null}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      // Still notify listeners even on error to prevent the app from being stuck
      notifyListeners();
    }
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  bool get isAuthenticated {
    try {
      return _supabaseService.isAuthenticated;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? birthDate,
    String? contactNumber,
    String? emergencyContact,
    String? gender,
  }) async {
    try {
      _setLoading(true);

      final userData = {
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'birth_date': birthDate?.toIso8601String(),
        'contact_number': contactNumber,
        'emergency_contact': emergencyContact,
        'gender': gender,
      };

      await _supabaseService.signUp(
        email: email,
        password: password,
        userData: userData,
      );

      // Note: SignUp automatically signs out after registration for email verification
      // The auth state listener will handle any state changes
      debugPrint('✅ Sign up successful, check email for verification');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);

      await _supabaseService.signIn(
        email: email,
        password: password,
      );

      // The auth state listener will handle loading the user profile
      // So we don't need to manually do it here
      debugPrint(
          '✅ Sign in successful, auth listener will handle user profile loading');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    // Prevent multiple simultaneous sign out attempts
    if (_isLoading) {
      debugPrint('⚠️ Sign out already in progress, ignoring duplicate request');
      return;
    }

    try {
      _setLoading(true);
      debugPrint('🔄 Starting sign out process...');

      // Clear stored credentials
      await _storageService.clearCredentials();

      // Sign out from Supabase
      await _supabaseService.signOut();

      // The auth state listener will handle clearing the user data
      debugPrint('✅ Sign out initiated, auth listener will handle cleanup');
    } catch (e) {
      debugPrint('❌ Error during sign out: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      _setLoading(true);
      await _supabaseService.resetPassword(email);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? middleName,
    String? lastName,
    DateTime? birthDate,
    String? contactNumber,
    String? emergencyContact,
    String? gender,
  }) async {
    try {
      _setLoading(true);

      final updates = {
        if (firstName != null) 'first_name': firstName,
        if (middleName != null) 'middle_name': middleName,
        if (lastName != null) 'last_name': lastName,
        if (birthDate != null) 'birth_date': birthDate.toIso8601String(),
        if (contactNumber != null) 'contact_number': contactNumber,
        if (emergencyContact != null) 'emergency_contact': emergencyContact,
        if (gender != null) 'gender': gender,
      };

      // Update the profile fields
      await _supabaseService.updateUserProfile(updates);

      final userProfile = await _supabaseService.getUserProfile();
      if (userProfile != null) {
        final enriched = Map<String, dynamic>.from(userProfile);
        enriched['email'] ??=
            _supabaseService.client.auth.currentUser?.email ?? '';
        // If first_name is missing but full_name exists, derive first_name
        if ((enriched['first_name'] == null ||
                (enriched['first_name'] is String &&
                    (enriched['first_name'] as String).trim().isEmpty)) &&
            enriched['full_name'] is String &&
            (enriched['full_name'] as String).trim().isNotEmpty) {
          final parts = (enriched['full_name'] as String).trim().split(' ');
          if (parts.isNotEmpty) enriched['first_name'] = parts.first;
        }
        enriched['created_at'] ??= DateTime.now().toIso8601String();
        enriched['updated_at'] ??= DateTime.now().toIso8601String();
        // Ensure avatar_url is included
        enriched['avatar_url'] ??= userProfile['avatar_url'];

        _currentUser = UserModel.fromJson(enriched);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Error updating profile: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    if (_currentUser == null) {
      throw Exception('No user authenticated');
    }

    try {
      _setLoading(true);
      
      // Upload the avatar to Supabase storage
      final avatarUrl = await _supabaseService.uploadUserAvatar(_currentUser!.id, imageFile);
      
      if (avatarUrl != null) {
        // Reload the user profile to get the updated avatar URL
        await loadUserProfile();
      }
      
      return avatarUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      throw Exception('Error uploading avatar: $e');
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadUserProfile() async {
    if (!isAuthenticated) return;

    try {
      _setLoading(true);
      final userProfile = await _supabaseService.getUserProfile();
      if (userProfile != null) {
        final enriched = Map<String, dynamic>.from(userProfile);
        enriched['email'] ??=
            _supabaseService.client.auth.currentUser?.email ?? '';
        // If first_name is missing but full_name exists, derive first_name
        if ((enriched['first_name'] == null ||
                (enriched['first_name'] is String &&
                    (enriched['first_name'] as String).trim().isEmpty)) &&
            enriched['full_name'] is String &&
            (enriched['full_name'] as String).trim().isNotEmpty) {
          final parts = (enriched['full_name'] as String).trim().split(' ');
          if (parts.isNotEmpty) enriched['first_name'] = parts.first;
        }
        enriched['created_at'] ??= DateTime.now().toIso8601String();
        enriched['updated_at'] ??= DateTime.now().toIso8601String();
        // Ensure avatar_url is included
        enriched['avatar_url'] ??= userProfile['avatar_url'];

        _currentUser = UserModel.fromJson(enriched);
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }
}
