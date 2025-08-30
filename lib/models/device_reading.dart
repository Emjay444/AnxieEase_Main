/// Data model for device readings from Bluetooth Classic SPP connection
///
/// Represents parsed sensor data from a wearable device including:
/// - Biometric data (heart rate, SpO2, body temperature)
/// - Environmental data (ambient temperature)
/// - Motion data (accelerometer, gyroscope, pitch/roll)
/// - Device status (battery, worn status)
class DeviceReading {
  /// Timestamp when reading was received
  final DateTime timestamp;

  /// Heart rate in BPM - null when device is not worn (worn == 0)
  final double? heartRate;

  /// Blood oxygen saturation percentage
  final double spo2;

  /// Body temperature in Celsius - null when device is not worn (worn == 0)
  final double? bodyTemp;

  /// Ambient temperature in Celsius
  final double ambientTemp;

  /// Device pitch angle in degrees
  final double pitch;

  /// Device roll angle in degrees
  final double roll;

  /// Accelerometer X-axis reading
  final double accelX;

  /// Accelerometer Y-axis reading
  final double accelY;

  /// Accelerometer Z-axis reading
  final double accelZ;

  /// Gyroscope X-axis reading
  final double gyroX;

  /// Gyroscope Y-axis reading
  final double gyroY;

  /// Gyroscope Z-axis reading
  final double gyroZ;

  /// Raw battery percentage from device
  final double battPercRaw;

  /// Smoothed battery percentage using moving average for UI display
  final double battPercSmoothed;

  /// Whether the device is currently being worn
  final bool worn;

  const DeviceReading({
    required this.timestamp,
    required this.heartRate,
    required this.spo2,
    required this.bodyTemp,
    required this.ambientTemp,
    required this.pitch,
    required this.roll,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.battPercRaw,
    required this.battPercSmoothed,
    required this.worn,
  });

  /// Convert to Firestore document format
  ///
  /// Stores both raw and smoothed battery values for analytics
  /// Heart rate and body temp are stored as received (including null when not worn)
  Map<String, dynamic> toFirestore() => {
        'timestamp': timestamp.toIso8601String(),
        'heartRate': heartRate,
        'spo2': spo2,
        'bodyTemp': bodyTemp,
        'ambientTemp': ambientTemp,
        'pitch': pitch,
        'roll': roll,
        'accelX': accelX,
        'accelY': accelY,
        'accelZ': accelZ,
        'gyroX': gyroX,
        'gyroY': gyroY,
        'gyroZ': gyroZ,
        'battPercRaw': battPercRaw,
        'battPercSmoothed': battPercSmoothed,
        'worn': worn,
      };

  /// Create from Firestore document
  factory DeviceReading.fromFirestore(Map<String, dynamic> data) {
    return DeviceReading(
      timestamp: DateTime.parse(data['timestamp'] as String),
      heartRate: data['heartRate']?.toDouble(),
      spo2: (data['spo2'] as num).toDouble(),
      bodyTemp: data['bodyTemp']?.toDouble(),
      ambientTemp: (data['ambientTemp'] as num).toDouble(),
      pitch: (data['pitch'] as num).toDouble(),
      roll: (data['roll'] as num).toDouble(),
      accelX: (data['accelX'] as num).toDouble(),
      accelY: (data['accelY'] as num).toDouble(),
      accelZ: (data['accelZ'] as num).toDouble(),
      gyroX: (data['gyroX'] as num).toDouble(),
      gyroY: (data['gyroY'] as num).toDouble(),
      gyroZ: (data['gyroZ'] as num).toDouble(),
      battPercRaw: (data['battPercRaw'] as num).toDouble(),
      battPercSmoothed: (data['battPercSmoothed'] as num).toDouble(),
      worn: data['worn'] as bool,
    );
  }

  /// Create a copy with updated values
  DeviceReading copyWith({
    DateTime? timestamp,
    double? heartRate,
    double? spo2,
    double? bodyTemp,
    double? ambientTemp,
    double? pitch,
    double? roll,
    double? accelX,
    double? accelY,
    double? accelZ,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? battPercRaw,
    double? battPercSmoothed,
    bool? worn,
  }) {
    return DeviceReading(
      timestamp: timestamp ?? this.timestamp,
      heartRate: heartRate ?? this.heartRate,
      spo2: spo2 ?? this.spo2,
      bodyTemp: bodyTemp ?? this.bodyTemp,
      ambientTemp: ambientTemp ?? this.ambientTemp,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      battPercRaw: battPercRaw ?? this.battPercRaw,
      battPercSmoothed: battPercSmoothed ?? this.battPercSmoothed,
      worn: worn ?? this.worn,
    );
  }

  @override
  String toString() {
    return 'DeviceReading(timestamp: $timestamp, heartRate: $heartRate, '
        'spo2: $spo2, bodyTemp: $bodyTemp, worn: $worn, '
        'battPercSmoothed: ${battPercSmoothed.toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceReading &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          heartRate == other.heartRate &&
          spo2 == other.spo2 &&
          bodyTemp == other.bodyTemp &&
          ambientTemp == other.ambientTemp &&
          pitch == other.pitch &&
          roll == other.roll &&
          accelX == other.accelX &&
          accelY == other.accelY &&
          accelZ == other.accelZ &&
          gyroX == other.gyroX &&
          gyroY == other.gyroY &&
          gyroZ == other.gyroZ &&
          battPercRaw == other.battPercRaw &&
          battPercSmoothed == other.battPercSmoothed &&
          worn == other.worn;

  @override
  int get hashCode => Object.hash(
        timestamp,
        heartRate,
        spo2,
        bodyTemp,
        ambientTemp,
        pitch,
        roll,
        accelX,
        accelY,
        accelZ,
        gyroX,
        gyroY,
        gyroZ,
        battPercRaw,
        battPercSmoothed,
        worn,
      );
}

