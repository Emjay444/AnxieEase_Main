import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Native Bluetooth Monitor Service
///
/// This service interfaces with the native Android Bluetooth service
/// to provide true background Bluetooth monitoring that persists even
/// when the Flutter app is closed.
class NativeBluetoothService {
  static const MethodChannel _channel = MethodChannel('bluetooth_monitor');
  static bool _isServiceRunning = false;

  /// Start native Bluetooth monitoring service
  ///
  /// This will start a native Android foreground service that:
  /// - Maintains Bluetooth connection in the background
  /// - Continues monitoring even when app is closed
  /// - Shows a persistent notification
  /// - Handles data processing and Firebase sync
  static Future<bool> startMonitoring({
    required String deviceAddress,
    required String userId,
  }) async {
    if (_isServiceRunning) {
      debugPrint('🛡️ Native Bluetooth service already running');
      return true;
    }

    try {
      debugPrint('🔵 NativeBluetoothService: About to call MethodChannel');
      debugPrint('🔵 NativeBluetoothService: Method = startBluetoothService');
      debugPrint('🔵 NativeBluetoothService: deviceAddress = $deviceAddress');
      debugPrint('🔵 NativeBluetoothService: userId = $userId');

      final result = await _channel.invokeMethod('startBluetoothService', {
        'deviceAddress': deviceAddress,
        'userId': userId,
      });

      debugPrint('🔵 NativeBluetoothService: MethodChannel returned: $result');

      if (result == true) {
        _isServiceRunning = true;
        debugPrint('✅ Native Bluetooth monitoring service started');
        debugPrint('📱 Device: $deviceAddress, User: $userId');
        return true;
      } else {
        debugPrint(
            '❌ Failed to start native Bluetooth service - result was: $result');
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException starting native Bluetooth service:');
      debugPrint('   Code: ${e.code}');
      debugPrint('   Message: ${e.message}');
      debugPrint('   Details: ${e.details}');
      return false;
    } catch (e) {
      debugPrint('❌ General error starting native Bluetooth service: $e');
      debugPrint('   Type: ${e.runtimeType}');
      return false;
    }
  }

  /// Stop native Bluetooth monitoring service
  static Future<bool> stopMonitoring() async {
    if (!_isServiceRunning) {
      debugPrint('🛡️ Native Bluetooth service not running');
      return true;
    }

    try {
      final result = await _channel.invokeMethod('stopBluetoothService');

      if (result == true) {
        _isServiceRunning = false;
        debugPrint('✅ Native Bluetooth monitoring service stopped');
        return true;
      } else {
        debugPrint('❌ Failed to stop native Bluetooth service');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error stopping native Bluetooth service: $e');
      return false;
    }
  }

  /// Check if native service is actually running (queries native side)
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _channel.invokeMethod('isServiceRunning');
      _isServiceRunning = result == true;
      debugPrint('🔍 Native service status check: $_isServiceRunning');
      return _isServiceRunning;
    } catch (e) {
      debugPrint('❌ Error checking native service status: $e');
      return false;
    }
  }

  /// Check if native service is running (cached value)
  static bool get isRunning => _isServiceRunning;

  /// Get service status information
  static Future<Map<String, dynamic>> getStatus() async {
    final actuallyRunning = await isServiceRunning();
    return {
      'isRunning': actuallyRunning,
      'serviceType': 'native_android',
      'capabilities': [
        'background_bluetooth',
        'survives_app_closure',
        'persistent_notification',
        'auto_reconnection',
      ],
    };
  }
}
