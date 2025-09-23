import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/wearable_device.dart';
import '../models/health_metrics.dart';
import '../models/baseline_heart_rate.dart';
import '../services/supabase_service.dart';
import '../services/iot_sensor_service.dart';
import '../services/anxiety_detection_engine.dart';
import '../services/notification_service.dart';
import '../services/device_sharing_service.dart';
import '../utils/logger.dart';

/// Comprehensive device service for wearable device integration
///
/// Handles:
/// - Device linking to user accounts
/// - Resting heart rate baseline collection
/// - Real-time data streaming via Firebase
/// - Permanent data storage via Supabase
class DeviceService extends ChangeNotifier {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final IoTSensorService _iotSensorService = IoTSensorService();
  final AnxietyDetectionEngine _anxietyDetectionEngine =
      AnxietyDetectionEngine();
  final NotificationService _notificationService = NotificationService();
  final DeviceSharingService _deviceSharingService = DeviceSharingService();

  // Firebase references
  FirebaseDatabase get _realtimeDb => FirebaseDatabase.instance;
  DatabaseReference? _deviceRef;
  StreamSubscription<DatabaseEvent>? _realtimeSubscription;

  // Current state
  WearableDevice? _linkedDevice;
  HealthMetrics? _currentMetrics;
  BaselineHeartRate? _currentBaseline;
  bool _isInitialized = false;
  bool _isRecordingBaseline = false;
  bool _isFinishingBaseline = false; // prevent double-finish races

  // Baseline recording state
  final List<double> _baselineReadings = [];
  DateTime? _baselineRecordingStartTime;
  Timer? _baselineRecordingTimer;
  StreamController<int>? _countdownController;
  StreamController<double>? _heartRateController;
  Completer<BaselineHeartRate>? _baselineRecordingCompleter;

  // Getters
  WearableDevice? get linkedDevice => _linkedDevice;
  HealthMetrics? get currentMetrics => _currentMetrics;
  BaselineHeartRate? get currentBaseline => _currentBaseline;
  bool get isInitialized => _isInitialized;
  bool get isRecordingBaseline => _isRecordingBaseline;
  bool get hasLinkedDevice => _linkedDevice != null;
  bool get hasBaseline => _currentBaseline != null;

  // Anxiety detection getters
  bool get canDetectAnxiety => hasBaseline && hasLinkedDevice;
  Map<String, dynamic> get anxietyDetectionStatus =>
      _anxietyDetectionEngine.getDetectionStatus();

  // Streams for real-time updates
  Stream<int>? get countdownStream => _countdownController?.stream;
  Stream<double>? get heartRateStream => _heartRateController?.stream;

  /// Ensure baseline stream controllers exist so UI can subscribe before starting
  void prepareBaselineStreams() {
    _countdownController ??= StreamController<int>.broadcast();
    _heartRateController ??= StreamController<double>.broadcast();
  }

  /// Initialize the device service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      AppLogger.d('DeviceService: Initializing...');

      // Initialize dependencies
      await _supabaseService.initialize();
      await _iotSensorService.initialize();

      // Load user's linked device and baseline
      await _loadLinkedDevice();

      _isInitialized = true;
      AppLogger.d('DeviceService: Initialized successfully');

