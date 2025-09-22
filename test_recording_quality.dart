import 'lib/models/baseline_heart_rate.dart';

void main() {
  print('Testing Recording Quality Assessment\n');

  // Test case 1: Excellent quality (low variation)
  testRecordingQuality(
      'Excellent Quality',
      List.generate(60, (i) => 70.0 + (i % 2) * 2), // 70-72 BPM alternating
      3.0);

  // Test case 2: Good quality (moderate variation)
  testRecordingQuality(
      'Good Quality',
      List.generate(60, (i) => 75.0 + (i % 5) * 3), // 75-87 BPM with pattern
      3.0);

  // Test case 3: Fair quality (higher variation)
  testRecordingQuality(
      'Fair Quality',
      List.generate(60, (i) => 80.0 + (i % 7) * 8), // More variable
      3.0);

  // Test case 4: Unstable quality (high variation)
  testRecordingQuality(
      'Unstable Quality',
      [65, 85, 70, 95, 68, 88, 72, 92, 66, 86, 74, 90], // High variation
      3.0);

  // Test case 5: Insufficient data
  testRecordingQuality(
      'Insufficient Data',
      [70, 72, 71], // Only 3 readings
      3.0);

  // Test case 6: Too short duration
  testRecordingQuality(
      'Too Short Duration',
      List.generate(20, (i) => 70.0 + i), // Good data but short
      1.5 // 1.5 minutes
      );
}

void testRecordingQuality(
    String testName, List<double> readings, double durationMinutes) {
  print('=== $testName ===');

  try {
    final baseline = BaselineHeartRate.calculateBaseline(
      userId: 'test-user',
      deviceId: 'test-device',
      readings: readings,
      startTime:
          DateTime.now().subtract(Duration(minutes: durationMinutes.round())),
      endTime: DateTime.now(),
    );

    print('Baseline HR: ${baseline.baselineHR.toStringAsFixed(1)} BPM');
    print('Quality: ${baseline.recordingQuality}');
    print('Readings count: ${baseline.recordedReadings.length}');
    print(
        'Duration: ${baseline.recordingDurationMinutes.toStringAsFixed(1)} min');
  } catch (e) {
    print('Error: $e');
  }

  print('');
}
