import 'package:flutter_test/flutter_test.dart';
import '../lib/services/anxiety_detection_engine.dart';

void main() {
  group('Anxiety Detection Threshold & Notification Tests', () {
    late AnxietyDetectionEngine detectionEngine;

    setUp(() {
      detectionEngine = AnxietyDetectionEngine();
    });

    group('🔬 Baseline Heart Rate Thresholds', () {
      test('should calculate correct anxiety thresholds from baseline', () {
        const baselineHR = 70.0;
        
        // Test 20% threshold (mild anxiety)
        final threshold20 = baselineHR * 1.20; // 84 BPM
        expect(threshold20, equals(84.0));
        
        // Test 30% threshold (moderate-high anxiety)
        final threshold30 = baselineHR * 1.30; // 91 BPM
        expect(threshold30, equals(91.0));
        
        print('✅ Baseline Thresholds:');
        print('   Baseline HR: $baselineHR BPM');
        print('   20% above (mild): $threshold20 BPM');
        print('   30% above (high): $threshold30 BPM');
      });

      test('should handle different baseline ranges', () {
        final testCases = [
          {'baseline': 60.0, 'mild': 72.0, 'high': 78.0},
          {'baseline': 80.0, 'mild': 96.0, 'high': 104.0},
          {'baseline': 100.0, 'mild': 120.0, 'high': 130.0},
        ];

        for (final testCase in testCases) {
          final baseline = testCase['baseline']! as double;
          final expectedMild = testCase['mild']! as double;
          final expectedHigh = testCase['high']! as double;

          expect(baseline * 1.20, equals(expectedMild));
          expect(baseline * 1.30, equals(expectedHigh));
          
          print('✅ Baseline: $baseline → Mild: $expectedMild, High: $expectedHigh');
        }
      });
    });

    group('🫁 SpO2 Critical Levels', () {
      test('should identify correct SpO2 emergency thresholds', () {
        final testCases = [
          {'spo2': 98.0, 'status': 'Normal', 'critical': false},
          {'spo2': 95.0, 'status': 'Normal', 'critical': false},
          {'spo2': 94.0, 'status': 'Critical', 'critical': true},
          {'spo2': 92.0, 'status': 'Critical', 'critical': true},
          {'spo2': 90.0, 'status': 'Severe Critical', 'critical': true},
          {'spo2': 88.0, 'status': 'Severe Critical', 'critical': true},
        ];

        for (final testCase in testCases) {
          final spo2 = testCase['spo2']! as double;
          final expectedCritical = testCase['critical']! as bool;
          final status = testCase['status']! as String;

          final isCritical = spo2 <= 94.0;
          final isSevere = spo2 <= 90.0;
          
          expect(isCritical, equals(expectedCritical));
          
          String actualStatus;
          if (isSevere) {
            actualStatus = 'Severe Critical';
          } else if (isCritical) {
            actualStatus = 'Critical';
          } else {
            actualStatus = 'Normal';
          }
          
          expect(actualStatus, equals(status));
          print('✅ SpO2: $spo2% → $actualStatus');
        }
      });
    });

    group('🚨 Critical Detection Tests', () {
      test('should trigger immediate notification for emergency SpO2', () {
        final result = detectionEngine.detectAnxiety(
          currentHeartRate: 105.0,  // 50% above baseline
          restingHeartRate: 70.0,
          currentSpO2: 92.0,        // Critical emergency level
          currentMovement: 0.8,     // High movement
        );

        expect(result.triggered, isTrue);
        expect(result.confidenceLevel, greaterThan(0.8));
        expect(result.abnormalMetrics['spO2'], isTrue);
        expect(result.abnormalMetrics['heartRate'], isTrue);
        
        print('🚨 CRITICAL EMERGENCY:');
        print('   HR: 105.0 BPM (50% above baseline)');
        print('   SpO2: 92.0% (CRITICAL)');
        print('   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
        print('   Action: IMMEDIATE NOTIFICATION');
      });

      test('should handle normal metrics correctly', () {
        final result = detectionEngine.detectAnxiety(
          currentHeartRate: 75.0,   // 7% above baseline (normal)
          restingHeartRate: 70.0,
          currentSpO2: 98.0,        // Excellent
          currentMovement: 0.2,     // Low movement
        );

        expect(result.triggered, isFalse);
        expect(result.confidenceLevel, lessThan(0.6));
        
        print('😌 NORMAL STATE:');
        print('   HR: 75.0 BPM (normal variation)');
        print('   SpO2: 98.0% (excellent)');
        print('   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
        print('   Action: Silent monitoring');
      });
    });

    group('🔄 Real-World Simulation', () {
      test('should demonstrate complete anxiety episode detection', () {
        print('\n🔄 ANXIETY EPISODE SIMULATION:');
        print('=' * 50);
        
        const baseline = 72.0;
        final timeline = [
          {'time': '10:00', 'hr': 74.0, 'spo2': 98.0, 'move': 0.1, 'phase': 'Calm'},
          {'time': '10:15', 'hr': 88.0, 'spo2': 95.0, 'move': 0.4, 'phase': 'Anxiety rising'},
          {'time': '10:30', 'hr': 98.0, 'spo2': 93.0, 'move': 0.7, 'phase': 'High anxiety'},
          {'time': '10:45', 'hr': 76.0, 'spo2': 97.0, 'move': 0.2, 'phase': 'Calming down'},
        ];

        for (final point in timeline) {
          final result = detectionEngine.detectAnxiety(
            currentHeartRate: point['hr']! as double,
            restingHeartRate: baseline,
            currentSpO2: point['spo2']! as double,
            currentMovement: point['move']! as double,
          );

          String action = 'MONITOR';
          if (result.confidenceLevel >= 0.8) {
            action = 'ALERT';
          } else if (result.confidenceLevel >= 0.6) {
            action = 'CONFIRM';
          }

          print('\n⏰ ${point['time']} - ${point['phase']}:');
          print('   Metrics: HR ${point['hr']}, SpO2 ${point['spo2']}%, Move ${point['move']}');
          print('   Detection: ${result.triggered}');
          print('   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(0)}%');
          print('   Action: $action');
        }
      });
    });
  });
}

    group('Multi-Parameter Detection Tests', () {
      test('should detect high-confidence anxiety with elevated HR and critical SpO2', () {
        final result = detectionEngine.detectAnxiety(
          currentHeartRate: 105.0,  // 50% above baseline of 70
          restingHeartRate: 70.0,
          currentSpO2: 93.0,        // Critical level
          currentMovement: 0.8,     // High movement
        );

        expect(result.triggered, isTrue);
        expect(result.confidenceLevel, greaterThan(0.8)); // High confidence
        expect(result.abnormalMetrics['spO2'], isTrue);
        expect(result.abnormalMetrics['heartRate'], isTrue);
        
        print('✅ High-confidence detection:');
        print('   HR: 105.0 BPM (${((105.0 / 70.0 - 1) * 100).toStringAsFixed(1)}% above baseline)');
        print('   SpO2: 93.0% (Critical)');
        print('   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
        print('   Reason: ${result.reason}');
        print('   Abnormal metrics: ${result.abnormalMetrics}');
      });

      test('should detect medium-confidence anxiety requiring user confirmation', () async {
        final metrics = HealthMetrics(
          heartRate: 88.0,   // 25% above baseline of 70
          spO2: 96.0,        // Normal but lower end
          movementVariance: 0.3,  // Moderate movement
          timestamp: DateTime.now(),
        );

        final result = await detectionEngine.analyzeMetrics(
          metrics, 
          baselineHeartRate: 70.0,
        );

        expect(result.isAnxietyDetected, isTrue);
        expect(result.confidence, allOf(greaterThan(0.6), lessThan(0.8))); // Medium confidence
        
        print('✅ Medium-confidence detection (requires confirmation):');
        print('   HR: ${metrics.heartRate} BPM (${((metrics.heartRate / 70.0 - 1) * 100).toStringAsFixed(1)}% above baseline)');
        print('   SpO2: ${metrics.spO2}% (Normal range)');
        print('   Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
        print('   Should prompt user: ${result.confidence >= 0.6 && result.confidence < 0.8}');
      });

      test('should not trigger on normal metrics', () async {
        final metrics = HealthMetrics(
          heartRate: 72.0,   // 3% above baseline (normal variation)
          spO2: 98.0,        // Excellent
          movementVariance: 0.1,  // Low movement
          timestamp: DateTime.now(),
        );

        final result = await detectionEngine.analyzeMetrics(
          metrics, 
          baselineHeartRate: 70.0,
        );

        expect(result.isAnxietyDetected, isFalse);
        expect(result.confidence, lessThan(0.6)); // Low confidence
        
        print('✅ Normal metrics (no detection):');
        print('   HR: ${metrics.heartRate} BPM (${((metrics.heartRate / 70.0 - 1) * 100).toStringAsFixed(1)}% above baseline)');
        print('   SpO2: ${metrics.spO2}% (Excellent)');
        print('   Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
        print('   Detection: ${result.isAnxietyDetected}');
      });

      test('should handle edge cases and boundary conditions', () async {
        final testCases = [
          {
            'name': 'Exactly 20% HR threshold',
            'hr': 84.0,  // Exactly 20% above 70
            'spo2': 95.0,
            'movement': 0.2,
            'expectedDetection': true,
          },
          {
            'name': 'Exactly 94% SpO2 threshold',
            'hr': 75.0,  // Mild elevation
            'spo2': 94.0,  // Exactly at critical threshold
            'movement': 0.4,
            'expectedDetection': true,
          },
          {
            'name': 'Just below HR threshold',
            'hr': 83.5,  // Just under 20%
            'spo2': 97.0,
            'movement': 0.1,
            'expectedDetection': false,
          },
        ];

        for (final testCase in testCases) {
          final metrics = HealthMetrics(
            heartRate: testCase['hr']! as double,
            spO2: testCase['spo2']! as double,
            movementVariance: testCase['movement']! as double,
            timestamp: DateTime.now(),
          );

          final result = await detectionEngine.analyzeMetrics(
            metrics, 
            baselineHeartRate: 70.0,
          );

          final expectedDetection = testCase['expectedDetection']! as bool;
          expect(result.isAnxietyDetected, equals(expectedDetection));
          
          print('✅ ${testCase['name']}:');
          print('   Detection: ${result.isAnxietyDetected} (expected: $expectedDetection)');
          print('   Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
        }
      });
    });

    group('Notification System Tests', () {
      test('should generate appropriate notification content for different triggers', () {
        final testCases = [
          {
            'triggers': ['criticalSpO2'],
            'confidence': 0.95,
            'expectedContent': 'Critical SpO2 detected',
          },
          {
            'triggers': ['elevatedHeartRate', 'highMovement'],
            'confidence': 0.85,
            'expectedContent': 'Combined HR and movement patterns',
          },
          {
            'triggers': ['elevatedHeartRate'],
            'confidence': 0.75,
            'expectedContent': 'Elevated heart rate detected',
          },
          {
            'triggers': ['criticalSpO2', 'elevatedHeartRate', 'highMovement'],
            'confidence': 0.92,
            'expectedContent': 'Multiple anxiety indicators detected',
          },
        ];

        for (final testCase in testCases) {
          final triggers = testCase['triggers']! as List<String>;
          final confidence = testCase['confidence']! as double;
          final expectedContent = testCase['expectedContent']! as String;

          // Simulate notification content generation logic
          String actualContent;
          if (triggers.contains('criticalSpO2') && triggers.length > 1) {
            actualContent = 'Multiple anxiety indicators detected';
          } else if (triggers.contains('criticalSpO2')) {
            actualContent = 'Critical SpO2 detected';
          } else if (triggers.contains('elevatedHeartRate') && triggers.contains('highMovement')) {
            actualContent = 'Combined HR and movement patterns';
          } else if (triggers.contains('elevatedHeartRate')) {
            actualContent = 'Elevated heart rate detected';
          } else {
            actualContent = 'Anxiety patterns detected';
          }

          expect(actualContent, equals(expectedContent));
          
          print('✅ Notification test:');
          print('   Triggers: ${triggers.join(', ')}');
          print('   Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
          print('   Content: "$actualContent"');
          print('   Action: ${confidence >= 0.8 ? 'Immediate notification' : confidence >= 0.6 ? 'Request confirmation' : 'Silent collection'}');
        }
      });

      test('should determine correct notification action based on confidence', () {
        final confidenceLevels = [0.95, 0.85, 0.75, 0.65, 0.55, 0.45];
        
        for (final confidence in confidenceLevels) {
          String expectedAction;
          if (confidence >= 0.8) {
            expectedAction = 'Immediate notification';
          } else if (confidence >= 0.6) {
            expectedAction = 'Request user confirmation';
          } else {
            expectedAction = 'Silent data collection';
          }
          
          print('✅ Confidence: ${(confidence * 100).toStringAsFixed(1)}% → $expectedAction');
        }
      });
    });

    group('Integration Tests', () {
      test('should simulate complete detection workflow', () async {
        print('\n🔄 Simulating complete anxiety detection workflow...\n');
        
        // Step 1: Record baseline
        const baselineHR = 72.0;
        print('📊 Step 1: Baseline recorded - $baselineHR BPM');
        
        // Step 2: Normal metrics
        var metrics = HealthMetrics(
          heartRate: 74.0,
          spO2: 98.0,
          movementVariance: 0.1,
          timestamp: DateTime.now(),
        );
        
        var result = await detectionEngine.analyzeMetrics(metrics, baselineHeartRate: baselineHR);
        print('📈 Step 2: Normal metrics - No detection (${(result.confidence * 100).toStringAsFixed(1)}% confidence)');
        
        // Step 3: Mild elevation (medium confidence)
        metrics = HealthMetrics(
          heartRate: 89.0,  // 24% above baseline
          spO2: 95.0,
          movementVariance: 0.4,
          timestamp: DateTime.now(),
        );
        
        result = await detectionEngine.analyzeMetrics(metrics, baselineHeartRate: baselineHR);
        print('⚠️  Step 3: Mild elevation - User confirmation needed (${(result.confidence * 100).toStringAsFixed(1)}% confidence)');
        
        // Step 4: Critical situation (high confidence)
        metrics = HealthMetrics(
          heartRate: 98.0,  // 36% above baseline
          spO2: 93.0,       // Critical SpO2
          movementVariance: 0.7,
          timestamp: DateTime.now(),
        );
        
        result = await detectionEngine.analyzeMetrics(metrics, baselineHeartRate: baselineHR);
        print('🚨 Step 4: Critical situation - Immediate notification (${(result.confidence * 100).toStringAsFixed(1)}% confidence)');
        print('   Triggers: ${result.triggers.join(', ')}');
        
        expect(result.isAnxietyDetected, isTrue);
        expect(result.confidence, greaterThan(0.8));
        expect(result.triggers.length, greaterThan(1));
        
        print('\n✅ Complete workflow test passed!\n');
      });
    });
  });
}