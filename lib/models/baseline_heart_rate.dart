import 'dart:math' as math;

/// Model for storing baseline heart rate data and resting HR recordings
class BaselineHeartRate {
  /// User ID who owns this baseline
  final String userId;

  /// Device ID used for recording
  final String deviceId;

  /// Calculated resting heart rate (average of recording session)
  final double baselineHR;

  /// Individual HR readings during the recording session
  final List<double> recordedReadings;

  /// When the recording session started
  final DateTime recordingStartTime;

  /// When the recording session ended
  final DateTime recordingEndTime;

  /// Duration of recording session in minutes
  final double recordingDurationMinutes;

  /// When this baseline was created/updated
  final DateTime createdAt;

  /// Whether this is the active baseline for the user
  final bool isActive;

  /// Notes about the recording conditions
  final String? notes;

  const BaselineHeartRate({
    required this.userId,
    required this.deviceId,
    required this.baselineHR,
    required this.recordedReadings,
    required this.recordingStartTime,
    required this.recordingEndTime,
    required this.recordingDurationMinutes,
    required this.createdAt,
    this.isActive = true,
    this.notes,
  });

  /// Create from Supabase database record
  factory BaselineHeartRate.fromSupabase(Map<String, dynamic> data) {
    return BaselineHeartRate(
      userId: data['user_id'] as String,
      deviceId: data['device_id'] as String,
      baselineHR: (data['baseline_hr'] as num).toDouble(),
      recordedReadings: List<double>.from((data['recorded_readings'] as List)
          .map((x) => (x as num).toDouble())),
      recordingStartTime:
          DateTime.parse(data['recording_start_time'] as String),
      recordingEndTime: DateTime.parse(data['recording_end_time'] as String),
      recordingDurationMinutes:
          (data['recording_duration_minutes'] as num).toDouble(),
      createdAt: DateTime.parse(data['created_at'] as String),
      isActive: data['is_active'] as bool? ?? true,
      notes: data['notes'] as String?,
    );
  }

  /// Convert to Supabase format for insert/update
  Map<String, dynamic> toSupabase() => {
        'user_id': userId,
        'device_id': deviceId,
        'baseline_hr': baselineHR,
        'recorded_readings': recordedReadings,
        'recording_start_time': recordingStartTime.toIso8601String(),
        'recording_end_time': recordingEndTime.toIso8601String(),
        'recording_duration_minutes': recordingDurationMinutes,
        'created_at': createdAt.toIso8601String(),
        'is_active': isActive,
        if (notes != null) 'notes': notes,
      };

  /// Calculate baseline from a list of HR readings
  static BaselineHeartRate calculateBaseline({
    required String userId,
    required String deviceId,
    required List<double> readings,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
  }) {
    if (readings.isEmpty) {
      throw ArgumentError('Cannot calculate baseline from empty readings');
    }

    // Remove outliers (readings beyond 2 standard deviations)
    final cleanedReadings = _removeOutliers(readings);

    // Calculate average as baseline
    final baseline =
        cleanedReadings.reduce((a, b) => a + b) / cleanedReadings.length;

    // Calculate duration
    final duration = endTime.difference(startTime).inMilliseconds / (1000 * 60);

    return BaselineHeartRate(
      userId: userId,
      deviceId: deviceId,
      baselineHR: double.parse(baseline.toStringAsFixed(1)),
      // Store a copy to prevent later mutations (e.g., cleanup) from
      // affecting this baseline's quality assessment.
      recordedReadings: List<double>.from(readings),
      recordingStartTime: startTime,
      recordingEndTime: endTime,
      recordingDurationMinutes: double.parse(duration.toStringAsFixed(1)),
      createdAt: DateTime.now(),
      notes: notes,
    );
  }

  /// Remove outlier readings using statistical method
  static List<double> _removeOutliers(List<double> readings) {
    if (readings.length < 3) return readings;

    final mean = readings.reduce((a, b) => a + b) / readings.length;
    final variance =
        readings.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            readings.length;
    final stdDev = math.sqrt(variance.abs());

    // Keep readings within 2 standard deviations
    return readings
        .where((reading) => (reading - mean).abs() <= 2 * stdDev)
        .toList();
  }

  /// Get recording quality assessment
  RecordingQuality get recordingQuality {
    print('BaselineHeartRate: Assessing recording quality');
    print(
        '  - Duration: ${recordingDurationMinutes.toStringAsFixed(1)} minutes');
    print('  - Number of readings: ${recordedReadings.length}');

    if (recordingDurationMinutes < 2) {
      print('  - Quality result: tooShort (duration < 2 minutes)');
      return RecordingQuality.tooShort;
    }
    if (recordedReadings.length < 5) {
      print('  - Quality result: insufficientData (< 5 readings)');
      return RecordingQuality.insufficientData;
    }

    // Calculate coefficient of variation (CV = std dev / mean)
    final mean =
        recordedReadings.reduce((a, b) => a + b) / recordedReadings.length;
    final variance = recordedReadings
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b) /
        recordedReadings.length;
    final stdDev = math.sqrt(variance.abs());
    final cv = stdDev / mean;

    print('  - Mean HR: ${mean.toStringAsFixed(1)} BPM');
    print('  - Standard deviation: ${stdDev.toStringAsFixed(2)} BPM');
    print('  - Coefficient of variation: ${(cv * 100).toStringAsFixed(1)}%');

    if (cv > 0.20) {
      print('  - Quality result: unstable (CV > 20%)');
      return RecordingQuality.unstable; // >20% variation
    }
    if (cv > 0.15) {
      print('  - Quality result: fair (CV 15-20%)');
      return RecordingQuality.fair; // 15-20% variation
    }
    if (cv > 0.10) {
      print('  - Quality result: good (CV 10-15%)');
      return RecordingQuality.good; // 10-15% variation
    }
    print('  - Quality result: excellent (CV < 10%)');
    return RecordingQuality.excellent; // <10% variation
  }

  @override
  String toString() {
    return 'BaselineHeartRate(userId: $userId, baseline: ${baselineHR.toStringAsFixed(1)} BPM, '
        'quality: $recordingQuality, duration: ${recordingDurationMinutes.toStringAsFixed(1)}min)';
  }
}

/// Assessment of baseline recording quality
enum RecordingQuality {
  tooShort, // Recording was too brief
  insufficientData, // Not enough data points
  unstable, // High variability in readings
  fair, // Acceptable quality
  good, // Good quality recording
  excellent, // Excellent stable recording
}
