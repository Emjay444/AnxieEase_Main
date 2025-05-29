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
