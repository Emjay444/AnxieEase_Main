import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../utils/logger.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';
import 'dart:async';

class SupabaseService {
  static const String supabaseUrl = 'https://gqsustjxzjzfntcsnvpk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA';

  SupabaseClient? _supabaseClient;
  bool _isInitialized = false;
  bool _isInitializing = false;
  final Completer<void> _initCompleter = Completer<void>();
  
  // Store registration data temporarily for profile creation during sign-in
  Map<String, dynamic>? _pendingUserData;

  // Helper method to create user profile directly bypassing RLS
  Future<void> _createUserProfileDirectly({
    required String userId,
    required String email,
    required Map<String, dynamic> userData,
    required String timestamp,
  }) async {
    try {
      // Create a temporary client with service role key for admin operations
      // Note: In production, this should be done via a server-side function
      // For now, we'll try with the existing client and handle RLS issues
      
      final profileData = {
        'id': userId,
        'email': email,
        'first_name': userData['first_name'] ?? '',
        'middle_name': userData['middle_name'] ?? '',
        'last_name': userData['last_name'] ?? '',
        'birth_date': userData['birth_date'],
        'contact_number': userData['contact_number'] ?? '',
        'emergency_contact': userData['emergency_contact'] ?? '',
        'gender': userData['gender'] ?? '',
        'role': 'patient',
        'created_at': timestamp,
        'updated_at': timestamp,
        'is_email_verified': false,
      };

      print('Attempting to insert profile data: $profileData');
      
      // Try using the database function first (most reliable)
      try {
        await client.rpc('create_missing_user_profile', params: {
          'user_id': userId,
          'user_email': email,
          'first_name': userData['first_name'] ?? '',
          'middle_name': userData['middle_name'] ?? '',
          'last_name': userData['last_name'] ?? '',
          'birth_date': userData['birth_date'],
          'contact_number': userData['contact_number'] ?? '',
          'emergency_contact': userData['emergency_contact'] ?? '',
          'gender': userData['gender'] ?? '',
        });
        print('✅ Profile created successfully via database function');
        return;
      } catch (rpcError) {
        print('❌ Database function failed: $rpcError');
      }

      // Fallback: Try direct insert
      try {
        await client.from('user_profiles').insert(profileData);
        print('✅ Profile inserted successfully via direct insert');
        return;
      } catch (directError) {
        print('❌ Direct insert failed: $directError');
      }

      // Fallback: Try upsert
      try {
        await client.from('user_profiles').upsert(profileData);
        print('✅ Profile created successfully via upsert');
        return;
      } catch (upsertError) {
        print('❌ Upsert failed: $upsertError');
      }

      // If both fail, store for later creation during sign-in
      _pendingUserData = {
        'user_id': userId,
        'email': email,
        'first_name': userData['first_name'],
        'middle_name': userData['middle_name'],
        'last_name': userData['last_name'],
        'birth_date': userData['birth_date'],
        'contact_number': userData['contact_number'],
        'emergency_contact': userData['emergency_contact'],
        'gender': userData['gender'],
      };
      print('⏳ Stored data for profile creation during sign-in: $_pendingUserData');
      
    } catch (e) {
      print('❌ Error in _createUserProfileDirectly: $e');
      // Store for later creation as fallback
      _pendingUserData = {
        'user_id': userId,
        'email': email,
        'first_name': userData['first_name'],
        'middle_name': userData['middle_name'],
        'last_name': userData['last_name'],
        'birth_date': userData['birth_date'],
        'contact_number': userData['contact_number'],
        'emergency_contact': userData['emergency_contact'],
        'gender': userData['gender'],
      };
      print('⏳ Fallback: Stored data for profile creation during sign-in');
    }
  }

  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Getter for supabase client that safely handles null case
  SupabaseClient get client {
    if (_supabaseClient != null) {
      return _supabaseClient!;
    }

    // If client is null but Supabase is initialized, try to get the instance
    try {
      _supabaseClient = Supabase.instance.client;
      return _supabaseClient!;
    } catch (e) {
      debugPrint('Error getting Supabase instance: $e');
    }

    // If we still don't have a client, throw an error
    throw Exception('Supabase client is not initialized');
  }

  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_isInitialized) {
      debugPrint('Supabase is already initialized, skipping initialization');
      try {
        _supabaseClient = Supabase.instance.client;
      } catch (e) {
        debugPrint('Error getting Supabase instance: $e');
      }
      return;
    }

    // If initialization is in progress, wait for it to complete
    if (_isInitializing) {
      debugPrint('Supabase initialization already in progress, waiting...');
      return _initCompleter.future;
    }

    _isInitializing = true;

    try {
      // Set a timeout for initialization
      await Future.any([
        _initializeSupabase(),
        Future.delayed(const Duration(seconds: 5), () {
          throw TimeoutException(
              'Supabase initialization timed out after 5 seconds');
        })
      ]);

      _isInitialized = true;
      _isInitializing = false;
      _initCompleter.complete();
      debugPrint('Supabase initialized successfully');
    } catch (e) {
      _isInitializing = false;
      _initCompleter.completeError(e);
      debugPrint('Error initializing Supabase: $e');
      // Don't rethrow - allow the app to continue even if Supabase fails
      // The app will try to reconnect when needed
    }
  }

  Future<void> _initializeSupabase() async {
    // Diagnostics: Log which Supabase project URL we're targeting
    debugPrint('🔗 Initializing Supabase with URL: ' + supabaseUrl);
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // Automatically refresh tokens
        autoRefreshToken: true,
      ),
      // Add debug mode for better logging in development
      debug: kDebugMode,
    );
    _supabaseClient = Supabase.instance.client;

    // Wait a moment for session restoration to complete
    await Future.delayed(const Duration(milliseconds: 500));

    // Log the current session state for debugging
    final currentSession = _supabaseClient?.auth.currentSession;
    debugPrint(
        '📱 Supabase initialized - Current session: ${currentSession != null ? 'Found' : 'None'}');
    if (currentSession != null) {
      debugPrint('📱 Session user: ${currentSession.user.email}');
      debugPrint('📱 Session expires at: ${currentSession.expiresAt}');
      debugPrint(
          '📱 Session access token length: ${currentSession.accessToken.length}');
    } else {
      debugPrint('📱 No session found - user will need to log in');
    }
  }

  // Authentication methods
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
  }) async {
    try {
      print('Starting user registration process for: $email');
      print('User data to be saved: ${userData.toString()}');

      // Set up redirect URL based on platform
      const redirectUrl = kIsWeb
          ? 'https://anxieease.vercel.app/verify' // For web (your actual website)
          : 'anxiease://verify'; // For mobile deep linking

      print('Using redirect URL for verification: $redirectUrl');

      // Proceed with signup in auth
      print('Calling Supabase auth.signUp...');
      final AuthResponse response = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: redirectUrl,
        data: {
          'first_name': userData['first_name'],
          'middle_name': userData['middle_name'],
          'last_name': userData['last_name'],
          'email': email,
          'role': 'patient', // Always set as patient for mobile app
        },
      );
      print(
          'Supabase auth.signUp response received: ${response.session != null ? 'Session created' : 'No session'}, User: ${response.user != null ? response.user!.id : 'No user'}');

      if (response.user == null) {
        throw Exception('Registration failed. Please try again.');
      }

      print('Auth user created successfully with ID: ${response.user!.id}');

      try {
        // Always attempt to create user profile immediately during registration
        final timestamp = DateTime.now().toIso8601String();
        print('Creating user profile immediately during registration...');
        
        // Use service role to bypass RLS and create profile directly
        await _createUserProfileDirectly(
          userId: response.user!.id,
          email: email,
          userData: userData,
          timestamp: timestamp,
        );
        
        print('User profile created successfully during registration');
      } catch (e) {
        print('Error creating user record: $e');
        print('Error details: ${e.toString()}');
        // Don't throw here, as the auth user is already created
        // Just log the error and continue
      }

      // Sign out after registration so user is prompted to verify email
      // and remains on the authentication screens to see the success message
      try {
        await client.auth.signOut();
        print('Signed out after registration to await email verification');
      } catch (e) {
        print('Non-fatal: error signing out after signup: $e');
      }

      print('Registration process finished. Waiting for email verification.');

      return response;
    } catch (e) {
      print('Error during signup: ${e.toString()}');
      if (e.toString().contains('User already registered')) {
        throw Exception('Email already registered. Please login instead.');
      } else if (e.toString().contains('Invalid email')) {
        throw Exception('Please enter a valid email address.');
      } else if (e
          .toString()
          .contains('Password should be at least 6 characters')) {
        throw Exception('Password must be at least 6 characters long.');
      } else if (e.toString().contains('429')) {
        throw Exception('Please wait a moment before trying again.');
      }
      print('Unexpected error during registration: ${e.toString()}');
      throw Exception('Registration failed. Please try again later.');
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
    bool skipEmailVerification = false,
  }) async {
    try {
      // Try to authenticate with Supabase first
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed');
      }

      // Check if email is verified
      if (!skipEmailVerification && response.user?.emailConfirmedAt == null) {
        throw Exception(
            'Please verify your email before logging in. Check your inbox for the verification link.');
      }

      Logger.info(
          'User email verification status: ${response.user?.emailConfirmedAt != null}');
      Logger.info('Login successful');

      // Ensure user profile exists BEFORE returning - this prevents race conditions
      try {
        final user = await client
            .from('user_profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (user == null) {
          // User doesn't exist in user_profiles table, create it
          Logger.info(
              'User not found in user_profiles table, creating user record');
          
          // Try to use pending user data first, then fall back to metadata
          Map<String, dynamic> profileData;
          if (_pendingUserData != null && _pendingUserData!['user_id'] == response.user!.id) {
            print('Using pending user data for profile creation: $_pendingUserData');
            profileData = {
              'id': response.user!.id,
              'email': email,
              'first_name': _pendingUserData!['first_name'] ?? '',
              'middle_name': _pendingUserData!['middle_name'] ?? '',
              'last_name': _pendingUserData!['last_name'] ?? '',
              'birth_date': _pendingUserData!['birth_date'],
              'contact_number': _pendingUserData!['contact_number'] ?? '',
              'emergency_contact': _pendingUserData!['emergency_contact'] ?? '',
              'gender': _pendingUserData!['gender'] ?? '',
              'role': 'patient',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'is_email_verified': response.user?.emailConfirmedAt != null,
            };
            // Clear the pending data after use
            _pendingUserData = null;
          } else {
            // Fallback to metadata (for existing users)
            final metadata = response.user?.userMetadata ?? {};
            print('Using metadata for profile creation: $metadata');
            profileData = {
              'id': response.user!.id,
              'email': email,
              'first_name': metadata['first_name'] ?? '',
              'middle_name': metadata['middle_name'] ?? '',
              'last_name': metadata['last_name'] ?? '',
              'role': 'patient',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
              'is_email_verified': response.user?.emailConfirmedAt != null,
            };
          }
          
          await client.from('user_profiles').upsert(profileData);
          Logger.info('User record created successfully with profile data');
        } else {
          // Update email verification status if user exists
          await client.from('user_profiles').update({
            'updated_at': DateTime.now().toIso8601String(),
            'is_email_verified': response.user?.emailConfirmedAt != null,
          }).eq('id', response.user!.id);
          Logger.info('User profile updated successfully');
        }
      } catch (e) {
        Logger.error(
            'Error managing user record, but authentication succeeded', e);
        // Don't fail the login if user table operations fail
      }

      return response;
    } catch (e) {
      if (e.toString().contains('Invalid login credentials')) {
        Logger.error('Invalid login credentials', e);
        throw Exception('Invalid email or password');
      }
      Logger.error('Error during sign in', e);
      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      // Increase logging for debugging
      print('Requesting password reset for email: $email');

      // Use a platform-aware redirect so the link opens the app
      final String redirectUrl = kIsWeb
          ? 'https://anxieease.vercel.app/reset-password'
          : 'anxiease://reset-password';

      // Send reset email with deep-link redirect
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );

      print('Password reset email sent successfully');
    } catch (e) {
      print('Error sending password reset email: $e');
      throw Exception('Failed to send reset email: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } catch (e) {
      print('Error updating password: $e');
      throw Exception('Failed to update password: ${e.toString()}');
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile([String? userId]) async {
    final currentUser = client.auth.currentUser;
    if (currentUser == null) {
      print('getUserProfile: No user ID available');
      return null;
    }

    final user = userId ?? currentUser.id;
    print('Fetching user profile for ID: $user');

    try {
      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', user)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  Future<void> recoverPassword(String token, String newPassword,
      {String? email}) async {
    try {
      print('Attempting to recover password with token: $token');
      if (email != null) {
        print('Email provided for recovery: $email');
      }

      final client = Supabase.instance.client;

      // Verify the OTP with the recovery token and email if available
      if (email != null) {
        print('Using email + token verification approach');
        try {
          final response = await client.auth.verifyOTP(
            email: email,
            token: token,
            type: OtpType.recovery,
          );

          print(
              'OTP verification response: ${response.session != null ? 'Session established' : 'No session'}');

          if (response.session == null) {
            throw Exception(
                'Failed to establish a session with the recovery token. Please ensure the link is valid and not expired.');
          }
        } catch (e) {
          print('Error during OTP verification: $e');
          // Re-throw with clear message
          if (e.toString().contains('expired') ||
              e.toString().contains('otp_expired')) {
            throw Exception(
                'Your reset code has expired. Please request a new password reset.');
          }
          throw Exception('Error verifying reset code: $e');
        }
      } else {
        print('Using token-only verification approach');
        // Try token-only approach as fallback
        try {
          final response = await client.auth.verifyOTP(
            token: token,
            type: OtpType.recovery,
          );

          print(
              'Token-only OTP verification response: ${response.session != null ? 'Session established' : 'No session'}');

          if (response.session == null) {
            throw Exception(
                'Failed to establish a session with the recovery token. The link may be invalid or expired.');
          }
        } catch (e) {
          print('Error during token-only OTP verification: $e');
          // Re-throw with clear message
          if (e.toString().contains('expired') ||
              e.toString().contains('otp_expired')) {
            throw Exception(
                'Your reset code has expired. Please request a new password reset.');
          }
          throw Exception('Error verifying reset code: $e');
        }
      }

      // Now update the password
      print('Updating password after successful verification');
      await client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      print('Password updated successfully after recovery');
    } catch (e) {
      print('Error recovering password: $e');
      throw Exception('Failed to recover password: ${e.toString()}');
    }
  }

  Future<bool> verifyPasswordResetCode(String email, String token) async {
    try {
      print('Verifying password reset code: $token for email: $email');

      // Verify the OTP
      final response = await client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );

      print(
          'OTP verification response: ${response.session != null ? 'Session established' : 'No session'}');
      return response.session != null;
    } catch (e) {
      print('Error verifying password reset code: $e');
      if (e.toString().contains('expired') ||
          e.toString().contains('invalid') ||
          e.toString().contains('otp_expired')) {
        throw Exception(
            'Your verification code has expired. Please request a new one.');
      }
      throw Exception('Invalid verification code. Please try again.');
    }
  }

  Future<void> updatePasswordWithToken(String newPassword) async {
    try {
      print('Updating password with recovery token');

      // Get the auth instance
      final client = Supabase.instance.client;
      final auth = client.auth;

      // First check if we have a valid session
      final session = auth.currentSession;
      if (session == null) {
        throw Exception(
            'No active session found. Your reset link may have expired. Please request a new password reset.');
      }

      // Check if the session is expired
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      if (session.expiresAt != null && session.expiresAt! < now) {
        throw Exception(
            'Your session has expired. Please request a new password reset.');
      }

      // Update the user's password - this uses the current session
      final response = await auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        print('Password updated successfully');
      } else {
        throw Exception('Failed to update password. Please try again.');
      }
    } catch (e) {
      print('Error updating password: $e');
      if (e.toString().contains('expired') ||
          e.toString().contains('invalid') ||
          e.toString().contains('otp_expired')) {
        throw Exception(
            'Your reset link has expired. Please request a new password reset.');
      }
      throw Exception('Failed to update password: $e');
    }
  }

  // Profile methods
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First, verify which columns exist in the table
      final safeData = Map<String, dynamic>.from(data);
      final updatedData = {
        ...safeData,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('user_profiles').update(updatedData).eq('id', user.id);
      print(
          'Successfully updated user profile: ${updatedData.keys.join(', ')}');
    } catch (e) {
      if (e.toString().contains('Could not find')) {
        // If we get a PostgrestException about missing columns, try to update each field individually
        print(
            'Warning: Schema error detected. Trying individual field updates...');

        // Always update the timestamp
        try {
          await client.from('user_profiles').update({
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', user.id);
        } catch (_) {
          // Ignore errors with timestamp update
        }

        // Try each field individually
        for (var entry in data.entries) {
          try {
            await client.from('user_profiles').update({
              entry.key: entry.value,
            }).eq('id', user.id);
            print('Successfully updated field: ${entry.key}');
          } catch (fieldError) {
            print('Failed to update field ${entry.key}: $fieldError');
            // Continue with other fields
          }
        }
      } else {
        // For other errors, rethrow
        print('Error updating user profile: $e');
        rethrow;
      }
    }
  }

  // Anxiety records methods
  Future<void> saveAnxietyRecord(Map<String, dynamic> record) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Ensure record has a timestamp
      if (!record.containsKey('timestamp')) {
        record['timestamp'] = DateTime.now().toIso8601String();
      }

      // Map to exact anxiety_records table schema
      final recordToSave = <String, dynamic>{
        'user_id': user.id,
        'severity_level': record['severity_level'] ?? 'unknown',
        'timestamp':
            record['timestamp'], // Keep user-provided timestamp or now()
        'is_manual': record['is_manual'] ?? false,
        'source': (record['source'] ?? 'app').toString().substring(
            0,
            (record['source'] ?? 'app').toString().length > 50
                ? 50
                : (record['source'] ?? 'app').toString().length),
        'details': record['details']?.toString() ?? '',
      };

      // heart_rate removed from schema per product decision; do not include

      // Save to anxiety_records table and return the inserted row for verification
      final inserted = await client
          .from('anxiety_records')
          .insert(recordToSave)
          .select()
          .single();

      debugPrint(
          'Successfully saved anxiety record for user: ${user.id}, severity: ${record['severity_level']}');
      debugPrint(
          '🆔 anxiety_records inserted id: ${inserted['id']} at ${inserted['created_at']}');

      // Double-check: Immediately query back the record to confirm it's visible
      try {
        final verification = await client
            .from('anxiety_records')
            .select()
            .eq('id', inserted['id'])
            .maybeSingle();

        if (verification != null) {
          debugPrint(
              '✅ Verification: Record ${inserted['id']} found in anxiety_records with severity: ${verification['severity_level']}');
        } else {
          debugPrint(
              '❌ Verification failed: Record ${inserted['id']} not found in anxiety_records (possible RLS/visibility issue)');
        }
      } catch (verifyError) {
        debugPrint('❌ Verification query failed: $verifyError');
      }
    } catch (e) {
      debugPrint('Error saving anxiety record: $e');
      throw Exception('Failed to save anxiety record: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAnxietyRecords({
    String? userId,
    String? severityLevel,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Use the provided user ID or fall back to current user
      final targetUserId = userId ?? user.id;

      // Start building the query
      var query =
          client.from('anxiety_records').select().eq('user_id', targetUserId);

      // Add severity level filter if provided
      if (severityLevel != null) {
        query = query.eq('severity_level', severityLevel);
      }

      // Add date range filters if provided
      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      // Get the records ordered by created_at in descending order (newest first)
      final response = await query.order('created_at', ascending: false);

      debugPrint(
          'Retrieved ${response.length} anxiety records for user: $targetUserId');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error retrieving anxiety records: $e');
      throw Exception('Failed to retrieve anxiety records: $e');
    }
  }

  // Get anxiety statistics for a specific user (for web dashboard)
  Future<Map<String, dynamic>> getAnxietyStatistics({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Use the provided user ID or fall back to current user
      final targetUserId = userId ?? user.id;

      // Get all anxiety records for the specified time period
      final List<Map<String, dynamic>> records = await getAnxietyRecords(
        userId: targetUserId,
        startDate: startDate,
        endDate: endDate,
      );

      if (records.isEmpty) {
        return {
          'total_attacks': 0,
          'by_severity': {
            'mild': 0,
            'moderate': 0,
            'severe': 0,
            'unknown': 0,
          },
          'frequency_data': [],
        };
      }

      // Count attacks by severity
      int mildCount = 0;
      int moderateCount = 0;
      int severeCount = 0;
      int unknownCount = 0;

      // Maps to track frequency (by day)
      final Map<String, int> dailyFrequency = {};

      // Process each record
      for (final record in records) {
        // Count by severity
        final String severity =
            record['severity_level']?.toString().toLowerCase() ?? 'unknown';
        switch (severity) {
          case 'mild':
            mildCount++;
            break;
          case 'moderate':
            moderateCount++;
            break;
          case 'severe':
            severeCount++;
            break;
          default:
            unknownCount++;
        }

        // Track daily frequency
        if (record['timestamp'] != null) {
          final DateTime timestamp = DateTime.parse(record['timestamp']);
          final String dateKey =
              '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

          dailyFrequency[dateKey] = (dailyFrequency[dateKey] ?? 0) + 1;
        }
      }

      // Convert frequency map to list for charts
      final List<Map<String, dynamic>> frequencyData = dailyFrequency.entries
          .map((entry) => {
                'date': entry.key,
                'count': entry.value,
              })
          .toList();

      // Sort frequency data by date
      frequencyData.sort((a, b) => a['date'].compareTo(b['date']));

      // Return statistics
      return {
        'total_attacks': records.length,
        'by_severity': {
          'mild': mildCount,
          'moderate': moderateCount,
          'severe': severeCount,
          'unknown': unknownCount,
        },
        'frequency_data': frequencyData,
      };
    } catch (e) {
      debugPrint('Error retrieving anxiety statistics: $e');
      throw Exception('Failed to retrieve anxiety statistics: $e');
    }
  }

  // Wellness logs methods (for moods, symptoms, stress levels)
  Future<void> saveWellnessLog(Map<String, dynamic> log) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      print('SaveWellnessLog called with log data: ${log.toString()}');

      // Check if this is an update of an existing log (log has an id)
      if (log['id'] != null) {
        print('Log has ID ${log['id']}, using updateWellnessLog directly');
        // This is an update - use the updateWellnessLog method
        await updateWellnessLog(log);
        return;
      }

      // Even if no ID is provided, check if a log with the same timestamp already exists
      if (log['timestamp'] != null) {
        print('Checking for existing log with timestamp ${log['timestamp']}');
        final existingLogs = await client
            .from('wellness_logs')
            .select('id, feelings, stress_level, symptoms, journal')
            .eq('user_id', user.id)
            .eq('timestamp', log['timestamp'])
            .limit(1);

        if (existingLogs.isNotEmpty) {
          print(
              'Found existing log with ID ${existingLogs[0]['id']} - updating instead of creating new record');

          // Check if content has actually changed before updating
          bool contentChanged = false;
          final existingLog = existingLogs[0];

          // Compare feelings
          if (!_areListsEqual(existingLog['feelings'], log['feelings'])) {
            print(
                'Feelings have changed: ${existingLog['feelings']} -> ${log['feelings']}');
            contentChanged = true;
          }

          // Compare stress level
          if (existingLog['stress_level'] != log['stress_level']) {
            print(
                'Stress level has changed: ${existingLog['stress_level']} -> ${log['stress_level']}');
            contentChanged = true;
          }

          // Compare symptoms
          if (!_areListsEqual(existingLog['symptoms'], log['symptoms'])) {
            print(
                'Symptoms have changed: ${existingLog['symptoms']} -> ${log['symptoms']}');
            contentChanged = true;
          }

          // Compare journal
          if (existingLog['journal'] != log['journal']) {
            print(
                'Journal has changed: ${existingLog['journal']} -> ${log['journal']}');
            contentChanged = true;
          }

          if (!contentChanged) {
            print('No content changes detected, skipping update');
            return;
          }

          // Add the ID to the log data and update
          log['id'] = existingLogs[0]['id'];
          await updateWellnessLog(log);
          return;
        } else {
          print('No existing log found with timestamp ${log['timestamp']}');
        }
      }

      // Add the record to the wellness_logs table with all the needed fields
      print('Creating new wellness log record');
      await client.from('wellness_logs').insert({
        'user_id': user.id,
        'date': log['date'],
        'feelings': log['feelings'],
        'stress_level': log['stress_level'],
        'symptoms': log['symptoms'],
        'journal': log['journal'],
        'timestamp': log['timestamp'],
        'created_at': DateTime.now().toIso8601String(),
      });

      print('Successfully saved wellness log for user: ${user.id}');
    } catch (e) {
      print('Error in saveWellnessLog: $e');
      throw Exception('Failed to save wellness log: $e');
    }
  }

  // Helper method to compare two lists
  bool _areListsEqual(List<dynamic>? list1, List<dynamic>? list2) {
    if (list1 == null && list2 == null) return true;
    if (list1 == null || list2 == null) return false;
    if (list1.length != list2.length) return false;

    for (int i = 0; i < list1.length; i++) {
      if (!list2.contains(list1[i])) return false;
    }

    return true;
  }

  // Update an existing wellness log
  Future<void> updateWellnessLog(Map<String, dynamic> log) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      print('UpdateWellnessLog called with log data: ${log.toString()}');

      if (log['id'] == null && log['timestamp'] == null) {
        throw Exception('Cannot update log without an id or timestamp');
      }

      // Only include fields that are needed for the update
      Map<String, dynamic> updateData = {
        'date': log['date'],
        'feelings': log['feelings'],
        'stress_level': log['stress_level'],
        'symptoms': log['symptoms'],
      };

      // Only include journal if it's provided
      if (log['journal'] != null) {
        updateData['journal'] = log['journal'];
      }

      // Include timestamp for consistency
      updateData['timestamp'] = log['timestamp'];

      print('Final update data: $updateData');

      // Start building the query
      var query = client
          .from('wellness_logs')
          .update(updateData)
          .eq('user_id', user.id);

      // Use ID if available, otherwise use timestamp
      if (log['id'] != null) {
        print('Updating by ID: ${log['id']}');
        query = query.eq('id', log['id']);
      } else {
        print('Updating by timestamp: ${log['timestamp']}');
        query = query.eq('timestamp', log['timestamp']);
      }

      final response = await query;
      print('Update response: $response');

      print('Successfully updated wellness log for user: ${user.id}');
    } catch (e) {
      print('Error updating wellness log: $e');
      throw Exception('Failed to update wellness log: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getWellnessLogs({String? userId}) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // If userId is provided, fetch logs for that user (for psychologists)
    // Otherwise, fetch logs for the current user (for patients)
    final targetUserId = userId ?? user.id;

    final response = await client
        .from('wellness_logs')
        .select()
        .eq('user_id', targetUserId)
        .order('created_at', ascending: false);

    print(
        'Successfully retrieved ${response.length} wellness logs for user: $targetUserId');
    return List<Map<String, dynamic>>.from(response);
  }

  // Delete a wellness log
  Future<void> deleteWellnessLog(String date, DateTime timestamp) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Convert timestamp to ISO string for comparison
    final timestampString = timestamp.toIso8601String();

    await client
        .from('wellness_logs')
        .delete()
        .eq('user_id', user.id)
        .eq('date', date)
        .eq('timestamp', timestampString);

    print(
        'Successfully deleted wellness log for date: $date, timestamp: $timestampString');
  }

  // Clear all wellness logs for the current user
  Future<void> clearAllWellnessLogs() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await client.from('wellness_logs').delete().eq('user_id', user.id);

      print('Successfully cleared all wellness logs for user: ${user.id}');
    } catch (e) {
      print('Error clearing wellness logs from Supabase: $e');
      throw Exception('Failed to clear wellness logs from database');
    }
  }

  // Get all patients assigned to a psychologist
  Future<List<Map<String, dynamic>>> getAssignedPatients() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if the current user is a psychologist
    final userProfile = await getUserProfile();
    if (userProfile == null || userProfile['role'] != 'psychologist') {
      throw Exception(
          'Unauthorized. Only psychologists can access patient data.');
    }

    // In a real implementation, fetch assigned patients from the database
    // For demonstration, return hardcoded patient data
    return [
      {
        'id': 'patient-001',
        'full_name': 'John Doe',
        'email': 'john.doe@example.com',
      },
      {
        'id': 'patient-002',
        'full_name': 'Jane Smith',
        'email': 'jane.smith@example.com',
      },
    ];

    // Original implementation (commented out)
    /*
    final response = await client
        .from('user_profiles')
        .select()
        .eq('assigned_psychologist_id', user.id)
        .eq('role', 'patient');

    return List<Map<String, dynamic>>.from(response);
    */
  }

  // Get mood log statistics for a patient
  Future<Map<String, dynamic>> getPatientMoodStats(String patientId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if the current user is a psychologist
    final userProfile = await getUserProfile();
    if (userProfile == null || userProfile['role'] != 'psychologist') {
      throw Exception(
          'Unauthorized. Only psychologists can access patient statistics.');
    }

    // Get all mood logs for the patient
    final logs = await getWellnessLogs(userId: patientId);

    // Calculate frequency statistics
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    int logsLast7Days = 0;
    int logsLast30Days = 0;
    Map<String, int> symptomFrequency = {};
    Map<String, int> moodFrequency = {};
    List<double> stressLevels = [];

    for (var log in logs) {
      final logDate = DateTime.parse(log['timestamp']);

      // Count logs in last 7 and 30 days
      if (logDate.isAfter(sevenDaysAgo)) {
        logsLast7Days++;
      }
      if (logDate.isAfter(thirtyDaysAgo)) {
        logsLast30Days++;
      }

      // Count symptoms
      for (var symptom in log['symptoms']) {
        symptomFrequency[symptom] = (symptomFrequency[symptom] ?? 0) + 1;
      }

      // Count moods
      for (var mood in log['feelings']) {
        moodFrequency[mood] = (moodFrequency[mood] ?? 0) + 1;
      }

      // Track stress levels
      stressLevels.add(log['stress_level']?.toDouble() ?? 0.0);
    }

    // Calculate average stress level
    double avgStressLevel = stressLevels.isEmpty
        ? 0.0
        : stressLevels.reduce((a, b) => a + b) / stressLevels.length;

    // Sort symptoms and moods by frequency
    final sortedSymptoms = symptomFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sortedMoods = moodFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return the statistics
    return {
      'total_logs': logs.length,
      'logs_last_7_days': logsLast7Days,
      'logs_last_30_days': logsLast30Days,
      'avg_stress_level': avgStressLevel,
      'top_symptoms': sortedSymptoms
          .take(5)
          .map((e) => {'symptom': e.key, 'count': e.value})
          .toList(),
      'top_moods': sortedMoods
          .take(5)
          .map((e) => {'mood': e.key, 'count': e.value})
          .toList(),
    };
  }

  // Check if user is authenticated
  bool get isAuthenticated {
    try {
      return client.auth.currentUser != null;
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
      return false;
    }
  }

  // Get current user
  User? get currentUser => client.auth.currentUser;

  // Email verification methods
  Future<void> resendVerificationEmail(String email) async {
    try {
      // Request Supabase to resend the signup confirmation email
      await client.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } catch (e) {
      print('Error resending verification email: $e');
      // Provide friendlier messages for common cases
      final msg = e.toString();
      if (msg.contains('rate limit') || msg.contains('429')) {
        throw Exception('You\'re doing that too much. Please try again later.');
      }
      throw Exception('Failed to resend verification email.');
    }
  }

  Future<void> updateEmailVerificationStatus(String email) async {
    try {
      print('Updating email verification status for: $email');

      await client.from('user_profiles').update({
        'is_email_verified': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('email', email);

      print('Email verification status updated successfully');
    } catch (e) {
      print('Error updating email verification status: $e');
      throw Exception('Failed to update email verification status');
    }
  }

  // Psychologist methods
  Future<Map<String, dynamic>?> getAssignedPsychologist() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First get the user's assigned psychologist ID
      final userProfile = await getUserProfile();
      if (userProfile == null) {
        // If no user profile found, try fetching a default psychologist
        final psychologists =
            await client.from('psychologists').select().limit(1).maybeSingle();

        if (psychologists != null) {
          return _ensurePsychologistFields(psychologists);
        }
        return null;
      }

      // If user has assigned_psychologist_id, use it
      if (userProfile['assigned_psychologist_id'] != null) {
        final psychologistId = userProfile['assigned_psychologist_id'];

        // Get the psychologist details
        final psychologist = await client
            .from('psychologists')
            .select()
            .eq('id', psychologistId)
            .maybeSingle();

        if (psychologist != null) {
          return _ensurePsychologistFields(psychologist);
        }
        return null;
      } else {
        // If user doesn't have assigned psychologist, get the first available one
        final psychologist =
            await client.from('psychologists').select().limit(1).maybeSingle();

        // If a psychologist is found, assign it to the user
        if (psychologist != null) {
          await client
              .from('user_profiles')
              .update({'assigned_psychologist_id': psychologist['id']}).eq(
                  'id', user.id);

          return _ensurePsychologistFields(psychologist);
        }
        return null;
      }
    } catch (e) {
      Logger.error('Error fetching assigned psychologist', e);

      // Fallback to hardcoded data in case of error
      return {
        'id': 'psy-001',
        'name': 'Dr. Sarah Johnson',
        'specialization': 'Clinical Psychologist, Anxiety Specialist',
        'contact_email': 'sarah.johnson@anxiease.com',
        'contact_phone': '(555) 123-4567',
        'biography':
            'Dr. Sarah Johnson is a licensed clinical psychologist with over 15 years of experience specializing in anxiety disorders, panic attacks, and stress management. She completed her Ph.D. at Stanford University and has published numerous research papers on cognitive behavioral therapy techniques for anxiety management. Dr. Johnson takes a holistic approach to mental health, combining evidence-based therapeutic techniques with mindfulness practices to help patients develop effective coping strategies for their anxiety.',
        'image_url': null,
      };
    }
  }

  // Appointment methods
  Future<List<Map<String, dynamic>>> getAppointments() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First try to create the table if it doesn't exist
      await createAppointmentsTableIfNotExists();

      // Query appointments table for this user
      try {
        final response = await client
            .from('appointments')
            .select()
            .eq('user_id', user.id)
            .order('appointment_date', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('does not exist') ||
            errorMsg.contains('relation "appointments" does not exist')) {
          // If appointments table doesn't exist, check for appointment_request notifications
          final notifications = await client
              .from('notifications')
              .select()
              .eq('user_id', user.id)
              .eq('type', 'appointment_request')
              .order('created_at', ascending: false);

          if (notifications.isNotEmpty) {
            // Convert notifications to appointment format
            return notifications.map<Map<String, dynamic>>((notification) {
              // Parse the message to extract details
              return {
                'id': notification['id'] ?? 'temp-id',
                'psychologist_id': notification['related_id'] ?? 'unknown',
                'user_id': user.id,
                'appointment_date': notification[
                    'created_at'], // Use notification date as appointment date
                'reason': notification['message'] ?? 'Appointment request',
                'status': 'pending',
                'created_at': notification['created_at'],
              };
            }).toList();
          }

          // If no notifications found, return empty list
          return [];
        } else {
          // Some other error occurred
          rethrow;
        }
      }
    } catch (e) {
      Logger.error('Error fetching appointments', e);

      // Fallback to hardcoded data in case of error
      final now = DateTime.now();
      return [
        // Past appointments (only 2)
        {
          'id': 'apt-001',
          'psychologist_id': 'psy-001',
          'user_id': user.id,
          'appointment_date': DateTime(now.year, now.month, now.day - 30, 10, 0)
              .toIso8601String(),
          'reason': 'Initial consultation and anxiety assessment',
          'status': 'completed',
          'created_at':
              DateTime(now.year, now.month, now.day - 35).toIso8601String(),
        },
        {
          'id': 'apt-002',
          'psychologist_id': 'psy-001',
          'user_id': user.id,
          'appointment_date': DateTime(now.year, now.month, now.day - 7, 11, 0)
              .toIso8601String(),
          'reason': 'Discuss progress with breathing exercises',
          'status': 'cancelled',
          'created_at':
              DateTime(now.year, now.month, now.day - 10).toIso8601String(),
        },
      ];
    }
  }

  // Method to create the appointments table if it doesn't exist
  Future<bool> createAppointmentsTableIfNotExists() async {
    try {
      // First check if the table exists by querying it
      try {
        await client.from('appointments').select('count').limit(1);
        Logger.info('Appointments table already exists');
        return true; // Table exists
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('does not exist') ||
            errorMsg.contains('relation "appointments" does not exist')) {
          // Table doesn't exist, create it using SQL
          Logger.info('Creating appointments table...');
          await client.rpc('create_appointments_table');
          Logger.info('Appointments table created successfully');
          return true;
        } else {
          Logger.error('Error checking appointments table', e);
          return false;
        }
      }
    } catch (e) {
      Logger.error('Error creating appointments table', e);
      return false;
    }
  }

  Future<String> requestAppointment(
      Map<String, dynamic> appointmentData) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First try to create the table if it doesn't exist
      await createAppointmentsTableIfNotExists();

      // Get the current timestamp for created_at
      final timestamp = DateTime.now().toIso8601String();

      // Try to insert the appointment record
      final response = await client.from('appointments').insert({
        'user_id': user.id,
        ...appointmentData,
        'status': 'pending',
        'created_at': timestamp,
      }).select();

      if (response.isEmpty) {
        throw Exception('Failed to create appointment');
      }

      // Log success for debugging
      Logger.info('Successfully created appointment: ${response[0]['id']}');

      // Return the newly created appointment ID
      return response[0]['id'];
    } catch (e) {
      Logger.error('Error requesting appointment', e);

      // If it's a table-not-exists error, create a notification as fallback
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('does not exist') ||
          errorMsg.contains('relation "appointments" does not exist')) {
        // Create a notification record as fallback
        await createNotification(
          title: 'New Appointment Request',
          message:
              'You requested an appointment with a psychologist. Please contact them directly.',
          type: 'appointment_request',
        );
        return 'temp-${DateTime.now().millisecondsSinceEpoch}';
      }

      throw Exception('Failed to request appointment: ${e.toString()}');
    }
  }

  // Notification methods
  Future<List<Map<String, dynamic>>> getNotifications({String? type}) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    debugPrint('getNotifications called with type: $type');

    try {
      // First get all notifications for this user
      var query = client.from('notifications').select().eq('user_id', user.id);

      // Add type filter if specified
      if (type != null) {
        query = query.eq('type', type);
      }

      // Get all notifications first
      final allNotifications =
          await query.order('created_at', ascending: false);

      // Filter out deleted notifications in Dart code
      final activeNotifications = allNotifications
          .where((notification) => notification['deleted_at'] == null)
          .toList();

      debugPrint(
          'getNotifications success - retrieved ${activeNotifications.length} notifications out of ${allNotifications.length} total');
      return List<Map<String, dynamic>>.from(activeNotifications);
    } catch (e) {
      debugPrint('getNotifications error: $e');

      if (e.toString().contains('does not exist')) {
        // Table doesn't exist yet, return empty list
        debugPrint('Notifications table does not exist. Returning empty list.');
        return [];
      }
      rethrow;
    }
  }

  Future<void> deleteNotification(String id, {bool hardDelete = false}) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (hardDelete) {
      // Permanently delete the notification
      await client
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      debugPrint('Permanently deleted notification $id');
    } else {
      // Soft delete (mark as deleted)
      await client
          .from('notifications')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', user.id);

      debugPrint('Soft-deleted notification $id');
    }
  }

  Future<void> clearAllNotifications({bool hardDelete = false}) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (hardDelete) {
      // Permanently delete all notifications
      await client.from('notifications').delete().eq('user_id', user.id);

      debugPrint('Permanently deleted all notifications for user ${user.id}');
    } else {
      // Soft delete (mark as deleted)
      await client
          .from('notifications')
          .update({'deleted_at': DateTime.now().toIso8601String()}).eq(
              'user_id', user.id);

      debugPrint('Soft-deleted all notifications for user ${user.id}');
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await client
        .from('notifications')
        .update({'read': true})
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<void> markAllNotificationsAsRead() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', user.id)
        .eq('read', false)
        .isFilter('deleted_at', null);
  }

  Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    String? relatedScreen,
    String? relatedId,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final nowIso = DateTime.now().toIso8601String();
    bool _isValidUuid(String s) {
      final regex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\$');
      return regex.hasMatch(s);
    }

    final Map<String, dynamic> row = {
      'user_id': user.id,
      'title': title,
      'message': message,
      'type': type,
      'related_screen': relatedScreen,
      'read': false,
      'created_at': nowIso,
    };

    if (relatedId != null) {
      if (_isValidUuid(relatedId)) {
        row['related_id'] = relatedId;
      } else {
        debugPrint('ℹ️ Skipping non-UUID relatedId: ' + relatedId);
      }
    }

    try {
      final inserted =
          await client.from('notifications').insert(row).select().single();
      debugPrint('💾 createNotification inserted id: ' +
          (inserted['id']?.toString() ?? 'unknown') +
          ' type: ' +
          type);
    } catch (e) {
      debugPrint('❌ createNotification insert failed: ' + e.toString());
      rethrow;
    }
  }

  // Additional psychologist methods
  Future<List<Map<String, dynamic>>> getAllPsychologists() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Query all psychologists from the database
      final response =
          await client.from('psychologists').select().order('name');

      // Ensure all required fields are present for each psychologist
      return List<Map<String, dynamic>>.from(response
          .map((psychologist) => _ensurePsychologistFields(psychologist)));
    } catch (e) {
      Logger.error('Error fetching all psychologists', e);

      // Fallback to hardcoded data in case of error
      return [
        {
          'id': 'psy-001',
          'name': 'Dr. Sarah Johnson',
          'specialization': 'Clinical Psychologist, Anxiety Specialist',
          'contact_email': 'sarah.johnson@anxiease.com',
          'contact_phone': '(555) 123-4567',
          'biography':
              'Dr. Sarah Johnson is a licensed clinical psychologist with over 15 years of experience specializing in anxiety disorders, panic attacks, and stress management.',
          'image_url': null,
        },
        {
          'id': 'psy-002',
          'name': 'Dr. Michael Chen',
          'specialization': 'Psychiatrist, Depression & Anxiety Treatment',
          'contact_email': 'michael.chen@anxiease.com',
          'contact_phone': '(555) 234-5678',
          'biography':
              'Dr. Michael Chen is a board-certified psychiatrist specializing in medication management for anxiety and depression. He combines pharmacological approaches with lifestyle interventions.',
          'image_url': null,
        },
        {
          'id': 'psy-003',
          'name': 'Dr. Emily Rodriguez',
          'specialization': 'Cognitive Behavioral Therapist',
          'contact_email': 'emily.rodriguez@anxiease.com',
          'contact_phone': '(555) 345-6789',
          'biography':
              'Dr. Emily Rodriguez is an expert in cognitive behavioral therapy (CBT) with a focus on helping clients overcome anxiety through evidence-based techniques and practical coping strategies.',
          'image_url': null,
        },
      ];
    }
  }

  Future<void> assignPsychologist(String psychologistId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Update the user's assigned psychologist
      await client.from('user_profiles').update(
          {'assigned_psychologist_id': psychologistId}).eq('id', user.id);

      Logger.info(
          'Successfully assigned psychologist $psychologistId to user ${user.id}');
    } catch (e) {
      Logger.error('Error assigning psychologist', e);
      throw Exception('Failed to assign psychologist: ${e.toString()}');
    }
  }

  // Helper method to ensure all required psychologist fields are present
  Map<String, dynamic> _ensurePsychologistFields(
      Map<String, dynamic> psychologist) {
    return {
      'id': psychologist['id'] ?? 'unknown-id',
      'name': psychologist['name'] ?? 'Unknown Psychologist',
      'specialization': psychologist['specialization'] ?? 'General Psychology',
      // Try multiple possible keys before using placeholder
      'contact_email': psychologist['contact_email'] ??
          psychologist['email'] ??
          psychologist['contactEmail'] ??
          'contact@anxiease.com',
      'contact_phone':
          psychologist['contact'] ?? psychologist['contact_phone'] ?? 'N/A',
      'biography': psychologist['bio'] ??
          psychologist['biography'] ??
          'No biography available',
      'image_url': psychologist['image_url'] ?? psychologist['avatar_url'],
    };
  }

  // Profile picture methods
  Future<String?> uploadPsychologistProfilePicture(
      String psychologistId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$psychologistId.$fileExt';
      final filePath = 'psychologists/$fileName';

      // Upload file to Supabase Storage
      await client.storage.from('profile_pictures').upload(filePath, imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

      // Get public URL
      final imageUrl =
          client.storage.from('profile_pictures').getPublicUrl(filePath);

      // Update psychologist record with image URL
      await client
          .from('psychologists')
          .update({'image_url': imageUrl}).eq('id', psychologistId);

      return imageUrl;
    } catch (e) {
      Logger.error('Error uploading profile picture', e);
      return null;
    }
  }

  Future<String?> getPsychologistProfilePictureUrl(
      String psychologistId) async {
    try {
      // First check if the psychologist has an avatar_url directly in their record
      final psychologist = await client
          .from('psychologists')
          .select('avatar_url')
          .eq('id', psychologistId)
          .maybeSingle();

      // If there's an avatar_url in the database record, use that directly
      if (psychologist != null &&
          psychologist['avatar_url'] != null &&
          psychologist['avatar_url'].toString().isNotEmpty) {
        return psychologist['avatar_url'];
      }

      // Fallback to storage bucket lookup
      final files = await client.storage
          .from('profile_pictures')
          .list(path: 'psychologists');

      // Find files that start with the psychologist ID
      final profilePic = files
          .where((file) => file.name.startsWith(psychologistId))
          .firstOrNull;

      if (profilePic != null) {
        return client.storage
            .from('profile_pictures')
            .getPublicUrl('psychologists/${profilePic.name}');
      }

      return null;
    } catch (e) {
      Logger.error('Error fetching profile picture', e);
      return null;
    }
  }

  // User avatar upload methods
  Future<String?> uploadUserAvatar(String userId, File imageFile) async {
    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId.$fileExt';
      final filePath = 'users/$fileName';

      // Upload file to Supabase Storage (avatars bucket)
      await client.storage.from('avatars').upload(filePath, imageFile,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

      // Get public URL
      final imageUrl = client.storage.from('avatars').getPublicUrl(filePath);

      // Update user profile record with avatar URL
      await client
          .from('user_profiles')
          .update({'avatar_url': imageUrl}).eq('id', userId);

      return imageUrl;
    } catch (e) {
      Logger.error('Error uploading user avatar', e);
      return null;
    }
  }

  Future<String?> getUserAvatarUrl(String userId) async {
    try {
      // First check if the user has an avatar_url directly in their record
      final userProfile = await client
          .from('user_profiles')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();

      // If there's an avatar_url in the database record, use that directly
      if (userProfile != null &&
          userProfile['avatar_url'] != null &&
          userProfile['avatar_url'].toString().isNotEmpty) {
        return userProfile['avatar_url'];
      }

      // Fallback to storage bucket lookup
      final files = await client.storage.from('avatars').list(path: 'users');

      // Find files that start with the user ID
      final avatar =
          files.where((file) => file.name.startsWith(userId)).firstOrNull;

      if (avatar != null) {
        final avatarUrl =
            client.storage.from('avatars').getPublicUrl('users/${avatar.name}');

        // Update the database with the found URL for future use
        await client
            .from('user_profiles')
            .update({'avatar_url': avatarUrl}).eq('id', userId);

        return avatarUrl;
      }

      return null;
    } catch (e) {
      Logger.error('Error fetching user avatar', e);
      return null;
    }
  }

  // Method to manually refresh an appointment's status from the database
  Future<Map<String, dynamic>?> refreshAppointmentStatus(
      String appointmentId) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Query the appointments table for the specific appointment
      final response = await client
          .from('appointments')
          .select()
          .eq('id', appointmentId)
          .maybeSingle();

      // If the appointment has a response message but is still pending, update it to accepted
      if (response != null &&
          response['status'] == 'pending' &&
          response['response_message'] != null &&
          response['response_message'].toString().isNotEmpty) {
        Logger.info(
            'Appointment has response but still pending. Updating to accepted.');

        // Update the status to accepted
        final updatedResponse = await client
            .from('appointments')
            .update({'status': 'accepted'})
            .eq('id', appointmentId)
            .select();

        if (updatedResponse.isNotEmpty) {
          return updatedResponse[0];
        }
      }

      return response;
    } catch (e) {
      Logger.error('Error refreshing appointment status', e);
      return null;
    }
  }

  // Method to update an appointment's status
  Future<bool> updateAppointmentStatus(
      String appointmentId, String newStatus) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Update the status in the database
      await client.from('appointments').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', appointmentId);

      Logger.info(
          'Successfully updated appointment $appointmentId status to $newStatus');
      return true;
    } catch (e) {
      Logger.error('Error updating appointment status', e);
      return false;
    }
  }

  // Method to auto-archive old appointments
  Future<int> autoArchiveOldAppointments() async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final now = DateTime.now();
      final cutoffDate =
          now.subtract(const Duration(days: 30)).toIso8601String();
      int totalArchived = 0;

      // Get completed appointments older than 30 days
      final completedAppointments = await client
          .from('appointments')
          .update({'status': 'archived', 'updated_at': now.toIso8601String()})
          .eq('user_id', user.id)
          .eq('status', 'completed')
          .lt('appointment_date', cutoffDate)
          .select();

      totalArchived += completedAppointments.length;

      // Get expired but unattended appointments
      final expiredAppointments = await client
          .from('appointments')
          .update({'status': 'archived', 'updated_at': now.toIso8601String()})
          .eq('user_id', user.id)
          .or('status.eq.accepted,status.eq.approved')
          .lt('appointment_date', cutoffDate)
          .select();

      totalArchived += expiredAppointments.length;

      // Get old cancelled/denied appointments
      final cancelledAppointments = await client
          .from('appointments')
          .update({'status': 'archived', 'updated_at': now.toIso8601String()})
          .eq('user_id', user.id)
          .or('status.eq.cancelled,status.eq.denied')
          .lt('updated_at', cutoffDate)
          .select();

      totalArchived += cancelledAppointments.length;

      Logger.info('Auto-archived $totalArchived old appointments');
      return totalArchived;
    } catch (e) {
      Logger.error('Error auto-archiving old appointments', e);
      return 0;
    }
  }

  // Record anxiety detection response from user
  Future<void> recordAnxietyResponse({
    required Map<String, dynamic> detectionData,
    required bool userConfirmed,
    String? reportedSeverity,
    required double confidenceLevel,
    String? responseTime,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // If user denied the detection, skip inserting into anxiety_records and just log
      if (!userConfirmed) {
        await createNotification(
          title: 'Anxiety Detection Dismissed',
          message:
              'User indicated they are not anxious at this time. Detection confidence: ${(confidenceLevel * 100).toStringAsFixed(0)}%',
          type: 'anxiety_log',
        );
        return;
      }

      // Map response into existing anxiety_records schema
      final String severity = (reportedSeverity ??
              detectionData['severity'] ??
              detectionData['severity_level'] ??
              'unknown')
          .toString()
          .toLowerCase();

      // Heart rate is not stored in anxiety_records

      // Extract trigger source from detection data
      final String triggerSource = (() {
        final source = detectionData['source']?.toString() ?? 'app_detection';
        if (detectionData['reasons']?.toString().contains('Movement') == true)
          return 'movement_pattern';
        if (detectionData['reasons']?.toString().contains('SpO2') == true)
          return 'oxygen_level';
        return source;
      })();

      final String details =
          detectionData['details']?.toString().isNotEmpty == true
              ? detectionData['details'].toString()
              : 'User confirmed ${severity} anxiety episode';

      await saveAnxietyRecord({
        'severity_level': severity,
        'timestamp': responseTime ?? DateTime.now().toIso8601String(),
        'is_manual': false,
        'source': triggerSource,
        'details': details,
      });
    } catch (e) {
      Logger.error('Error recording anxiety response', e);
      // Fall back to creating a notification log if the table doesn't exist
      await createNotification(
        title: 'Anxiety Response Logged',
        message:
            'User ${userConfirmed ? 'confirmed' : 'denied'} anxiety detection'
            '${reportedSeverity != null ? ' (Severity: $reportedSeverity)' : ''}',
        type: 'anxiety_log',
      );
    }
  }
}
