import 'package:flutter_test/flutter_test.dart';
import 'package:anxiease/services/anxiety_detection_engine.dart';

void main() {
  group('AnxietyDetectionEngine Tests', () {
    late AnxietyDetectionEngine engine;

    setUp(() {
      engine = AnxietyDetectionEngine();
    });

    tearDown(() {
      engine.reset();
    });

    group('Heart Rate Analysis', () {
      test('should detect high heart rate (20% above baseline)', () {
        const restingHR = 70.0;
        const currentHR = 84.0; // 20% above baseline
        
        final result = engine.detectAnxiety(
          currentHeartRate: currentHR,
          restingHeartRate: restingHR,
          currentSpO2: 98.0,
          currentMovement: 10.0,
        );

        // Single metric abnormal should require confirmation
        expect(result.triggered, true);
        expect(result.reason, 'highHR');
        expect(result.requiresUserConfirmation, true);
        expect(result.confidenceLevel, 0.6);
      });

      test('should detect very high heart rate (30% above baseline)', () {
        const restingHR = 70.0;
        const currentHR = 91.0; // 30% above baseline
        
        // Build up sustained high HR over 30 readings
        for (int i = 0; i < 30; i++) {
          engine.detectAnxiety(
            currentHeartRate: currentHR,
            restingHeartRate: restingHR,
            currentSpO2: 98.0,
            currentMovement: 10.0,
          );
        }

        final result = engine.detectAnxiety(
          currentHeartRate: currentHR,
          restingHeartRate: restingHR,
          currentSpO2: 98.0,
          currentMovement: 10.0,
        );

        expect(result.triggered, true);
        expect(result.reason, 'highHR');
        expect(result.abnormalMetrics['heartRate'], true);
      });

      test('should detect unusually low heart rate', () {
        const restingHR = 70.0;
        const currentHR = 45.0; // Below 50 BPM threshold
        
        // Build up sustained low HR
        for (int i = 0; i < 30; i++) {
          engine.detectAnxiety(
            currentHeartRate: currentHR,
            restingHeartRate: restingHR,
            currentSpO2: 98.0,
            currentMovement: 10.0,
          );
        }

        final result = engine.detectAnxiety(
          currentHeartRate: currentHR,
          restingHeartRate: restingHR,
          currentSpO2: 98.0,
          currentMovement: 10.0,
        );

        expect(result.triggered, true);
        expect(result.reason, 'lowHR');
        expect(result.abnormalMetrics['heartRate'], true);
      });
    });

    group('SpO2 Analysis', () {
      test('should detect low SpO2 requiring confirmation', () {
        final result = engine.detectAnxiety(
          currentHeartRate: 70.0,
          restingHeartRate: 70.0,
          currentSpO2: 92.0, // Below 94% threshold
          currentMovement: 10.0,
        );

        expect(result.triggered, true);
        expect(result.reason, 'lowSpO2');
        expect(result.requiresUserConfirmation, true);
        expect(result.abnormalMetrics['spO2'], true);
      });

      test('should detect critical SpO2 without confirmation', () {
        final result = engine.detectAnxiety(
          currentHeartRate: 70.0,
          restingHeartRate: 70.0,
          currentSpO2: 88.0, // Below 90% critical threshold
          currentMovement: 10.0,
        );

        expect(result.triggered, true);
        expect(result.reason, 'criticalSpO2');
        expect(result.requiresUserConfirmation, false);
        expect(result.confidenceLevel, 1.0);
      });
    });

    group('Movement Analysis', () {
      test('should detect movement spikes', () {
        // Build up baseline movement
        for (int i = 0; i < 20; i++) {
          engine.detectAnxiety(
            currentHeartRate: 70.0,
            restingHeartRate: 70.0,
            currentSpO2: 98.0,
            currentMovement: 15.0, // Low baseline movement
          );
        }

        final result = engine.detectAnxiety(
          currentHeartRate: 70.0,
          restingHeartRate: 70.0,
          currentSpO2: 98.0,
          currentMovement: 80.0, // Sudden spike
        );

        expect(result.abnormalMetrics['movement'], true);
      });
    });

    group('Multi-Parameter Detection', () {
      test('should trigger without confirmation for multiple abnormal metrics', () {
        // Build sustained abnormal readings
        for (int i = 0; i < 30; i++) {
          engine.detectAnxiety(
            currentHeartRate: 84.0, // 20% above baseline of 70
            restingHeartRate: 70.0,
            currentSpO2: 92.0, // Below 94% threshold
            currentMovement: 60.0, // High movement
          );
        }

        final result = engine.detectAnxiety(
          currentHeartRate: 84.0,
          restingHeartRate: 70.0,
          currentSpO2: 92.0,
          currentMovement: 60.0,
        );

        expect(result.triggered, true);
        expect(result.requiresUserConfirmation, false);
        expect(result.confidenceLevel, greaterThan(0.8));
        expect(result.reason, anyOf([
          'combinedHRSpO2',
          'combinedHRMovement', 
          'multipleMetrics'
        ]));
      });

      test('should have highest confidence for HR + Movement combination', () {
        // Build sustained readings
        for (int i = 0; i < 30; i++) {
          engine.detectAnxiety(
            currentHeartRate: 91.0, // 30% above baseline of 70
            restingHeartRate: 70.0,
            currentSpO2: 98.0, // Normal
            currentMovement: 5.0, // Low baseline
          );
        }

        // Then detect HR + Movement spike
        final result = engine.detectAnxiety(
          currentHeartRate: 91.0,
          restingHeartRate: 70.0,
          currentSpO2: 98.0,
          currentMovement: 80.0, // Movement spike
        );

        expect(result.triggered, true);
        expect(result.reason, 'combinedHRMovement');
        expect(result.confidenceLevel, greaterThan(0.85));
      });
    });

    group('Edge Cases', () {
      test('should not trigger for normal readings', () {
        final result = engine.detectAnxiety(
          currentHeartRate: 72.0, // Normal, close to baseline
          restingHeartRate: 70.0,
          currentSpO2: 98.0,
          currentMovement: 15.0,
        );

        expect(result.triggered, false);
        expect(result.reason, 'normal');
        expect(result.confidenceLevel, 0.0);
      });

      test('should handle missing body temperature gracefully', () {
        final result = engine.detectAnxiety(
          currentHeartRate: 85.0,
          restingHeartRate: 70.0,
          currentSpO2: 98.0,
          currentMovement: 15.0,
          // bodyTemperature not provided
        );

        expect(result.metrics['bodyTemperature'], null);
        // Should still work without body temperature
        expect(result.triggered, true);
      });

      test('should reset historical data correctly', () {
        // Build up some history
        for (int i = 0; i < 50; i++) {
          engine.detectAnxiety(
            currentHeartRate: 85.0,
            restingHeartRate: 70.0,
            currentSpO2: 98.0,
            currentMovement: 15.0,
          );
        }

        var status = engine.getDetectionStatus();
        expect(status['historicalDataPoints'], greaterThan(0));

        // Reset
        engine.reset();

        status = engine.getDetectionStatus();
        expect(status['historicalDataPoints'], 0);
        expect(status['recentHRAverage'], 0.0);
      });
    });

    group('Confidence Levels', () {
      test('should have appropriate confidence levels for different scenarios', () {
        // Single metric abnormal
        var result = engine.detectAnxiety(
          currentHeartRate: 90.0,
          restingHeartRate: 70.0,
          currentSpO2: 98.0,
          currentMovement: 15.0,
        );
        expect(result.confidenceLevel, 0.6);

        // Critical SpO2
        result = engine.detectAnxiety(
          currentHeartRate: 70.0,
          restingHeartRate: 70.0,
          currentSpO2: 88.0,
          currentMovement: 15.0,
        );
        expect(result.confidenceLevel, 1.0);

        // Build up for multiple metrics
        engine.reset();
        for (int i = 0; i < 30; i++) {
          engine.detectAnxiety(
            currentHeartRate: 85.0,
            restingHeartRate: 70.0,
            currentSpO2: 92.0,
            currentMovement: 15.0,
          );
        }

        result = engine.detectAnxiety(
          currentHeartRate: 85.0,
          restingHeartRate: 70.0,
          currentSpO2: 92.0,
          currentMovement: 15.0,
        );
        expect(result.confidenceLevel, greaterThanOrEqualTo(0.85));
      });
    });
  });
}