      notifyListeners();
    } catch (e) {
      AppLogger.e('DeviceService: Initialization failed', e as Object?);
      rethrow;
    }
  }

  /// Link a device to the current user's account
  Future<bool> linkDevice(String deviceId) async {
    try {
      AppLogger.d('DeviceService: Linking device $deviceId');

      // Validate device ID format
      if (!_isValidDeviceId(deviceId)) {
        throw ArgumentError(
            'Invalid device ID format. Expected format: AnxieEaseXXX');
      }

      // Normalize device ID case (AnxieEase should have proper case)
      String normalizedDeviceId = deviceId;
      if (deviceId.toLowerCase().startsWith('anxieease')) {
        normalizedDeviceId = 'AnxieEase${deviceId.substring(9)}';
      }

      // For testing phase: Create user-specific virtual device ID
      final virtualDeviceId =
          await _deviceSharingService.getCurrentUserDeviceId();
      AppLogger.d(
          'DeviceService: Using virtual device ID for testing: $virtualDeviceId');

      AppLogger.d('DeviceService: Normalized device ID: $normalizedDeviceId');

      final user = _supabaseService.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if device exists and is available
      final existingDevice = await _getDeviceFromDatabase(normalizedDeviceId);
      if (existingDevice != null &&
          existingDevice.isLinked &&
          existingDevice.userId != user.id) {
        throw Exception('Device is already linked to another user');
      }

      // Validate device is actually connected and sending data
      AppLogger.d('DeviceService: Validating device connection...');
      final isConnected = await _validateDeviceConnection(normalizedDeviceId);
      if (!isConnected) {
        throw Exception('Device not found or not connected. Please ensure:\n'
            '1. Device is turned ON\n'
            '2. Device is connected to "AnxieEase" WiFi hotspot\n'
            '3. Hotspot password is "11112222"\n'
            '4. Device is actively sending data to the system');
      }

      // Create or update device record (use normalized device ID for Supabase)
      final device = WearableDevice(
        deviceId: normalizedDeviceId, // Use actual device ID for DB consistency
        deviceName:
            _deviceSharingService.getDeviceDisplayName(normalizedDeviceId),
        userId: user.id,
        linkedAt: DateTime.now(),
        isActive: true,
        lastSeenAt: DateTime.now(),
      );

      // Save to Supabase with real device ID
      await _saveDeviceToDatabase(device);

      // Set up Firebase real-time streaming (use virtual device ID for user separation)
      await _setupRealtimeStreaming(virtualDeviceId);

      _linkedDevice = device;

      // Update notification service to use the virtual device reference for Firebase
      _notificationService.updateDeviceReference(virtualDeviceId);

      // Reset anxiety detection engine for new device
      _anxietyDetectionEngine.reset();

      notifyListeners();

      AppLogger.d(
          'DeviceService: Device $normalizedDeviceId linked successfully (entered as: $deviceId)');
      return true;
    } catch (e) {
      AppLogger.e('DeviceService: Failed to link device', e as Object?);
      rethrow;
    }
  }

  /// Start collecting resting heart rate baseline (3-5 minute session)
  Future<BaselineHeartRate> recordRestingHeartRate({
    int durationMinutes = 3,
    String? notes,
  }) async {
    if (_linkedDevice == null) {
      throw Exception('No device linked. Please link a device first.');
    }

    if (_isRecordingBaseline) {
      throw Exception(
          'Already recording baseline. Please stop current recording first.');
    }

    try {
      AppLogger.d(
          'DeviceService: Starting baseline HR recording for ${durationMinutes}min');

      _isRecordingBaseline = true;
      _baselineReadings.clear();
      _baselineRecordingStartTime = DateTime.now();

      // Ensure countdown/HR streams exist for UI consumers
      prepareBaselineStreams();
      _baselineRecordingCompleter = Completer<BaselineHeartRate>();

      AppLogger.d('DeviceService: Baseline streams ready');

      // Ensure IoT sensor is running for realistic data
      await _iotSensorService.startSensors();
      AppLogger.d(
          'DeviceService: IoT sensors started, current HR: ${_iotSensorService.heartRate}');

      // Start countdown timer
      int remainingSeconds = durationMinutes * 60;
      AppLogger.d(
          'DeviceService: Starting timer with ${remainingSeconds}s total duration');
      // Emit initial value so UI updates immediately
      _countdownController?.add(remainingSeconds);

      _baselineRecordingTimer =
          Timer.periodic(const Duration(seconds: 1), (timer) {
        remainingSeconds--;
        AppLogger.d(
            'DeviceService: Timer tick - ${remainingSeconds}s remaining');
        _countdownController?.add(remainingSeconds);

        // Collect heart rate reading every 5 seconds
        if (remainingSeconds % 5 == 0) {
          AppLogger.d(
              'DeviceService: 5-second interval - collecting HR reading');
          _collectHeartRateReading();
        }

        if (remainingSeconds <= 0) {
          AppLogger.d('DeviceService: Timer completed, finishing recording');
          timer.cancel();
          // Use await to ensure proper completion
          _finishBaselineRecording(notes).then((_) {
            AppLogger.d(
                'DeviceService: Baseline recording finished successfully');
          }).catchError((e) {
            AppLogger.e('DeviceService: Error finishing baseline recording', e);
          });
        }
      });

      // Return a Future that completes when recording is done, with a safety timeout
      final totalSeconds = durationMinutes * 60;
      return _baselineRecordingCompleter!.future
          .timeout(Duration(seconds: totalSeconds + 15), onTimeout: () async {
        AppLogger.w(
            'DeviceService: Baseline recording timed out, forcing finish');
        try {
          // Attempt to finish gracefully
          return await _finishBaselineRecording(notes);
        } catch (e) {
          // If still failing but we have enough readings, compute baseline locally
          if (_baselineReadings.length >= 5) {
            final endTime = DateTime.now();
            final startTime = _baselineRecordingStartTime ??
                endTime.subtract(Duration(minutes: durationMinutes));
            final baseline = BaselineHeartRate.calculateBaseline(
              userId: _linkedDevice!.userId!,
              deviceId: _linkedDevice!.deviceId,
              readings: List<double>.from(_baselineReadings),
              startTime: startTime,
              endTime: endTime,
              notes: notes,
            );

            _currentBaseline = baseline;
            _cleanupBaselineRecording();
            AppLogger.w(
                'DeviceService: Returning locally computed baseline due to timeout');
            return baseline;
          }
          rethrow;
        }
      });
    } catch (e) {
      _isRecordingBaseline = false;
      _cleanupBaselineRecording();
      AppLogger.e(
          'DeviceService: Failed to start baseline recording', e as Object?);
      rethrow;
    }
  }

  /// Stop baseline recording early
  Future<BaselineHeartRate?> stopBaselineRecording() async {
    // If we're not actively recording anymore, try to return the most
    // up-to-date baseline (handles race when user taps Stop at 0s)
    if (!_isRecordingBaseline) {
      // If baseline already computed, return it
      if (_currentBaseline != null) {
        return _currentBaseline;
      }

      // If finishing is in progress, await the completer
      if (_baselineRecordingCompleter != null &&
          !_baselineRecordingCompleter!.isCompleted) {
        try {
          final result = await _baselineRecordingCompleter!.future;
          return result;
        } catch (_) {
          return null;
        }
      }

      return null;
    }

    _baselineRecordingTimer?.cancel();
    return await _finishBaselineRecording('Recording stopped early by user');
  }

  /// Forcefully abort any ongoing baseline recording and clean up.
  /// This prevents lingering timers/streams or timeouts from firing after the UI cancels.
  Future<void> abortBaselineRecording() async {
    try {
      _baselineRecordingTimer?.cancel();
      // If a completer is pending, complete it with an error to unblock waiters
      if (_baselineRecordingCompleter != null &&
          !_baselineRecordingCompleter!.isCompleted) {
        _baselineRecordingCompleter!
            .completeError(StateError('baseline_aborted'));
      }
      _isRecordingBaseline = false;
      _isFinishingBaseline = false;
      _cleanupBaselineRecording();
      notifyListeners();
    } catch (_) {
      // Best-effort abort; swallow errors
    }
  }

  /// Collect a single heart rate reading during baseline recording
  void _collectHeartRateReading() {
    try {
      // Prefer live metrics from the device stream if available
      double currentHR;
      bool worn = false;

      if (_currentMetrics != null && _currentMetrics!.heartRate != null) {
        currentHR = _currentMetrics!.heartRate!;
        worn = _currentMetrics!.isWorn;
      } else {
        // Fallback to simulator if no live data
        currentHR = _iotSensorService.heartRate;
        worn = _iotSensorService.isDeviceWorn;
      }

      // Collect only when the device is worn and we have a positive HR
      if (worn && currentHR > 0) {
        _baselineReadings.add(currentHR);
        _heartRateController?.add(currentHR);
        AppLogger.d(
            'DeviceService: Collected HR reading: ${currentHR.toStringAsFixed(1)} BPM (worn: $worn, live: ${_currentMetrics != null})');
      } else {
        AppLogger.d(
            'DeviceService: Skipped HR reading (hr: ${currentHR.toStringAsFixed(1)}, worn: $worn)');
      }
    } catch (e) {
      AppLogger.w('DeviceService: Error collecting HR reading: $e');
    }
  }

  /// Finish baseline recording and calculate result
  Future<BaselineHeartRate> _finishBaselineRecording(String? notes) async {
    // Guard against multiple concurrent finish attempts (timer + timeout + stop)
    if (_isFinishingBaseline) {
      if (_baselineRecordingCompleter != null &&
          !_baselineRecordingCompleter!.isCompleted) {
        return await _baselineRecordingCompleter!.future;
      }
      if (_currentBaseline != null) return _currentBaseline!;
    }

    _isFinishingBaseline = true;
    try {
      AppLogger.d('DeviceService: Finishing baseline recording');

      _isRecordingBaseline = false;
      _baselineRecordingTimer?.cancel();

      final endTime = DateTime.now();
      final startTime = _baselineRecordingStartTime ??
          endTime.subtract(const Duration(minutes: 3));

      if (_baselineReadings.isEmpty) {
        throw Exception(
            'Not enough data collected to compute heart rate. Please ensure device is worn properly and try again.');
      }

      if (_baselineReadings.length < 5) {
        throw Exception(
            'Not enough data collected to compute heart rate. Need at least ${5 - _baselineReadings.length} more readings. Please try recording for a longer period.');
      }

      // Calculate baseline
      final baseline = BaselineHeartRate.calculateBaseline(
        userId: _linkedDevice!.userId!,
        deviceId: _linkedDevice!.deviceId,
        readings: _baselineReadings,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );

      // Always update local state first for immediate UI feedback
      _currentBaseline = baseline;
      final updatedDevice = _linkedDevice!.copyWith(
        baselineHR: baseline.baselineHR,
        baselineUpdatedAt: DateTime.now(),
      );
      _linkedDevice = updatedDevice;

      // Save to Supabase and Firebase (best effort, don't block UI completion)
      AppLogger.d(
          'DeviceService: Saving baseline to databases: ${baseline.baselineHR.toStringAsFixed(1)} BPM');
      try {
        await _saveBaselineToDatabase(baseline);
        await _saveDeviceToDatabase(updatedDevice);

        // Also save baseline to Firebase for Cloud Functions access
        await _saveBaselineToFirebase(baseline);

        AppLogger.d(
            'DeviceService: Baseline and device saved to all databases successfully');
      } catch (e) {
        AppLogger.w(
            'DeviceService: Database save failed, baseline available locally: $e');
        // Don't rethrow - allow completion with local baseline
      }

      // Complete the future BEFORE cleanup so timeout won't fire
      final completer = _baselineRecordingCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(baseline);
      }

      _cleanupBaselineRecording();
      notifyListeners();

      AppLogger.d(
          'DeviceService: Baseline recording completed: ${baseline.baselineHR.toStringAsFixed(1)} BPM');
      return baseline;
    } catch (e) {
      // Complete error BEFORE cleanup so waiters are released
      final completer = _baselineRecordingCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e);
      }
      _cleanupBaselineRecording();
      AppLogger.e(
          'DeviceService: Failed to finish baseline recording', e as Object?);
      rethrow;
    } finally {
      _isFinishingBaseline = false;
    }
  }

  /// Clean up baseline recording resources
  void _cleanupBaselineRecording() {
    _baselineRecordingTimer?.cancel();
    _countdownController?.close();
    _heartRateController?.close();
    _countdownController = null;
    _heartRateController = null;
    _baselineRecordingCompleter = null;
    _baselineReadings.clear();
    _baselineRecordingStartTime = null;
  }

  /// Validate device connection by checking if it's sending data to Firebase
  Future<bool> _validateDeviceConnection(String deviceId) async {
    try {
      AppLogger.d('DeviceService: Validating device: $deviceId');
      final deviceRef = _realtimeDb.ref('devices/$deviceId');

      // Check if device exists in Firebase
      final snapshot = await deviceRef.once();
      if (!snapshot.snapshot.exists) {
        AppLogger.w(
            'DeviceService: Device $deviceId not found in Firebase at path: devices/$deviceId');
        return false;
      }

      AppLogger.d('DeviceService: Device $deviceId found in Firebase');

      // Check if device has recent data
      final currentRef = deviceRef.child('current');
      final currentSnapshot = await currentRef.once();

      if (!currentSnapshot.snapshot.exists) {
        AppLogger.w(
            'DeviceService: No current data for device $deviceId at path: devices/$deviceId/current');
        return false;
      }

      AppLogger.d('DeviceService: Current data found for device $deviceId');

      final data =
          Map<String, dynamic>.from(currentSnapshot.snapshot.value as Map);

      AppLogger.d(
          'DeviceService: Device $deviceId data keys: ${data.keys.toList()}');
      AppLogger.d(
          'DeviceService: Device $deviceId timestamp: ${data['timestamp']}');
      AppLogger.d(
          'DeviceService: Device $deviceId battery: ${data['battPerc']}');
      AppLogger.d('DeviceService: Device $deviceId status: ${data['status']}');

      // Check if data is recent (within last 60 seconds for setup)
      final timestampValue = data['timestamp'];
      if (timestampValue != null) {
        DateTime? dataTime;

        // Handle different timestamp formats
        if (timestampValue is int) {
          dataTime = DateTime.fromMillisecondsSinceEpoch(timestampValue);
        } else if (timestampValue is String) {
          try {
            // Try parsing as ISO string first
            dataTime = DateTime.parse(timestampValue);
          } catch (e) {
            try {
              // Try parsing as int string
              final intValue = int.tryParse(timestampValue);
              if (intValue != null) {
                dataTime = DateTime.fromMillisecondsSinceEpoch(intValue);
              }
            } catch (e2) {
              // Try parsing custom format like "2025-09-23 00:16:00"
              try {
                dataTime = DateTime.parse(timestampValue.replaceAll(' ', 'T'));
              } catch (e3) {
                AppLogger.w(
                    'DeviceService: Could not parse timestamp: $timestampValue');
              }
            }
          }
        }

        if (dataTime != null) {
          final timeDifference = DateTime.now().difference(dataTime);

          if (timeDifference.inSeconds > 60) {
            AppLogger.w(
                'DeviceService: Device $deviceId data is stale (${timeDifference.inSeconds}s old)');
            return false;
          }
        }
      }

      // Determine connection status more flexibly for device setup
      final rawConn = (data['connectionStatus'] ?? '').toString().toLowerCase();
      final isConnectedFlag = data['isConnected'];
      final hasVitals = (data['heartRate'] != null) || (data['spo2'] != null);
      final hasBattery = data['battPerc'] != null;
      final isExplicitlyDisconnected =
          rawConn == 'disconnected' || isConnectedFlag == false;

      // For device setup validation, we're more lenient:
      // - Device just needs to be sending ANY data (not necessarily worn)
      // - Check if device has recent timestamp and battery info
      // - Don't require worn status during setup phase
      final hasRecentData = timestampValue != null;
      final deviceSendingData =
          hasRecentData && (hasBattery || hasVitals || data.isNotEmpty);

      var isConnected = !isExplicitlyDisconnected && deviceSendingData;

      if (!isConnected) {
        AppLogger.w(
            'DeviceService: Device $deviceId appears inactive (no recent data or explicitly disconnected)');
        return false;
      }

      AppLogger.d(
          'DeviceService: Device $deviceId validation successful - connected, data: $deviceSendingData, battery: $hasBattery');
      return true;
    } catch (e) {
      AppLogger.e('DeviceService: Device validation error', e as Object?);
      return false;
    }
  }

  /// Set up real-time data streaming from Firebase
  Future<void> _setupRealtimeStreaming(String deviceId) async {
    try {
      // Extract real device ID from virtual device ID for Firebase streaming
      String realDeviceId = deviceId;
      if (deviceId.contains('_')) {
        realDeviceId = deviceId.split('_')[0];
      }

      AppLogger.d(
          'DeviceService: Setting up streaming for virtual device $deviceId, reading from real device $realDeviceId');

      _deviceRef = _realtimeDb.ref('devices/$realDeviceId/current');

      // Cancel existing subscription
      await _realtimeSubscription?.cancel();

      // Listen for real-time updates
      _realtimeSubscription = _deviceRef!.onValue.listen(
        (event) {
          if (event.snapshot.exists) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            _updateCurrentMetrics(data);
          }
        },
        onError: (error) {
          AppLogger.e(
              'DeviceService: Firebase streaming error', error as Object?);
        },
      );

      AppLogger.d(
          'DeviceService: Real-time streaming setup for device $deviceId, reading from Firebase path devices/$realDeviceId/current');
    } catch (e) {
      AppLogger.e(
          'DeviceService: Failed to setup real-time streaming', e as Object?);
    }
  }

  // Data storage optimization variables
  DateTime? _lastStoredDataTime;
  HealthMetrics? _lastStoredMetrics;
  final Duration _minStorageInterval =
      const Duration(minutes: 5); // Store data every 5 minutes minimum
  final List<HealthMetrics> _recentReadings = [];
  // Feature flag: disable client writes to Firebase RTDB by default since
  // the app uses Supabase auth (no Firebase auth token). The wearable device
  // continues to write to devices/<id>/current; the client only reads.
  bool _enableClientFirebaseWrites = false;
  void enableClientFirebaseWrites(bool enable) {
    _enableClientFirebaseWrites = enable;
  }

  /// Update current health metrics from Firebase data
  void _updateCurrentMetrics(Map<String, dynamic> data) {
    try {
      var metrics = HealthMetrics.fromFirebase(
        data,
        baselineHR: _linkedDevice?.baselineHR,
      );

      // Suppress misleading values when data is stale or the device isn't worn
      final now = DateTime.now();
      final ageSec = now.difference(metrics.timestamp).inSeconds;
      final isStale = ageSec > 60; // consider data older than 60s as stale

      if (isStale) {
        AppLogger.w(
            'DeviceService: Stale data (${ageSec}s old) - forcing not worn and hiding HR/SpO2/Temp');
        metrics = HealthMetrics(
          heartRate: null,
          spo2: null,
          bodyTemperature: null,
          ambientTemperature: metrics.ambientTemperature,
          movementLevel: null,
          batteryLevel: metrics.batteryLevel,
          isWorn: false,
          isConnected: false,
          timestamp: metrics.timestamp,
          baselineHR: metrics.baselineHR,
        );
      } else if (!metrics.isWorn) {
        // If not worn, ensure we don't show HR/SpO2/Temp values
        if (metrics.heartRate != null ||
            metrics.spo2 != null ||
            metrics.bodyTemperature != null) {
          AppLogger.d(
              'DeviceService: Device not worn - suppressing HR/SpO2/Temp display values');
        }
        metrics = HealthMetrics(
          heartRate: null,
          spo2: null,
          bodyTemperature: null,
          ambientTemperature: metrics.ambientTemperature,
          movementLevel: metrics.movementLevel,
          batteryLevel: metrics.batteryLevel,
          isWorn: false,
          isConnected: metrics.isConnected,
          timestamp: metrics.timestamp,
          baselineHR: metrics.baselineHR,
        );
      }

      _currentMetrics = metrics;
      _recentReadings.add(metrics);

      // Keep only last 30 readings (5 minutes worth at 10s intervals)
      if (_recentReadings.length > 30) {
        _recentReadings.removeAt(0);
      }

      // Run anxiety detection if we have valid data and baseline
      if (metrics.isWorn &&
          metrics.heartRate != null &&
          metrics.spo2 != null &&
          metrics.movementLevel != null &&
          _currentBaseline != null) {
        _runAnxietyDetection(metrics);
      }

      notifyListeners();

      // Smart data storage: only store if significant change or time interval
      _handleSmartDataStorage(metrics);

      // Update device last seen time
      if (_linkedDevice != null) {
        _linkedDevice = _linkedDevice!.copyWith(
          isActive: metrics.isConnected,
          batteryLevel: metrics.batteryLevel,
          lastSeenAt: DateTime.now(),
        );
      }
    } catch (e) {
      AppLogger.w('DeviceService: Error updating metrics: $e');
    }
  }

  /// Handle smart data storage to reduce Firebase writes
  void _handleSmartDataStorage(HealthMetrics metrics) {
    // Skip all RTDB writes unless explicitly enabled
    if (!_enableClientFirebaseWrites) {
      return;
    }
    final now = DateTime.now();

    // Check if we should store this data point
    bool shouldStore = false;
    String? reason;

    // 1. Store if minimum time interval has passed
    if (_lastStoredDataTime == null ||
        now.difference(_lastStoredDataTime!) >= _minStorageInterval) {
      shouldStore = true;
      reason = 'time_interval';
    }

    // 2. Store if significant change detected
    if (_lastStoredMetrics != null && !shouldStore) {
      if (_hasSignificantChange(metrics, _lastStoredMetrics!)) {
        shouldStore = true;
        reason = 'significant_change';
      }
    }

    // 3. Store if alert condition detected (baseline-relative HR thresholds)
    final severity = _computeAnxietySeverity();
    if (!shouldStore && severity != null) {
      shouldStore = true;
      reason = 'anxiety_severity';
    }

    // Store data if any condition is met
    if (shouldStore) {
      _storeDataToHistory(metrics, reason!);
      _lastStoredDataTime = now;
      _lastStoredMetrics = metrics;
    }

    // Always update current data (overwrites previous)
    _updateCurrentDataInFirebase(metrics);
  }

  /// Check if there's a significant change in health metrics
  bool _hasSignificantChange(HealthMetrics current, HealthMetrics previous) {
    // Heart rate change > 10 BPM
    if (current.heartRate != null && previous.heartRate != null) {
      if ((current.heartRate! - previous.heartRate!).abs() > 10) {
        return true;
      }
    }

    // SpO2 change > 2%
    if (current.spo2 != null && previous.spo2 != null) {
      if ((current.spo2! - previous.spo2!).abs() > 2) {
        return true;
      }
    }

    // Temperature change > 0.5°C
    if (current.bodyTemperature != null && previous.bodyTemperature != null) {
      if ((current.bodyTemperature! - previous.bodyTemperature!).abs() > 0.5) {
        return true;
      }
    }

    // Movement level change > 20%
    if (current.movementLevel != null && previous.movementLevel != null) {
      if ((current.movementLevel! - previous.movementLevel!).abs() > 20) {
        return true;
      }
    }

    return false;
  }

  /// Check if current metrics indicate an alert condition
  // Removed legacy _isAlertCondition; replaced by _computeAnxietySeverity() usage.

  /// Compute anxiety severity based on recent HR relative to baseline.
  /// Returns 'mild' | 'moderate' | 'severe' when sustained elevation is detected, otherwise null.
  String? _computeAnxietySeverity() {
    // Must have user baseline HR to compare
    if (_linkedDevice?.baselineHR == null) return null;
    final baselineHR = _linkedDevice!.baselineHR!;

    // Average human baseline temp (no per-user baseline temp)
    const avgBaselineTempC = 36.7;

    // Sustained window and thresholds
    const sustainedSeconds = 45;
    const mildHrFactor = 1.25;
    const moderateHrFactor = 1.35;
    const severeHrFactor = 1.50;
    const mildTempDelta = 0.5; // °C above avg baseline temp
    const moderateTempDelta = 0.8;
    const severeTempDelta = 1.0;

    // Use last 60s of readings while worn and connected, with HR and body temp
    final cutoff = DateTime.now().subtract(const Duration(seconds: 60));
    final readings = _recentReadings
        .where((r) =>
            r.isWorn &&
            r.isConnected &&
            r.heartRate != null &&
            r.bodyTemperature != null &&
            r.timestamp.isAfter(cutoff))
        .toList();

    if (readings.length < 3) return null; // need enough points

    bool sustainedFor(String level, double hrFactor, double tempDelta) {
      // Filter readings that meet both HR% and Temp conditions
      final passing = readings.where((r) {
        final hrOk = r.heartRate! >= baselineHR * hrFactor;
        final tempOk = r.bodyTemperature! >= (avgBaselineTempC + tempDelta);
        // Ignore temp rises explained by high ambient: require body - ambient >= 0.5 when ambient present
        final ambientOk = r.ambientTemperature == null
            ? true
            : (r.bodyTemperature! - r.ambientTemperature!) >= 0.5;
        return hrOk && tempOk && ambientOk;
      }).toList();

      if (passing.length < 3) return false;
      passing.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final durationSec =
          passing.last.timestamp.difference(passing.first.timestamp).inSeconds;
      return durationSec >= sustainedSeconds;
    }

    // Check from most severe to mild
    if (sustainedFor('severe', severeHrFactor, severeTempDelta))
      return 'severe';
    if (sustainedFor('moderate', moderateHrFactor, moderateTempDelta))
      return 'moderate';
    if (sustainedFor('mild', mildHrFactor, mildTempDelta)) return 'mild';
    return null;
  }

  /// Store health data to Firebase history (only when needed)
  Future<void> _storeDataToHistory(HealthMetrics metrics, String reason) async {
    if (!_enableClientFirebaseWrites) return;
    if (_linkedDevice == null) return;

    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final historyRef = _realtimeDb.ref(
          'health_metrics/${user.id}/${_linkedDevice!.deviceId}/history/$timestamp');

      final severity = _computeAnxietySeverity();
      await historyRef.set({
        ...metrics.toFirebase(),
        'storage_reason': reason,
        if (severity != null) 'severityLevel': severity,
        if (_linkedDevice?.baselineHR != null)
          'baselineHR': _linkedDevice!.baselineHR,
        if (metrics.heartRate != null && _linkedDevice?.baselineHR != null)
          'hrDelta': (metrics.heartRate! - _linkedDevice!.baselineHR!).round(),
        'timestamp': timestamp,
      });

      AppLogger.d('DeviceService: Stored health data - reason: $reason');

      // Store alert if anxiety severity is present
      if (severity != null) {
        await _storeAlert(metrics, timestamp, severity: severity);
      }
    } catch (e) {
      AppLogger.e(
          'DeviceService: Failed to store health data history', e as Object?);
    }
  }

  /// Update current data in Firebase (always overwrites)
  Future<void> _updateCurrentDataInFirebase(HealthMetrics metrics) async {
    if (!_enableClientFirebaseWrites) return;
    if (_linkedDevice == null) return;

    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      final currentRef = _realtimeDb
          .ref('health_metrics/${user.id}/${_linkedDevice!.deviceId}/current');

      await currentRef.set({
        ...metrics.toFirebase(),
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      AppLogger.w('DeviceService: Failed to update current data: $e');
    }
  }

  /// Run comprehensive anxiety detection on current metrics
  void _runAnxietyDetection(HealthMetrics metrics) {
    try {
      if (_currentBaseline == null) {
        AppLogger.d(
            'DeviceService: No baseline available for anxiety detection');
        return;
      }

      // Run the comprehensive anxiety detection
      final result = _anxietyDetectionEngine.detectAnxiety(
        currentHeartRate: metrics.heartRate!,
        restingHeartRate: _currentBaseline!.baselineHR,
        currentSpO2: metrics.spo2!,
        currentMovement: metrics.movementLevel!,
        bodyTemperature: metrics.bodyTemperature,
      );

      // Log detection result
      AppLogger.d('DeviceService: Anxiety detection - '
          'Triggered: ${result.triggered}, '
          'Reason: ${result.reason}, '
          'Confidence: ${result.confidenceLevel.toStringAsFixed(2)}, '
          'Needs confirmation: ${result.requiresUserConfirmation}');

      // Handle the detection result
      if (result.triggered) {
        _handleAnxietyDetectionResult(result, metrics);
      }
    } catch (e) {
      AppLogger.e('DeviceService: Error in anxiety detection', e as Object?);
    }
  }

  /// Handle anxiety detection results
  Future<void> _handleAnxietyDetectionResult(
      AnxietyDetectionResult result, HealthMetrics metrics) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Store the detection result
      await _storeAnxietyAlert(result, metrics, timestamp);

      // Send notification based on confidence level and confirmation requirement
      if (!result.requiresUserConfirmation || result.confidenceLevel >= 0.8) {
        await _sendAnxietyNotification(result, metrics);
      } else {
        // For lower confidence detections, we might want to request user confirmation
        await _requestUserConfirmation(result, metrics);
      }
    } catch (e) {
      AppLogger.e('DeviceService: Error handling anxiety detection result',
          e as Object?);
    }
  }

  /// Store anxiety alert in Firebase
  Future<void> _storeAnxietyAlert(AnxietyDetectionResult result,
      HealthMetrics metrics, int timestamp) async {
    if (!_enableClientFirebaseWrites) return;
    if (_linkedDevice == null) return;

    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      final alertRef = _realtimeDb.ref(
          'anxiety_alerts/${user.id}/${_linkedDevice!.deviceId}/$timestamp');

      await alertRef.set({
        'triggered': result.triggered,
        'reason': result.reason,
        'confidenceLevel': result.confidenceLevel,
        'requiresUserConfirmation': result.requiresUserConfirmation,
        'metrics': result.metrics,
        'abnormalMetrics': result.abnormalMetrics,
        'timestamp': timestamp,
        'deviceId': _linkedDevice!.deviceId,
        'baseline': _currentBaseline!.baselineHR,
        'resolved': false,
      });

      AppLogger.d('DeviceService: Anxiety alert stored - ${result.reason}');
    } catch (e) {
      AppLogger.e('DeviceService: Failed to store anxiety alert', e as Object?);
    }
  }

  /// Send anxiety notification with enhanced content
  Future<void> _sendAnxietyNotification(
      AnxietyDetectionResult result, HealthMetrics metrics) async {
    try {
      // Generate notification content based on detection reason
      final notificationContent = _generateNotificationContent(result, metrics);

      AppLogger.d('DeviceService: ANXIETY NOTIFICATION - '
          'Reason: ${result.reason}, '
          'Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(0)}%, '
          'HR: ${metrics.heartRate}, '
          'SpO2: ${metrics.spo2}, '
          'Movement: ${metrics.movementLevel}');

      // Store notification for analytics
      await _storeNotificationEvent('anxiety_alert', result, metrics);

      // TODO: Integrate with your notification service here
      // Examples based on detection type:
      // - Push notification to user's device
      // - Send to emergency contacts for critical alerts
      // - Log to health monitoring dashboard
      // NotificationService.sendAnxietyAlert(notificationContent, result.confidenceLevel);
      notificationContent
          .toString(); // prevent unused local var warning until integration
    } catch (e) {
      AppLogger.e(
          'DeviceService: Failed to send anxiety notification', e as Object?);
    }
  }

  /// Request user confirmation for low-confidence detections
  Future<void> _requestUserConfirmation(
      AnxietyDetectionResult result, HealthMetrics metrics) async {
    try {
      AppLogger.d('DeviceService: REQUESTING USER CONFIRMATION - '
          'Reason: ${result.reason}, '
          'Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(0)}%');

      // Store confirmation request for analytics
      await _storeNotificationEvent('confirmation_request', result, metrics);

      // TODO: Show user prompt or notification asking for confirmation
      // This could be:
      // - In-app dialog with "Are you feeling anxious?"
      // - Push notification with yes/no actions
      // - Gentle vibration pattern with app prompt
      // NotificationService.requestAnxietyConfirmation(result, metrics);
    } catch (e) {
      AppLogger.e(
          'DeviceService: Failed to request user confirmation', e as Object?);
    }
  }

  /// Generate notification content based on detection result
  Map<String, String> _generateNotificationContent(
      AnxietyDetectionResult result, HealthMetrics metrics) {
    switch (result.reason) {
      case 'criticalSpO2':
        return {
          'title': 'Critical Alert: Low Oxygen',
          'body':
              'Your blood oxygen level is critically low (${metrics.spo2?.toStringAsFixed(0)}%). Please seek immediate medical attention if you feel unwell.',
        };
      case 'combinedHRMovement':
        return {
          'title': 'Anxiety Alert: Heart Rate + Movement',
          'body':
              'Elevated heart rate (${metrics.heartRate?.toStringAsFixed(0)} BPM) and unusual movement detected. Try your breathing exercises.',
        };
      case 'combinedHRSpO2':
        return {
          'title': 'Anxiety Alert: Heart Rate + Oxygen',
          'body':
              'High heart rate (${metrics.heartRate?.toStringAsFixed(0)} BPM) and low oxygen (${metrics.spo2?.toStringAsFixed(0)}%) detected.',
        };
      case 'highHR':
        final baselineHR = _currentBaseline?.baselineHR ?? 70;
        final percentAbove =
            ((metrics.heartRate! - baselineHR) / baselineHR * 100).round();
        return {
          'title': 'High Heart Rate Detected',
          'body':
              'Your heart rate is elevated (${metrics.heartRate?.toStringAsFixed(0)} BPM, ${percentAbove}% above baseline). Consider using relaxation techniques.',
        };
      case 'lowSpO2':
        return {
          'title': 'Low Oxygen Levels',
          'body':
              'Your oxygen levels are below normal (${metrics.spo2?.toStringAsFixed(0)}%). Are you feeling okay?',
        };
      case 'movementSpikes':
        return {
          'title': 'Unusual Movement Detected',
          'body':
              'We detected some unusual movement patterns. Are you experiencing anxiety or restlessness?',
        };
      default:
        return {
          'title': 'Anxiety Alert',
          'body':
              'We detected some changes that might indicate anxiety. Take a moment to check in with yourself.',
        };
    }
  }

  /// Store notification event for analytics and history
  Future<void> _storeNotificationEvent(String eventType,
      AnxietyDetectionResult result, HealthMetrics metrics) async {
    if (!_enableClientFirebaseWrites) return;
    if (_linkedDevice == null) return;

    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final eventRef = _realtimeDb.ref(
          'notification_events/${user.id}/${_linkedDevice!.deviceId}/$timestamp');

      await eventRef.set({
        'eventType': eventType,
        'reason': result.reason,
        'confidenceLevel': result.confidenceLevel,
        'requiresUserConfirmation': result.requiresUserConfirmation,
        'heartRate': metrics.heartRate,
        'spO2': metrics.spo2,
        'movementLevel': metrics.movementLevel,
        'bodyTemperature': metrics.bodyTemperature,
        'baselineHR': _currentBaseline?.baselineHR,
        'timestamp': timestamp,
        'deviceId': _linkedDevice!.deviceId,
      });

      AppLogger.d('DeviceService: Notification event stored - $eventType');
    } catch (e) {
      AppLogger.e(
          'DeviceService: Failed to store notification event', e as Object?);
    }
  }

  /// Store alert data
  Future<void> _storeAlert(HealthMetrics metrics, int timestamp,
      {String? severity}) async {
    if (!_enableClientFirebaseWrites) return;
    if (_linkedDevice == null) return;

    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      String alertType = 'unknown';

      if (metrics.heartRate != null && metrics.heartRate! > 100) {
        alertType = 'high_heart_rate';
      } else if (metrics.spo2 != null && metrics.spo2! < 95) {
        alertType = 'low_spo2';
      } else if (metrics.bodyTemperature != null &&
          metrics.bodyTemperature! > 37.5) {
        alertType = 'high_temperature';
      } else if (!metrics.isConnected) {
        alertType = 'device_disconnected';
      } else if (!metrics.isWorn) {
        alertType = 'device_not_worn';
      }

      final alertRef = _realtimeDb.ref(
          'health_metrics/${user.id}/${_linkedDevice!.deviceId}/alerts/$timestamp');

      final sev = severity ?? _computeAnxietySeverity();
      final payload = <String, dynamic>{
        ...metrics.toFirebase(),
        'alert_type': alertType,
        if (sev != null) 'severityLevel': sev,
        if (_linkedDevice?.baselineHR != null)
          'baselineHR': _linkedDevice!.baselineHR,
        if (metrics.heartRate != null && _linkedDevice?.baselineHR != null)
          'hrDelta': (metrics.heartRate! - _linkedDevice!.baselineHR!).round(),
        'timestamp': timestamp,
        'resolved': false,
      };

      await alertRef.set(payload);

      AppLogger.d('DeviceService: Alert stored - type: $alertType');
    } catch (e) {
      AppLogger.e('DeviceService: Failed to store alert', e as Object?);
    }
  }

  /// Load user's linked device from Supabase
  Future<void> _loadLinkedDevice() async {
    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      final response = await _supabaseService.client
          .from('wearable_devices')
          .select()
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        _linkedDevice = WearableDevice.fromSupabase(response);

        // Load baseline data
        await _loadBaselineData();

        // Set up real-time streaming
        await _setupRealtimeStreaming(_linkedDevice!.deviceId);

        // Inform NotificationService about the current deviceId
        NotificationService().updateDeviceReference(_linkedDevice!.deviceId);

        AppLogger.d(
            'DeviceService: Loaded linked device: ${_linkedDevice!.deviceId}');
      }
    } catch (e) {
      AppLogger.w('DeviceService: Error loading linked device: $e');
    }
  }

  /// Load baseline heart rate data from Supabase
  Future<void> _loadBaselineData() async {
    if (_linkedDevice == null) return;

    try {
      final response = await _supabaseService.client
          .from('baseline_heart_rates')
          .select()
          .eq('user_id', _linkedDevice!.userId!)
          .eq('device_id', _linkedDevice!.deviceId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _currentBaseline = BaselineHeartRate.fromSupabase(response);
        AppLogger.d(
            'DeviceService: Loaded baseline: ${_currentBaseline!.baselineHR.toStringAsFixed(1)} BPM');
      }
    } catch (e) {
      AppLogger.w('DeviceService: Error loading baseline data: $e');
    }
  }

  /// Get device from Supabase database
  Future<WearableDevice?> _getDeviceFromDatabase(String deviceId) async {
    try {
      final response = await _supabaseService.client
          .from('wearable_devices')
          .select()
          .eq('device_id', deviceId)
          .maybeSingle();

      return response != null ? WearableDevice.fromSupabase(response) : null;
    } catch (e) {
      AppLogger.w('DeviceService: Error fetching device from database: $e');
      return null;
    }
  }

  /// Save device to Supabase database
  Future<void> _saveDeviceToDatabase(WearableDevice device) async {
    try {
      await _supabaseService.client
          .from('wearable_devices')
          .upsert(device.toSupabase());
    } catch (e) {
      AppLogger.e(
          'DeviceService: Error saving device to database', e as Object?);
      rethrow;
    }
  }

  /// Save baseline heart rate to Firebase for Cloud Functions access
  Future<void> _saveBaselineToFirebase(BaselineHeartRate baseline) async {
    if (!_enableClientFirebaseWrites) return;

    try {
      final user = _supabaseService.client.auth.currentUser;
      if (user == null) return;

      // Store baseline in Firebase format that Cloud Functions expect
      final baselineRef =
          _realtimeDb.ref('baselines/${user.id}/${baseline.deviceId}');

      await baselineRef.set({
        'baselineHR': baseline.baselineHR,
        'userId': baseline.userId,
        'deviceId': baseline.deviceId,
        'recordedReadings': baseline.recordedReadings,
        'recordingStartTime':
            baseline.recordingStartTime.millisecondsSinceEpoch,
        'recordingEndTime': baseline.recordingEndTime.millisecondsSinceEpoch,
        'recordingDurationMinutes': baseline.recordingDurationMinutes,
        'createdAt': baseline.createdAt.millisecondsSinceEpoch,
        'isActive': true,
        'notes': baseline.notes,
      });

      AppLogger.d(
          'DeviceService: Baseline saved to Firebase for Cloud Functions');
    } catch (e) {
      AppLogger.e(
          'DeviceService: Failed to save baseline to Firebase', e as Object?);
      // Don't rethrow - this is best effort for Cloud Functions
    }
  }

  /// Save baseline to Supabase database
  Future<void> _saveBaselineToDatabase(BaselineHeartRate baseline) async {
    try {
      AppLogger.d(
          'DeviceService: Saving baseline to Supabase: ${baseline.baselineHR.toStringAsFixed(1)} BPM');
      AppLogger.d('DeviceService: Baseline device_id: ${baseline.deviceId}');
      AppLogger.d('DeviceService: Baseline user_id: ${baseline.userId}');

      // Check if device exists in wearable_devices table first
      final deviceExists = await _supabaseService.client
          .from('wearable_devices')
          .select('device_id')
          .eq('device_id', baseline.deviceId)
          .maybeSingle();

      if (deviceExists == null) {
        AppLogger.w(
            'DeviceService: Device ${baseline.deviceId} not found in wearable_devices table');
        throw Exception(
            'Device not found in database. Please link device first.');
      }

      AppLogger.d('DeviceService: Device exists in wearable_devices table');

      // Prefer explicit find-update-or-insert to avoid ON CONFLICT constraint issues
      // 1) Try to find the latest existing baseline for this user + device (single canonical row)
      final existing = await _supabaseService.client
          .from('baseline_heart_rates')
          .select('id')
          .eq('user_id', baseline.userId)
          .eq('device_id', baseline.deviceId)
          .order('recording_end_time', ascending: false)
          .limit(1)
          .maybeSingle();

      final payload = {
        'baseline_hr': baseline.baselineHR,
        'recorded_readings': baseline.recordedReadings,
        'recording_start_time': baseline.recordingStartTime.toIso8601String(),
        'recording_end_time': baseline.recordingEndTime.toIso8601String(),
        'recording_duration_minutes': baseline.recordingDurationMinutes,
        'created_at': baseline.createdAt.toIso8601String(),
        'is_active':
            true, // kept for compatibility; single canonical row per device
        if (baseline.notes != null) 'notes': baseline.notes,
      };

      if (existing != null && existing['id'] != null) {
        // 2a) Update the existing active baseline row
        await _supabaseService.client
            .from('baseline_heart_rates')
            .update(payload)
            .eq('id', existing['id']);
        AppLogger.d('DeviceService: Updated existing active baseline');
      } else {
        // 2b) Insert new active baseline row
        await _supabaseService.client.from('baseline_heart_rates').insert({
          'user_id': baseline.userId,
          'device_id': baseline.deviceId,
          ...payload,
        });
        AppLogger.d('DeviceService: Inserted new active baseline');
      }

      AppLogger.d('DeviceService: Baseline saved to Supabase successfully');
    } catch (e) {
      // If RLS or constraint errors occur, attempt a deactivate-then-insert as a last resort
      final errStr = e.toString().toLowerCase();
      AppLogger.w('DeviceService: Baseline save error, details: $e');
      final looksLikeConstraint = errStr.contains('constraint') ||
          errStr.contains('on conflict') ||
          errStr.contains('duplicate key');

      if (looksLikeConstraint) {
        try {
          AppLogger.w(
              'DeviceService: Attempting fallback: deactivate existing then insert');
          await _supabaseService.client
              .from('baseline_heart_rates')
              .update({'is_active': false})
              .eq('user_id', baseline.userId)
              .eq('device_id', baseline.deviceId)
              .eq('is_active', true);

          await Future.delayed(const Duration(milliseconds: 100));

          await _supabaseService.client.from('baseline_heart_rates').insert({
            'user_id': baseline.userId,
            'device_id': baseline.deviceId,
            'baseline_hr': baseline.baselineHR,
            'recorded_readings': baseline.recordedReadings,
            'recording_start_time':
                baseline.recordingStartTime.toIso8601String(),
            'recording_end_time': baseline.recordingEndTime.toIso8601String(),
            'recording_duration_minutes': baseline.recordingDurationMinutes,
            'created_at': baseline.createdAt.toIso8601String(),
            'is_active': true,
            if (baseline.notes != null) 'notes': baseline.notes,
          });
          AppLogger.d(
              'DeviceService: Baseline saved via deactivate-then-insert fallback');
          return;
        } catch (e2) {
          AppLogger.e('DeviceService: Fallback deactivate-then-insert failed',
              e2 as Object?);
        }
      }

      // Final log but don't block UI completion
      AppLogger.w(
          'DeviceService: Baseline persistence ultimately failed; using local baseline only. Error: $e');
    }
  }

  /// Unlink current device
  Future<void> unlinkDevice() async {
    if (_linkedDevice == null) return;

    try {
      AppLogger.d('DeviceService: Unlinking device ${_linkedDevice!.deviceId}');

      // Update device in database
      await _supabaseService.client.from('wearable_devices').update({
        'user_id': null,
        'is_active': false,
        'linked_at': null,
      }).eq('device_id', _linkedDevice!.deviceId);

      // Stop real-time streaming
      await _realtimeSubscription?.cancel();
      _realtimeSubscription = null;
      _deviceRef = null;

      // Clear current state
      _linkedDevice = null;
      _currentMetrics = null;
      _currentBaseline = null;

      // Reset notification service to default device (fallback)
      _notificationService.updateDeviceReference('AnxieEase001');

      notifyListeners();
      AppLogger.d('DeviceService: Device unlinked successfully');
    } catch (e) {
      AppLogger.e('DeviceService: Failed to unlink device', e as Object?);
      rethrow;
    }
  }

  /// Validate device ID format
  bool _isValidDeviceId(String deviceId) {
    // Expected format: AnxieEaseXXX where XXX can be letters or numbers (case insensitive)
    final regex = RegExp(r'^anxieease[a-z0-9]{3}$', caseSensitive: false);
    return regex.hasMatch(deviceId);
  }

  // Removed unused _getDeviceDisplayName helper

  /// Update device battery level
  Future<void> updateDeviceBatteryLevel(double batteryLevel) async {
    if (_linkedDevice == null) return;

    try {
      await _supabaseService.client.from('wearable_devices').update({
        'battery_level': batteryLevel,
        'last_seen_at': DateTime.now().toIso8601String(),
      }).eq('device_id', _linkedDevice!.deviceId);

      _linkedDevice = _linkedDevice!.copyWith(
        batteryLevel: batteryLevel,
        lastSeenAt: DateTime.now(),
      );

      notifyListeners();
    } catch (e) {
      AppLogger.w('DeviceService: Error updating battery level: $e');
    }
  }

  /// Get device connection status
  bool get isDeviceConnected => _currentMetrics?.isConnected ?? false;

  /// Get device worn status
  bool get isDeviceWorn => _currentMetrics?.isWorn ?? false;

  /// Dispose resources
  @override
  void dispose() {
    _cleanupBaselineRecording();
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
