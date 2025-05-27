import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/logger.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';

class SupabaseService {
  static const String supabaseUrl = 'https://gqsustjxzjzfntcsnvpk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA';

  late final SupabaseClient _supabaseClient;
  bool _isInitialized = false;

  // Singleton pattern
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  Future<void> initialize() async {
    if (_isInitialized) {
      print('Supabase is already initialized, skipping initialization');
      _supabaseClient = Supabase.instance.client;
      return;
    }

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _supabaseClient = Supabase.instance.client;
      _isInitialized = true;
      print('Supabase initialized successfully');
    } catch (e) {
      print('Error initializing Supabase: $e');
      rethrow;
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

      // Set up redirect URL based on platform
      const redirectUrl = kIsWeb
          ? 'http://localhost:3000/verify' // For web
          : 'anxiease://verify'; // For mobile deep linking

      print('Using redirect URL for verification: $redirectUrl');

      // Proceed with signup in auth
      final AuthResponse response = await _supabaseClient.auth.signUp(
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

      if (response.user == null) {
        throw Exception('Registration failed. Please try again.');
      }

      print('Auth user created successfully with ID: ${response.user!.id}');

      try {
        // Create user record in users table
        final timestamp = DateTime.now().toIso8601String();
        await _supabaseClient.from('users').upsert({
          'id': response.user!.id,
          'email': email,
          'password_hash': 'MANAGED_BY_SUPABASE_AUTH',
          'first_name': userData['first_name'],
          'middle_name': userData['middle_name'],
          'last_name': userData['last_name'],
          'age': userData['age'],
          'contact_number': userData['contact_number'],
          'gender': userData['gender'],
          'role': 'patient',
          'created_at': timestamp,
          'updated_at': timestamp,
          'is_email_verified': false,
        });

        print('User record created successfully');
      } catch (e) {
        print('Error creating user record: $e');
        // Don't throw here, as the auth user is already created
        // Just log the error and continue
      }

      // Sign out after registration to ensure clean state
      await signOut();

      return response;
    } catch (e) {
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
      // First verify this email exists in users table
      final user = await _supabaseClient
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (user == null) {
        throw Exception(
            'This account is not registered. Please sign up first.');
      }

      final response = await _supabaseClient.auth.signInWithPassword(
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

      // Update email verification status only
      await _supabaseClient.from('users').update({
        'updated_at': DateTime.now().toIso8601String(),
        'is_email_verified': response.user?.emailConfirmedAt != null,
      }).eq('id', response.user!.id);

      Logger.info(
          'User email verification status: ${response.user?.emailConfirmedAt != null}');
      Logger.info('Updated user record with verification status');

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
    await _supabaseClient.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      // Increase logging for debugging
      print('Requesting password reset for email: $email');

      // Set a longer expiration for the reset token
      final response = await _supabaseClient.auth.resetPasswordForEmail(email,
          redirectTo: null // Let Supabase handle the redirect
          );

      print('Password reset email sent successfully');
    } catch (e) {
      print('Error sending password reset email: $e');
      throw Exception('Failed to send reset email: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabaseClient.auth.updateUser(
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
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) {
      print('getUserProfile: No user ID available');
      return null;
    }

    final user = userId ?? currentUser.id;
    print('Fetching user profile for ID: $user');

    try {
      final response = await _supabaseClient
          .from('users')
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
      final response = await _supabaseClient.auth.verifyOTP(
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First, verify which columns exist in the table
      final safeData = Map<String, dynamic>.from(data);
      final updatedData = {
        ...safeData,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabaseClient.from('users').update(updatedData).eq('id', user.id);
      print(
          'Successfully updated user profile: ${updatedData.keys.join(', ')}');
    } catch (e) {
      if (e.toString().contains('Could not find')) {
        // If we get a PostgrestException about missing columns, try to update each field individually
        print(
            'Warning: Schema error detected. Trying individual field updates...');

        // Always update the timestamp
        try {
          await _supabaseClient.from('users').update({
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', user.id);
        } catch (_) {
          // Ignore errors with timestamp update
        }

        // Try each field individually
        for (var entry in data.entries) {
          try {
            await _supabaseClient.from('users').update({
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabaseClient.from('anxiety_records').insert({
      'user_id': user.id,
      ...record,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAnxietyRecords() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final response = await _supabaseClient
        .from('anxiety_records')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Wellness logs methods (for moods, symptoms, stress levels)
  Future<void> saveWellnessLog(Map<String, dynamic> log) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Add the record to the wellness_logs table with all the needed fields
    await _supabaseClient.from('wellness_logs').insert({
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
  }

  Future<List<Map<String, dynamic>>> getWellnessLogs({String? userId}) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // If userId is provided, fetch logs for that user (for psychologists)
    // Otherwise, fetch logs for the current user (for patients)
    final targetUserId = userId ?? user.id;

    final response = await _supabaseClient
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Convert timestamp to ISO string for comparison
    final timestampString = timestamp.toIso8601String();

    await _supabaseClient
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _supabaseClient
          .from('wellness_logs')
          .delete()
          .eq('user_id', user.id);

      print('Successfully cleared all wellness logs for user: ${user.id}');
    } catch (e) {
      print('Error clearing wellness logs from Supabase: $e');
      throw Exception('Failed to clear wellness logs from database');
    }
  }

  // Get all patients assigned to a psychologist
  Future<List<Map<String, dynamic>>> getAssignedPatients() async {
    final user = _supabaseClient.auth.currentUser;
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
    final response = await _supabaseClient
        .from('users')
        .select()
        .eq('assigned_psychologist_id', user.id)
        .eq('role', 'patient');

    return List<Map<String, dynamic>>.from(response);
    */
  }

  // Get mood log statistics for a patient
  Future<Map<String, dynamic>> getPatientMoodStats(String patientId) async {
    final user = _supabaseClient.auth.currentUser;
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

  // Helper method to check if user is authenticated
  bool get isAuthenticated => _supabaseClient.auth.currentUser != null;

  // Get current user
  User? get currentUser => _supabaseClient.auth.currentUser;

  // Email verification methods
  Future<void> updateEmailVerificationStatus(String email) async {
    try {
      print('Updating email verification status for: $email');

      await _supabaseClient.from('users').update({
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First get the user's assigned psychologist ID
      final userProfile = await getUserProfile();
      if (userProfile == null) {
        // If no user profile found, try fetching a default psychologist
        final psychologists = await _supabaseClient
            .from('psychologists')
            .select()
            .limit(1)
            .maybeSingle();

        if (psychologists != null) {
          return _ensurePsychologistFields(psychologists);
        }
        return null;
      }

      // If user has assigned_psychologist_id, use it
      if (userProfile['assigned_psychologist_id'] != null) {
        final psychologistId = userProfile['assigned_psychologist_id'];

        // Get the psychologist details
        final psychologist = await _supabaseClient
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
        final psychologist = await _supabaseClient
            .from('psychologists')
            .select()
            .limit(1)
            .maybeSingle();

        // If a psychologist is found, assign it to the user
        if (psychologist != null) {
          await _supabaseClient
              .from('users')
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First try to create the table if it doesn't exist
      await createAppointmentsTableIfNotExists();

      // Query appointments table for this user
      try {
        final response = await _supabaseClient
            .from('appointments')
            .select()
            .eq('user_id', user.id)
            .order('appointment_date', ascending: false);

        if (response != null) {
          return List<Map<String, dynamic>>.from(response);
        }

        // If no appointments found, return empty list
        return [];
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('does not exist') ||
            errorMsg.contains('relation "appointments" does not exist')) {
          // If appointments table doesn't exist, check for appointment_request notifications
          final notifications = await _supabaseClient
              .from('notifications')
              .select()
              .eq('user_id', user.id)
              .eq('type', 'appointment_request')
              .order('created_at', ascending: false);

          if (notifications != null && notifications.isNotEmpty) {
            // Convert notifications to appointment format
            return notifications.map<Map<String, dynamic>>((notification) {
              // Parse the message to extract details
              final createdAt = DateTime.parse(notification['created_at']);

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
          throw e;
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
        await _supabaseClient.from('appointments').select('count').limit(1);
        Logger.info('Appointments table already exists');
        return true; // Table exists
      } catch (e) {
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('does not exist') ||
            errorMsg.contains('relation "appointments" does not exist')) {
          // Table doesn't exist, create it using SQL
          Logger.info('Creating appointments table...');
          final response =
              await _supabaseClient.rpc('create_appointments_table');
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // First try to create the table if it doesn't exist
      await createAppointmentsTableIfNotExists();

      // Get the current timestamp for created_at
      final timestamp = DateTime.now().toIso8601String();

      // Try to insert the appointment record
      final response = await _supabaseClient.from('appointments').insert({
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    debugPrint('getNotifications called with type: $type');

    try {
      // First get all notifications for this user
      var query =
          _supabaseClient.from('notifications').select().eq('user_id', user.id);

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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (hardDelete) {
      // Permanently delete the notification
      await _supabaseClient
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      debugPrint('Permanently deleted notification $id');
    } else {
      // Soft delete (mark as deleted)
      await _supabaseClient
          .from('notifications')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .eq('user_id', user.id);

      debugPrint('Soft-deleted notification $id');
    }
  }

  Future<void> clearAllNotifications({bool hardDelete = false}) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (hardDelete) {
      // Permanently delete all notifications
      await _supabaseClient
          .from('notifications')
          .delete()
          .eq('user_id', user.id);

      debugPrint('Permanently deleted all notifications for user ${user.id}');
    } else {
      // Soft delete (mark as deleted)
      await _supabaseClient
          .from('notifications')
          .update({'deleted_at': DateTime.now().toIso8601String()}).eq(
              'user_id', user.id);

      debugPrint('Soft-deleted all notifications for user ${user.id}');
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabaseClient
        .from('notifications')
        .update({'read': true})
        .eq('id', id)
        .eq('user_id', user.id);
  }

  Future<void> markAllNotificationsAsRead() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabaseClient
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabaseClient.from('notifications').insert({
      'user_id': user.id,
      'title': title,
      'message': message,
      'type': type,
      'related_screen': relatedScreen,
      'related_id': relatedId,
    });
  }

  // Additional psychologist methods
  Future<List<Map<String, dynamic>>> getAllPsychologists() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Query all psychologists from the database
      final response =
          await _supabaseClient.from('psychologists').select().order('name');

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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Update the user's assigned psychologist
      await _supabaseClient.from('users').update(
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
      'contact_email': psychologist['contact_email'] ?? 'contact@anxiease.com',
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
      final response = await _supabaseClient.storage
          .from('profile_pictures')
          .upload(filePath, imageFile,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: true));

      // Get public URL
      final imageUrl = _supabaseClient.storage
          .from('profile_pictures')
          .getPublicUrl(filePath);

      // Update psychologist record with image URL
      await _supabaseClient
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
      final psychologist = await _supabaseClient
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
      final files = await _supabaseClient.storage
          .from('profile_pictures')
          .list(path: 'psychologists');

      // Find files that start with the psychologist ID
      final profilePic = files
          .where((file) => file.name.startsWith(psychologistId))
          .firstOrNull;

      if (profilePic != null) {
        return _supabaseClient.storage
            .from('profile_pictures')
            .getPublicUrl('psychologists/${profilePic.name}');
      }

      return null;
    } catch (e) {
      Logger.error('Error fetching profile picture', e);
      return null;
    }
  }

  // Method to manually refresh an appointment's status from the database
  Future<Map<String, dynamic>?> refreshAppointmentStatus(
      String appointmentId) async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Query the appointments table for the specific appointment
      final response = await _supabaseClient
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
        final updatedResponse = await _supabaseClient
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Update the status in the database
      await _supabaseClient.from('appointments').update({
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
    final user = _supabaseClient.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final now = DateTime.now();
      final cutoffDate =
          now.subtract(const Duration(days: 30)).toIso8601String();
      int totalArchived = 0;

      // Get completed appointments older than 30 days
      final completedAppointments = await _supabaseClient
          .from('appointments')
          .update({'status': 'archived', 'updated_at': now.toIso8601String()})
          .eq('user_id', user.id)
          .eq('status', 'completed')
          .lt('appointment_date', cutoffDate)
          .select();

      totalArchived += completedAppointments.length;

      // Get expired but unattended appointments
      final expiredAppointments = await _supabaseClient
          .from('appointments')
          .update({'status': 'archived', 'updated_at': now.toIso8601String()})
          .eq('user_id', user.id)
          .or('status.eq.accepted,status.eq.approved')
          .lt('appointment_date', cutoffDate)
          .select();

      totalArchived += expiredAppointments.length;

      // Get old cancelled/denied appointments
      final cancelledAppointments = await _supabaseClient
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
}
