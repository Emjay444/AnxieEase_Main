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
        debugPrint('🔐 Handling sign in for user: ${user.email}');

        // Add timeout to prevent indefinite loading
        final profileData = await Future.any([
          _loadUserProfileWithRecovery(user),
          Future.delayed(const Duration(seconds: 10),
              () => throw TimeoutException('Profile loading timed out')),
        ]);

        if (profileData != null) {
          _currentUser = profileData;
          debugPrint(
              '✅ User profile loaded successfully: ${_currentUser?.firstName} ${_currentUser?.lastName}');
        } else {
          debugPrint('❌ Failed to load user profile after all attempts');
          // Don't sign out immediately, give user a chance to retry
          _currentUser = null;
        }
      } catch (e) {
        if (e is TimeoutException) {
          debugPrint('⏰ Profile loading timed out after 10 seconds');
        } else {
          debugPrint('❌ Error loading user profile after sign in: $e');
        }
        // Create a minimal user object from auth data as fallback
        final authMetadata = user.userMetadata ?? {};
        debugPrint(
            '🔄 Creating fallback user from auth metadata: $authMetadata');

        // Try multiple ways to get the name
        String firstName = '';
        String lastName = '';

        // Strategy 1: Direct from metadata
        firstName = authMetadata['first_name']?.toString() ?? '';
        lastName = authMetadata['last_name']?.toString() ?? '';

        // Strategy 2: If firstName is empty, try other metadata fields
        if (firstName.isEmpty) {
          firstName = authMetadata['given_name']?.toString() ?? '';
        }
        if (lastName.isEmpty) {
          lastName = authMetadata['family_name']?.toString() ?? '';
        }

        // Strategy 3: Try full_name and split it
        if (firstName.isEmpty && lastName.isEmpty) {
          final fullName = authMetadata['full_name']?.toString() ?? '';
          if (fullName.isNotEmpty) {
            final parts = fullName.trim().split(' ');
            if (parts.isNotEmpty) {
              firstName = parts.first;
              if (parts.length > 1) {
                lastName = parts.skip(1).join(' ');
              }
            }
          }
        }

        // Strategy 4: Extract from email as last resort
        if (firstName.isEmpty && user.email != null && user.email!.isNotEmpty) {
          final emailParts = user.email!.split('@');
          if (emailParts.isNotEmpty && emailParts.first.isNotEmpty) {
            firstName = emailParts.first
                .replaceAll('.', ' ')
                .split(' ')
                .map((word) => word.isNotEmpty
                    ? word[0].toUpperCase() + word.substring(1).toLowerCase()
                    : '')
                .join(' ');
          }
        }

        _currentUser = UserModel(
          id: user.id,
          email: user.email ?? '',
          firstName: firstName,
          lastName: lastName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        debugPrint(
            '🔄 Created fallback user: ${_currentUser?.firstName} ${_currentUser?.lastName} (${_currentUser?.email})');

        // Try to create the missing profile in the database for future use
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            debugPrint(
                '🔄 Attempting to create missing profile in background...');
            await _supabaseService.client.from('user_profiles').upsert({
              'id': user.id,
              'email': user.email ?? '',
              'first_name': firstName,
              'last_name': lastName,
              'role': 'patient',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'is_email_verified': user.emailConfirmedAt != null,
              'assigned_psychologist_id': null,
            });
            debugPrint('✅ Background profile creation successful');
          } catch (e) {
            debugPrint('❌ Background profile creation failed: $e');
          }
        });

        debugPrint(
            '🔄 Created fallback user object to prevent "Guest" display');
      } finally {
        _setLoading(false);
      }

      // Always notify listeners after handling sign in
      notifyListeners();
    }
  }

  // Helper method to load user profile with recovery attempts
  Future<UserModel?> _loadUserProfileWithRecovery(User user) async {
    try {
      final userProfile = await _supabaseService.getUserProfile();
      if (userProfile != null) {
        debugPrint('✅ Found existing user profile for: ${user.email}');
        // Ensure required fields exist (email may not be in user_profiles)
        final enriched = Map<String, dynamic>.from(userProfile);
        enriched['email'] ??= user.email ?? '';
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
        enriched['avatar_url'] ??= userProfile['avatar_url'];
        return UserModel.fromJson(enriched);
      } else {
        debugPrint(
            '❌ User profile missing after sign in - attempting recovery...');

        // Try to recover from pending user data first (from failed signup)
        if (await _tryCreateProfileFromPendingData(user)) {
          debugPrint('✅ Profile recovered from pending data');
          final newProfile = await _supabaseService.getUserProfile();
          if (newProfile != null) {
            final enriched = Map<String, dynamic>.from(newProfile);
            enriched['email'] ??= user.email ?? '';
            enriched['created_at'] ??= DateTime.now().toIso8601String();
            enriched['updated_at'] ??= DateTime.now().toIso8601String();
            enriched['avatar_url'] ??= newProfile['avatar_url'];
            return UserModel.fromJson(enriched);
          }
        } else if (await _tryCreateProfileFromAuthMetadata(user)) {
          debugPrint('✅ Profile created from auth metadata');
          final newProfile = await _supabaseService.getUserProfile();
          if (newProfile != null) {
            final enriched = Map<String, dynamic>.from(newProfile);
            enriched['email'] ??= user.email ?? '';
            enriched['created_at'] ??= DateTime.now().toIso8601String();
            enriched['updated_at'] ??= DateTime.now().toIso8601String();
            enriched['avatar_url'] ??= newProfile['avatar_url'];
            return UserModel.fromJson(enriched);
          }
        } else {
          debugPrint('❌ All profile recovery attempts failed');
          return null;
        }
      }
    } catch (e) {
      debugPrint('❌ Error in _loadUserProfileWithRecovery: $e');
      return null;
    }
    return null;
  }

  // Helper method to try creating profile from pending data
  Future<bool> _tryCreateProfileFromPendingData(User user) async {
    try {
      debugPrint('🔄 Attempting to create profile from pending data...');
      final success =
          await _supabaseService.createProfileFromPendingData(user.id);

      if (success) {
        // Try to load the newly created profile
        final newProfile = await _supabaseService.getUserProfile();
        if (newProfile != null) {
          final enriched = Map<String, dynamic>.from(newProfile);
          enriched['email'] ??= user.email ?? '';
          enriched['created_at'] ??= DateTime.now().toIso8601String();
          enriched['updated_at'] ??= DateTime.now().toIso8601String();
          enriched['avatar_url'] ??= newProfile['avatar_url'];
          _currentUser = UserModel.fromJson(enriched);
          debugPrint(
              '✅ Profile created from pending data: ${_currentUser?.firstName} ${_currentUser?.lastName}');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to create profile from pending data: $e');
      return false;
    }
  }

  // Helper method to try creating profile from auth metadata
  Future<bool> _tryCreateProfileFromAuthMetadata(User user) async {
    try {
      debugPrint('🔄 Attempting to create profile from auth metadata...');
      final metadata = user.userMetadata ?? {};
      debugPrint('📋 Auth metadata available: $metadata');

      await _supabaseService.client.from('user_profiles').upsert({
        'id': user.id,
        'email': user.email ?? '',
        'first_name': metadata['first_name'] ?? '',
        'middle_name': metadata['middle_name'] ?? '',
        'last_name': metadata['last_name'] ?? '',
        'role': 'patient',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'is_email_verified': user.emailConfirmedAt != null,
        'assigned_psychologist_id': null, // Explicitly set to null
      });

      // Try to load the newly created profile
      final newProfile = await _supabaseService.getUserProfile();
      if (newProfile != null) {
        final enriched = Map<String, dynamic>.from(newProfile);
        enriched['email'] ??= user.email ?? '';
        enriched['created_at'] ??= DateTime.now().toIso8601String();
        enriched['updated_at'] ??= DateTime.now().toIso8601String();
        enriched['avatar_url'] ??= newProfile['avatar_url'];
        _currentUser = UserModel.fromJson(enriched);
        debugPrint(
            '✅ Profile created from auth metadata: ${_currentUser?.firstName} ${_currentUser?.lastName}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Failed to create profile from auth metadata: $e');
      return false;
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
        } else {
          debugPrint('❌ User profile missing during update - signing out...');
          // Sign out if we have auth but no profile (corrupted state)
          await _supabaseService.signOut();
          // Only clear credentials if "Remember Me" is disabled
          final rememberMe = await _storageService.getRememberMe();
          if (!rememberMe) {
            await _storageService.clearCredentials();
          }
          _currentUser = null;
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
            debugPrint(
                '🔄 AuthProvider - Signing out due to missing profile...');
            // Sign out if we have auth but no profile (corrupted state)
            await _supabaseService.signOut();
            // Only clear credentials if "Remember Me" is disabled
            final rememberMe = await _storageService.getRememberMe();
            if (!rememberMe) {
              await _storageService.clearCredentials();
            }
            _currentUser = null;
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

      // Only clear stored credentials if "Remember Me" is disabled
      final rememberMe = await _storageService.getRememberMe();
      if (!rememberMe) {
        await _storageService.clearCredentials();
        debugPrint('🧹 Credentials cleared (Remember Me is disabled)');
      } else {
        debugPrint('💾 Credentials preserved (Remember Me is enabled)');
      }

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

  Future<void> resendVerificationEmail(String email) async {
    try {
      await _supabaseService.resendVerificationEmail(email);
    } catch (e) {
      rethrow;
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
    String? avatarUrl,
    bool removeAvatar = false,
  }) async {
    try {
      _setLoading(true);

      // If we're explicitly removing the avatar, update local state immediately
      if (removeAvatar && _currentUser != null) {
        // Evict previous avatar image from cache (targeted)
        if (_currentUser!.avatarUrl != null &&
            _currentUser!.avatarUrl!.isNotEmpty) {
          try {
            NetworkImage(_currentUser!.avatarUrl!).evict();
          } catch (_) {}
        }
        _currentUser = _currentUser!.copyWith(avatarUrl: null);
        notifyListeners();
      }

      final updates = {
        if (firstName != null) 'first_name': firstName,
        if (middleName != null) 'middle_name': middleName,
        if (lastName != null) 'last_name': lastName,
        if (birthDate != null) 'birth_date': birthDate.toIso8601String(),
        if (contactNumber != null) 'contact_number': contactNumber,
        if (emergencyContact != null) 'emergency_contact': emergencyContact,
        if (gender != null) 'gender': gender,
        // If a new avatarUrl is provided, set it; if explicitly removing, set to null
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (avatarUrl == null && removeAvatar) 'avatar_url': null,
      };

      // Update the profile fields
      await _supabaseService.updateUserProfile(updates);

      // Targeted cache eviction for avatar changes only
      if (_currentUser?.avatarUrl != null) {
        try {
          NetworkImage(_currentUser!.avatarUrl!).evict();
        } catch (e) {
          debugPrint('Error evicting previous avatar from cache: $e');
        }
      }

      // Optimistic local update for faster UI feedback
      if (_currentUser != null) {
        if (avatarUrl != null) {
          _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);
        } else if (removeAvatar) {
          _currentUser = _currentUser!.copyWith(avatarUrl: null);
        } else {
          // Keep existing avatar
        }
        notifyListeners();
      }

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
      final avatarUrl =
          await _supabaseService.uploadUserAvatar(_currentUser!.id, imageFile);

      if (avatarUrl != null) {
        // Try to evict old avatar image if it exists (targeted clearing)
        if (_currentUser?.avatarUrl != null &&
            _currentUser!.avatarUrl!.isNotEmpty) {
          try {
            NetworkImage(_currentUser!.avatarUrl!).evict();
          } catch (e) {
            debugPrint('Error evicting old avatar: $e');
          }
        }

        // Immediately update the current user with the new avatar URL
        _currentUser = _currentUser!.copyWith(avatarUrl: avatarUrl);

        // Trigger immediate UI refresh
        notifyListeners();

        // Also reload the user profile to ensure consistency
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
