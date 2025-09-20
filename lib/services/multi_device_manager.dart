import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/wearable_device.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';

/// Enhanced Device Manager for Multiple Wearable Support
///
/// Features:
/// - Multi-device support per user
/// - Primary device selection
/// - Device-specific baselines and thresholds
/// - Cross-device data aggregation
class MultiDeviceManager extends ChangeNotifier {
  static final MultiDeviceManager _instance = MultiDeviceManager._internal();
  factory MultiDeviceManager() => _instance;
  MultiDeviceManager._internal();

  final SupabaseService _supabaseService = SupabaseService();

  List<WearableDevice> _userDevices = [];
  WearableDevice? _primaryDevice;
  Map<String, PersonalizedThresholds> _deviceThresholds = {};

  // Getters
  List<WearableDevice> get userDevices => _userDevices;
  WearableDevice? get primaryDevice => _primaryDevice;
  bool get hasMultipleDevices => _userDevices.length > 1;

  /// Load all user's devices
  Future<void> loadUserDevices() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      final response = await _supabaseService.client
          .from('wearable_devices')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true)
          .order('linked_at', ascending: false);

      _userDevices = response
          .map<WearableDevice>((data) => WearableDevice.fromSupabase(data))
          .toList();

      // Set primary device (most recently linked or explicitly marked)
      _primaryDevice = _userDevices.isNotEmpty ? _userDevices.first : null;

      // Load device-specific thresholds
      await _loadDeviceThresholds();

      notifyListeners();
      AppLogger.d('MultiDeviceManager: Loaded ${_userDevices.length} devices');
    } catch (e) {
      AppLogger.e('MultiDeviceManager: Error loading devices', e as Object?);
    }
  }

  /// Load personalized thresholds for each device
  Future<void> _loadDeviceThresholds() async {
    for (final device in _userDevices) {
      if (device.baselineHR != null) {
        _deviceThresholds[device.deviceId] = PersonalizedThresholds(
          baseline: device.baselineHR!,
          mild: device.baselineHR! + 15,
          moderate: device.baselineHR! + 25,
          severe: device.baselineHR! + 35,
        );
      }
    }
  }

  /// Set primary device for monitoring
  Future<void> setPrimaryDevice(String deviceId) async {
    final device = _userDevices.firstWhere(
      (d) => d.deviceId == deviceId,
      orElse: () => throw ArgumentError('Device not found'),
    );

    _primaryDevice = device;

    // Update in database
    await _supabaseService.client
        .from('wearable_devices')
        .update({'is_primary': true})
        .eq('device_id', deviceId)
        .eq('user_id', _supabaseService.client.auth.currentUser!.id);

    // Clear primary flag from other devices
    for (final otherDevice in _userDevices) {
      if (otherDevice.deviceId != deviceId) {
        await _supabaseService.client
            .from('wearable_devices')
            .update({'is_primary': false})
            .eq('device_id', otherDevice.deviceId)
            .eq('user_id', _supabaseService.client.auth.currentUser!.id);
      }
    }

    notifyListeners();
    AppLogger.d('MultiDeviceManager: Set primary device to $deviceId');
  }

  /// Get personalized thresholds for a specific device
  PersonalizedThresholds? getThresholds(String deviceId) {
    return _deviceThresholds[deviceId];
  }

  /// Add a new device
  Future<void> addDevice(WearableDevice device) async {
    _userDevices.add(device);

    // If this is the first device, make it primary
    if (_userDevices.length == 1) {
      _primaryDevice = device;
    }

    notifyListeners();
  }

  /// Remove a device
  Future<void> removeDevice(String deviceId) async {
    _userDevices.removeWhere((d) => d.deviceId == deviceId);
    _deviceThresholds.remove(deviceId);

    // If removed device was primary, set new primary
    if (_primaryDevice?.deviceId == deviceId && _userDevices.isNotEmpty) {
      _primaryDevice = _userDevices.first;
    }

    notifyListeners();
  }
}

/// Personalized thresholds based on user's baseline
class PersonalizedThresholds {
  final double baseline;
  final double mild;
  final double moderate;
  final double severe;

  PersonalizedThresholds({
    required this.baseline,
    required this.mild,
    required this.moderate,
    required this.severe,
  });

  /// Determine severity level for a given heart rate
  String getSeverityLevel(double heartRate) {
    if (heartRate >= severe) return 'severe';
    if (heartRate >= moderate) return 'moderate';
    if (heartRate >= mild) return 'mild';
    return 'normal';
  }

  /// Get threshold percentage above baseline
  double getThresholdPercentage(double heartRate) {
    return ((heartRate - baseline) / baseline) * 100;
  }

  Map<String, dynamic> toJson() => {
        'baseline': baseline,
        'mild': mild,
        'moderate': moderate,
        'severe': severe,
      };

  @override
  String toString() =>
      'Thresholds(baseline: $baseline, mild: $mild, moderate: $moderate, severe: $severe)';
}
