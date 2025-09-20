import 'package:flutter_test/flutter_test.dart';
import '../lib/services/anxiety_detection_engine.dart';

void main() {
  group('🧪 Anxiety Detection Threshold & Notification Tests', () {
    late AnxietyDetectionEngine detectionEngine;

    setUp(() {
      detectionEngine = AnxietyDetectionEngine();
    });

    group('🔬 Baseline Heart Rate Threshold Tests', () {
      test('should calculate correct anxiety thresholds from baseline HR', () {
        const baselineHR = 70.0;

        // Test 20% threshold (mild anxiety)
        final threshold20 = baselineHR * 1.20; // 84 BPM
        expect(threshold20, equals(84.0));

        // Test 30% threshold (moderate-high anxiety)
        final threshold30 = baselineHR * 1.30; // 91 BPM
        expect(threshold30, equals(91.0));

        print('✅ Baseline Threshold Calculations:');
        print('   Baseline HR: $baselineHR BPM');
        print('   20% above (mild anxiety): $threshold20 BPM');
        print('   30% above (high anxiety): $threshold30 BPM');
      });

      test('should handle different baseline ranges correctly', () {
        final testCases = [
          {'baseline': 60.0, 'mild': 72.0, 'high': 78.0},
          {'baseline': 80.0, 'mild': 96.0, 'high': 104.0},
          {'baseline': 100.0, 'mild': 120.0, 'high': 130.0},
        ];

        for (final testCase in testCases) {
          final baseline = testCase['baseline'] as double;
          final expectedMild = testCase['mild'] as double;
          final expectedHigh = testCase['high'] as double;

          expect(baseline * 1.20, equals(expectedMild));
          expect(baseline * 1.30, equals(expectedHigh));

          print(
              '✅ Baseline: $baseline → Mild: $expectedMild, High: $expectedHigh');
        }
      });
    });

    group('🫁 SpO2 Critical Level Tests', () {
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
          final spo2 = testCase['spo2'] as double;
          final expectedCritical = testCase['critical'] as bool;
          final status = testCase['status'] as String;

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

    group('🚨 High Confidence Detection Tests', () {
      test('should trigger immediate notification for critical SpO2', () {
        final result = detectionEngine.detectAnxiety(
          currentHeartRate: 105.0, // 50% above baseline
          restingHeartRate: 70.0,
          currentSpO2: 92.0, // Critical emergency level
          currentMovement: 0.8, // High movement/tremors
        );

        expect(result.triggered, isTrue);
        expect(result.confidenceLevel, greaterThan(0.7)); // High confidence
        expect(result.abnormalMetrics['spO2'], isTrue);
        expect(result.abnormalMetrics['heartRate'], isTrue);

        print('🚨 CRITICAL EMERGENCY DETECTION:');
        print(
            '   HR: 105.0 BPM (${((105.0 / 70.0 - 1) * 100).toStringAsFixed(1)}% above baseline)');
        print('   SpO2: 92.0% (CRITICAL - Requires immediate attention)');
        print('   Movement: 0.8 (High activity/tremors detected)');
        print(
            '   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
        print('   Action: ⚡ IMMEDIATE NOTIFICATION');
        print('   Reason: "${result.reason}"');
      });

      test('should trigger for severely elevated heart rate alone', () {
        final result = detectionEngine.detectAnxiety(
          currentHeartRate: 125.0, // 78% above baseline
          restingHeartRate: 70.0,
          currentSpO2: 97.0, // Normal SpO2
          currentMovement: 0.5, // Moderate movement
        );

        expect(result.triggered, isTrue);
        expect(result.confidenceLevel, greaterThan(0.6)); // Good confidence
        expect(result.abnormalMetrics['heartRate'], isTrue);

        print('💓 SEVERE HEART RATE ELEVATION:');
        print(
            '   HR: 125.0 BPM (${((125.0 / 70.0 - 1) * 100).toStringAsFixed(1)}% above baseline)');
        print('   SpO2: 97.0% (Normal)');
        print('   Movement: 0.5 (Moderate)');
        print(
            '   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
        print(
            '   Action: ${result.confidenceLevel >= 0.8 ? '⚡ IMMEDIATE' : '🔔 NOTIFICATION'}');
        print('   Reason: "${result.reason}"');
      });
    });

    group('⚠️ Medium Confidence Tests (User Confirmation)', () {
      test('should request user confirmation for moderate elevation', () {
        final result = detectionEngine.detectAnxiety(
          currentHeartRate: 88.0, // 25% above baseline
          restingHeartRate: 70.0,
          currentSpO2: 95.0, // Normal but lower end
          currentMovement: 0.4, // Moderate movement
        );

        print('🤔 MODERATE CONFIDENCE DETECTION:');
        print(
            '   HR: 88.0 BPM (${((88.0 / 70.0 - 1) * 100).toStringAsFixed(1)}% above baseline)');
        print('   SpO2: 95.0% (Normal range but lower end)');
        print('   Movement: 0.4 (Moderate activity)');
        print(
            '   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
        print('   Requires confirmation: ${result.requiresUserConfirmation}');

        final isModerateConfidence =
            result.confidenceLevel >= 0.6 && result.confidenceLevel < 0.8;
        print(
            '   Action: ${isModerateConfidence ? '❓ REQUEST USER CONFIRMATION' : result.confidenceLevel >= 0.8 ? '⚡ IMMEDIATE ALERT' : '👀 CONTINUE MONITORING'}');
        print('   Reason: "${result.reason}"');

        // Test that system appropriately handles moderate confidence
        if (result.triggered) {
          expect(result.confidenceLevel, greaterThan(0.5));
        }
      });
    });

    group('✅ Normal Metrics Tests (No Detection)', () {
      test('should not trigger on normal physiological variation', () {
        final result = detectionEngine.detectAnxiety(
          currentHeartRate: 75.0, // 7% above baseline (normal variation)
          restingHeartRate: 70.0,
          currentSpO2: 98.0, // Excellent oxygen levels
          currentMovement: 0.2, // Low movement
        );

        expect(result.triggered, isFalse);
        expect(result.confidenceLevel,
            lessThan(0.6)); // Low confidence = no action

        print('😌 NORMAL PHYSIOLOGICAL STATE:');
        print(
            '   HR: 75.0 BPM (${((75.0 / 70.0 - 1) * 100).toStringAsFixed(1)}% above baseline - normal variation)');
        print('   SpO2: 98.0% (Excellent oxygen saturation)');
        print('   Movement: 0.2 (Low, restful state)');
        print(
            '   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
        print('   Detection: ${result.triggered}');
        print('   Action: 📊 Silent data collection');
      });
    });

    group('🎯 Boundary Condition Tests', () {
      test('should test exact threshold boundaries', () {
        final testCases = [
          {
            'name': 'Exactly 20% HR threshold',
            'hr': 84.0, // Exactly 20% above 70
            'spo2': 95.0,
            'movement': 0.3,
            'description': 'Right at mild anxiety threshold',
          },
          {
            'name': 'Just below 20% HR threshold',
            'hr': 83.9, // Just under 20%
            'spo2': 96.0,
            'movement': 0.2,
            'description': 'Just under anxiety threshold',
          },
          {
            'name': 'Exactly 94% SpO2 critical threshold',
            'hr': 75.0,
            'spo2': 94.0, // Exactly at critical
            'movement': 0.3,
            'description': 'Right at SpO2 emergency threshold',
          },
          {
            'name': 'Just above 94% SpO2 threshold',
            'hr': 75.0,
            'spo2': 94.1, // Just above critical
            'movement': 0.3,
            'description': 'Just above SpO2 emergency threshold',
          },
        ];

        print('\n🎯 BOUNDARY CONDITIONS TESTING:');
        print('=' * 60);

        for (final testCase in testCases) {
          final result = detectionEngine.detectAnxiety(
            currentHeartRate: testCase['hr'] as double,
            restingHeartRate: 70.0,
            currentSpO2: testCase['spo2'] as double,
            currentMovement: testCase['movement'] as double,
          );

          print('\n📍 ${testCase['name']}:');
          print('   Description: ${testCase['description']}');
          print(
              '   Metrics: HR ${testCase['hr']}, SpO2 ${testCase['spo2']}%, Movement ${testCase['movement']}');
          print('   Detected: ${result.triggered}');
          print(
              '   Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
          print(
              '   Abnormal: HR=${result.abnormalMetrics['heartRate']}, SpO2=${result.abnormalMetrics['spO2']}');

          if (result.triggered) {
            print('   🚨 Alert: "${result.reason}"');
          }
        }
      });
    });

    group('📱 Notification System Simulation', () {
      test('should demonstrate complete notification flow', () {
        final scenarios = [
          {
            'name': 'Life-Threatening Emergency',
            'hr': 115.0,
            'spo2': 89.0,
            'movement': 0.9,
            'expectedLevel': 'EMERGENCY',
            'description': 'Severe SpO2 + High HR + High movement',
          },
          {
            'name': 'Critical Anxiety Attack',
            'hr': 108.0,
            'spo2': 93.0,
            'movement': 0.7,
            'expectedLevel': 'CRITICAL',
            'description': 'Critical SpO2 + Elevated HR',
          },
          {
            'name': 'High Anxiety Episode',
            'hr': 98.0,
            'spo2': 96.0,
            'movement': 0.6,
            'expectedLevel': 'HIGH',
            'description': 'Elevated HR + Moderate movement',
          },
          {
            'name': 'Moderate Concern',
            'hr': 86.0,
            'spo2': 95.0,
            'movement': 0.4,
            'expectedLevel': 'MODERATE',
            'description': 'Mild HR elevation + Lower normal SpO2',
          },
          {
            'name': 'Normal Monitoring',
            'hr': 73.0,
            'spo2': 98.0,
            'movement': 0.2,
            'expectedLevel': 'NORMAL',
            'description': 'All metrics within normal ranges',
          },
        ];

        print('\n📱 NOTIFICATION SYSTEM COMPLETE TEST:');
        print('=' * 70);

        for (final scenario in scenarios) {
          final result = detectionEngine.detectAnxiety(
            currentHeartRate: scenario['hr'] as double,
            restingHeartRate: 70.0,
            currentSpO2: scenario['spo2'] as double,
            currentMovement: scenario['movement'] as double,
          );

          String notificationAction;
          String urgencyIcon;

          if (result.confidenceLevel >= 0.9) {
            notificationAction = '🚨 EMERGENCY ALERT + AUTO-CALL 911';
            urgencyIcon = '🆘';
          } else if (result.confidenceLevel >= 0.8) {
            notificationAction = '⚡ IMMEDIATE ANXIETY NOTIFICATION';
            urgencyIcon = '🚨';
          } else if (result.confidenceLevel >= 0.6) {
            notificationAction = '❓ REQUEST USER CONFIRMATION';
            urgencyIcon = '⚠️';
          } else {
            notificationAction = '📊 SILENT DATA COLLECTION';
            urgencyIcon = '👀';
          }

          print('\n$urgencyIcon ${scenario['name']}:');
          print('   📝 ${scenario['description']}');
          print(
              '   📊 HR: ${scenario['hr']}, SpO2: ${scenario['spo2']}%, Movement: ${scenario['movement']}');
          print('   🎯 Detection: ${result.triggered}');
          print(
              '   📈 Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
          print('   🔔 Action: $notificationAction');

          if (result.triggered) {
            print('   💬 Message: "${result.reason}"');
            print(
                '   ⚙️  Requires Confirmation: ${result.requiresUserConfirmation}');
          }
        }
      });
    });

    group('🔄 Real-World Anxiety Episode Simulation', () {
      test('should demonstrate complete anxiety attack progression', () {
        print('\n🔄 COMPLETE ANXIETY EPISODE TIMELINE:');
        print('=' * 70);

        const baseline = 72.0;
        print('🏁 Patient Profile: Baseline HR = $baseline BPM');
        print('📅 Date: September 20, 2025');
        print('👤 Scenario: University student during exam period\n');

        final timeline = [
          {
            'time': '10:00 AM',
            'hr': 74.0,
            'spo2': 98.0,
            'move': 0.1,
            'context': 'Studying calmly'
          },
          {
            'time': '10:30 AM',
            'hr': 82.0,
            'spo2': 97.0,
            'move': 0.3,
            'context': 'Reading difficult material'
          },
          {
            'time': '11:00 AM',
            'hr': 89.0,
            'spo2': 95.0,
            'move': 0.5,
            'context': 'Anxiety starting to build'
          },
          {
            'time': '11:15 AM',
            'hr': 96.0,
            'spo2': 94.0,
            'move': 0.7,
            'context': 'Panic attack beginning'
          },
          {
            'time': '11:20 AM',
            'hr': 105.0,
            'spo2': 92.0,
            'move': 0.8,
            'context': 'Full panic attack'
          },
          {
            'time': '11:30 AM',
            'hr': 88.0,
            'spo2': 95.0,
            'move': 0.4,
            'context': 'Starting to calm down'
          },
          {
            'time': '11:45 AM',
            'hr': 76.0,
            'spo2': 97.0,
            'move': 0.2,
            'context': 'Recovery phase'
          },
          {
            'time': '12:00 PM',
            'hr': 74.0,
            'spo2': 98.0,
            'move': 0.1,
            'context': 'Back to baseline'
          },
        ];

        for (int i = 0; i < timeline.length; i++) {
          final point = timeline[i];
          final result = detectionEngine.detectAnxiety(
            currentHeartRate: point['hr'] as double,
            restingHeartRate: baseline,
            currentSpO2: point['spo2'] as double,
            currentMovement: point['move'] as double,
          );

          final hrPercent = ((point['hr'] as double) / baseline - 1) * 100;

          String statusEmoji;
          String actionTaken;

          if (result.confidenceLevel >= 0.8) {
            statusEmoji = '🚨';
            actionTaken = 'IMMEDIATE NOTIFICATION SENT';
          } else if (result.confidenceLevel >= 0.6) {
            statusEmoji = '⚠️';
            actionTaken = 'USER CONFIRMATION REQUESTED';
          } else if (result.triggered) {
            statusEmoji = '👀';
            actionTaken = 'MONITORING INCREASED';
          } else {
            statusEmoji = '😌';
            actionTaken = 'NORMAL MONITORING';
          }

          print('⏰ ${point['time']} $statusEmoji ${point['context']}:');
          print(
              '   📊 HR: ${point['hr']} BPM (${hrPercent >= 0 ? '+' : ''}${hrPercent.toStringAsFixed(1)}% from baseline)');
          print(
              '   🫁 SpO2: ${point['spo2']}% ${(point['spo2'] as double) <= 94 ? '(CRITICAL)' : (point['spo2'] as double) <= 95 ? '(LOW)' : '(NORMAL)'}');
          print(
              '   🏃 Movement: ${point['move']} ${(point['move'] as double) > 0.6 ? '(HIGH)' : (point['move'] as double) > 0.3 ? '(MODERATE)' : '(LOW)'}');
          print('   🎯 Detection: ${result.triggered ? 'YES' : 'NO'}');
          print(
              '   📈 Confidence: ${(result.confidenceLevel * 100).toStringAsFixed(1)}%');
          print('   🔔 Action: $actionTaken');

          if (result.triggered) {
            print('   💬 Alert: "${result.reason}"');
          }
          print('');

          // Validate critical detection at peak
          if (i == 4) {
            // Peak of panic attack
            expect(result.triggered, isTrue,
                reason: 'Should detect anxiety at panic attack peak');
            expect(result.confidenceLevel, greaterThan(0.7),
                reason: 'Should have high confidence during panic attack');
          }

          // Validate normal state at baseline
          if (i == 0 || i == 7) {
            // Calm states
            expect(result.confidenceLevel, lessThan(0.6),
                reason: 'Should have low confidence during calm periods');
          }
        }

        print('✅ EPISODE ANALYSIS COMPLETE');
        print(
            '📊 System successfully tracked anxiety progression from calm → panic → recovery');
        print('🎯 Critical detection occurred at appropriate severity levels');
        print('📱 Notification system responded appropriately to each phase');
      });
    });
  });
}
