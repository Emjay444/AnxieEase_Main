import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  UserModel? _currentUser;
  bool _isLoading = false;

  AuthProvider() {
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    if (_supabaseService.isAuthenticated) {
      _setLoading(true);
      try {
        final userProfile = await _supabaseService.getUserProfile();
        if (userProfile != null) {
          _currentUser = UserModel.fromJson(userProfile);
        }
      } finally {
        _setLoading(false);
      }
    } else {
      // Clear any existing state if not authenticated
      _currentUser = null;
    }
    notifyListeners();
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _supabaseService.isAuthenticated;

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
    int? age,
    String? contactNumber,
    String? gender,
  }) async {
    try {
      _setLoading(true);

      final userData = {
        'first_name': firstName,
        'middle_name': middleName,
        'last_name': lastName,
        'age': age,
        'contact_number': contactNumber,
        'gender': gender,
      };

      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        userData: userData,
      );

      if (response.user != null) {
        final userProfile = await _supabaseService.getUserProfile();
        if (userProfile != null) {
          _currentUser = UserModel.fromJson(userProfile);
          notifyListeners();
        }
      }
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

      final response = await _supabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userProfile = await _supabaseService.getUserProfile();
        if (userProfile != null) {
          _currentUser = UserModel.fromJson(userProfile);
          notifyListeners();
        }
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _supabaseService.signOut();
      _currentUser = null;
      notifyListeners();
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
    int? age,
    String? contactNumber,
    String? gender,
  }) async {
    try {
      _setLoading(true);

      final updates = {
        if (firstName != null) 'first_name': firstName,
        if (middleName != null) 'middle_name': middleName,
        if (lastName != null) 'last_name': lastName,
        if (contactNumber != null) 'contact_number': contactNumber,
        if (gender != null) 'gender': gender,
      };

      // Only include age if it's valid and not null
      if (age != null && age > 0) {
        // We'll wrap this in a try-catch to handle potential schema issues
        try {
          await _supabaseService.updateUserProfile({'age': age});
        } catch (e) {
          print('Warning: Failed to update age: $e');
          // Continue with other updates even if age update fails
        }
      }

      // Update the rest of the profile fields
      await _supabaseService.updateUserProfile(updates);

      final userProfile = await _supabaseService.getUserProfile();
      if (userProfile != null) {
        _currentUser = UserModel.fromJson(userProfile);
        notifyListeners();
      }
    } catch (e) {
      print('Error updating profile: $e');
      throw Exception('Error updating profile: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUserProfile() async {
    if (!isAuthenticated) return;

    try {
      _setLoading(true);
      final userProfile = await _supabaseService.getUserProfile();
      if (userProfile != null) {
        _currentUser = UserModel.fromJson(userProfile);
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }
}
