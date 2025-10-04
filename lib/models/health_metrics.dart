import 'device_reading.dart';

/// Model for real-time health metrics from wearable device
class HealthMetrics {
  /// Current heart rate in BPM
  final double? heartRate;

  /// Blood oxygen saturation percentage (0-100)
  final double? spo2;

  /// Body temperature in Celsius
  final double? bodyTemperature;

  /// Ambient temperature in Celsius
  final double? ambientTemperature;

  /// Movement/activity level (0-100, calculated from accelerometer)
  final double? movementLevel;

  /// Device battery percentage (0-100)
  final double? batteryLevel;

  /// Whether device is currently being worn
  final bool isWorn;

  /// Whether device is connected/online
  final bool isConnected;

  /// Timestamp when metrics were recorded
  final DateTime timestamp;

  /// User's resting heart rate baseline for comparison
  final double? baselineHR;

  const HealthMetrics({
    this.heartRate,
    this.spo2,
    this.bodyTemperature,
    this.ambientTemperature,
    this.movementLevel,
    this.batteryLevel,
    required this.isWorn,
    required this.isConnected,
    required this.timestamp,
    this.baselineHR,
  });

  /// Create from Firebase real-time data
  factory HealthMetrics.fromFirebase(Map<String, dynamic> data,
      {double? baselineHR}) {
    // Helpers to parse dynamic types safely
    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        return parsed;
      }
      return null;
    }

    bool _toBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == 'true' || s == '1' || s == 'yes' || s == 'y';
      }
      return false;
    }

    DateTime _toDateTime(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is int) {
        // Heuristic: if it's seconds, convert to ms
        final ms = v > 1000000000000 ? v : v * 1000;
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      if (v is String) {
        final digitsOnly = RegExp(r'^\d{9,}$');
        if (digitsOnly.hasMatch(v)) {
          final asInt = int.tryParse(v);
          if (asInt != null) {
            final ms = asInt > 1000000000000 ? asInt : asInt * 1000;
            return DateTime.fromMillisecondsSinceEpoch(ms);
          }
        }
        final parsed = DateTime.tryParse(v);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    // Parse connection status from multiple possible keys
    bool connected = false;
    final connectedRaw = data['connected'] ?? data['isConnected'];
    if (connectedRaw != null) {
      connected = _toBool(connectedRaw);
    } else if (data['connectionStatus'] != null) {
      final s = data['connectionStatus'].toString().toLowerCase();
      connected = s.contains('connected') && !s.contains('disconnected');
    }

    // If no explicit connection info, infer from recency and vitals presence
    final ts = _toDateTime(data['timestamp']);
    final isFresh = DateTime.now().difference(ts).inSeconds <= 90;
    final hasVitals = (data['heartRate'] != null) || (data['spo2'] != null);
    if (!connected && isFresh && hasVitals) {
      connected = true;
    }

    return HealthMetrics(
      heartRate: _toDouble(data['heartRate']),
      spo2: _toDouble(data['spo2']),
      bodyTemperature: _toDouble(data['bodyTemp']),
      ambientTemperature: _toDouble(data['ambientTemp']),
      movementLevel: _toDouble(data['movementLevel']),
      batteryLevel: _toDouble(data['battPerc']),
      isWorn: _toBool(data['worn']),
      isConnected: connected,
      timestamp: ts,
      baselineHR: baselineHR,
    );
  }

  /// Create from DeviceReading model
  factory HealthMetrics.fromDeviceReading(DeviceReading reading,
      {double? baselineHR}) {
    // Calculate movement level from accelerometer data
    final movementLevel = _calculateMovementLevel(
      reading.accelX,
      reading.accelY,
      reading.accelZ,
    );

    return HealthMetrics(
      heartRate: reading.heartRate,
      spo2: reading.spo2,
      bodyTemperature: reading.bodyTemp,
      ambientTemperature: reading.ambientTemp,
      movementLevel: movementLevel,
      batteryLevel: reading.battPercSmoothed,
      isWorn: reading.worn,
      isConnected: true, // Assume connected if we have reading
      timestamp: reading.timestamp,
      baselineHR: baselineHR,
    );
  }

  /// Convert to Firebase format for real-time streaming
  Map<String, dynamic> toFirebase() => {
        if (heartRate != null) 'heartRate': heartRate!.round(),
        if (spo2 != null) 'spo2': spo2!.round(),
        if (bodyTemperature != null)
          'bodyTemp': double.parse(bodyTemperature!.toStringAsFixed(1)),
        if (ambientTemperature != null)
          'ambientTemp': double.parse(ambientTemperature!.toStringAsFixed(1)),
        if (movementLevel != null) 'movementLevel': movementLevel!.round(),
        if (batteryLevel != null) 'battPerc': batteryLevel!.round(),
        'worn': isWorn,
        'connected': isConnected,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  /// Calculate movement level from accelerometer data (0-100 scale)
  static double _calculateMovementLevel(
      double accelX, double accelY, double accelZ) {
    // Calculate magnitude of acceleration vector
    final magnitude =
        (accelX * accelX + accelY * accelY + accelZ * accelZ).abs();

    // Normalize to 0-100 scale (assuming typical range is 0-20 m/s²)
    final normalized = (magnitude / 20.0) * 100;

    // Clamp to 0-100 range
    return normalized.clamp(0.0, 100.0);
  }

  /// Get heart rate status relative to baseline
  HeartRateStatus get heartRateStatus {
    if (heartRate == null || baselineHR == null || !isWorn) {
      return HeartRateStatus.unknown;
    }

    final difference = heartRate! - baselineHR!;

    if (difference >= 30) return HeartRateStatus.veryHigh;
    if (difference >= 20) return HeartRateStatus.high;
    if (difference >= 10) return HeartRateStatus.elevated;
    if (difference >= -10) return HeartRateStatus.normal;
    if (difference >= -20) return HeartRateStatus.low;
    return HeartRateStatus.veryLow;
  }

  /// Get SpO2 status
  SpO2Status get spo2Status {
    if (spo2 == null || !isWorn) return SpO2Status.unknown;

    if (spo2! >= 98) return SpO2Status.excellent;
    if (spo2! >= 95) return SpO2Status.good;
    if (spo2! >= 90) return SpO2Status.low; // reverted back to 90
    return SpO2Status.critical;
  }

  /// Get temperature status
  TemperatureStatus get temperatureStatus {
    if (bodyTemperature == null || !isWorn) return TemperatureStatus.unknown;

    if (bodyTemperature! >= 38.0) return TemperatureStatus.fever;
    if (bodyTemperature! >= 37.5) return TemperatureStatus.elevated;
    if (bodyTemperature! >= 36.0) return TemperatureStatus.normal;
    return TemperatureStatus.low;
  }

  /// Get activity status based on movement level
  ActivityStatus get activityStatus {
    if (movementLevel == null || !isWorn) return ActivityStatus.unknown;

    if (movementLevel! >= 70) return ActivityStatus.active;
    if (movementLevel! >= 30) return ActivityStatus.moderate;
    if (movementLevel! >= 10) return ActivityStatus.light;
    return ActivityStatus.resting;
  }

  /// Check if any metrics indicate a potential health alert
  bool get hasHealthAlert {
    return heartRateStatus == HeartRateStatus.veryHigh ||
        heartRateStatus == HeartRateStatus.veryLow ||
        spo2Status == SpO2Status.critical ||
        spo2Status == SpO2Status.low ||
        temperatureStatus == TemperatureStatus.fever;
  }

  /// Get overall health status summary
  HealthStatus get overallStatus {
    if (!isWorn || !isConnected) return HealthStatus.unknown;

    if (hasHealthAlert) return HealthStatus.alert;

    if (heartRateStatus == HeartRateStatus.elevated ||
        spo2Status == SpO2Status.good ||
        temperatureStatus == TemperatureStatus.elevated) {
      return HealthStatus.caution;
    }

    if (heartRateStatus == HeartRateStatus.normal &&
        spo2Status == SpO2Status.excellent &&
        temperatureStatus == TemperatureStatus.normal) {
      return HealthStatus.excellent;
    }

    return HealthStatus.good;
  }

  @override
  String toString() {
    return 'HealthMetrics(HR: $heartRate, SpO2: $spo2, Temp: $bodyTemperature°C, '
        'Worn: $isWorn, Connected: $isConnected)';
  }
}

/// Heart rate status relative to baseline
enum HeartRateStatus {
  unknown,
  veryLow, // -20 BPM or more below baseline
  low, // -10 to -20 BPM below baseline
  normal, // Within ±10 BPM of baseline
  elevated, // +10 to +20 BPM above baseline
  high, // +20 to +30 BPM above baseline
  veryHigh, // +30 BPM or more above baseline
}

/// Blood oxygen saturation status
enum SpO2Status {
  unknown,
  critical, // Below 90%
  low, // 90-94%
  good, // 95-97%
  excellent, // 98% or higher
}

/// Body temperature status
enum TemperatureStatus {
  unknown,
  low, // Below 36°C
  normal, // 36-37.4°C
  elevated, // 37.5-37.9°C
  fever, // 38°C or higher
}

/// Activity/movement status
enum ActivityStatus {
  unknown,
  resting, // 0-10% movement
  light, // 10-30% movement
  moderate, // 30-70% movement
  active, // 70%+ movement
}

/// Overall health status summary
enum HealthStatus {
  unknown,
  alert, // Requires immediate attention
  caution, // Monitor closely
  good, // Normal range
  excellent, // Optimal range
}
