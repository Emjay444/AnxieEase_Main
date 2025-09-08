import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:anxiease/firebase_options.dart';
import 'package:anxiease/services/iot_sensor_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Firebase for tests
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  });

  group('IoT Sensor Service Tests', () {
    late IoTSensorService iotService;

    setUp(() {
      iotService = IoTSensorService();
    });

    tearDown(() {
      iotService.dispose();
    });

    test('IoT Service initializes with default values', () {
      expect(iotService.heartRate, 72.0);
      expect(iotService.spo2, 98.0);
      expect(iotService.bodyTemperature, 36.5);
      expect(iotService.batteryLevel, 85.0);
      expect(iotService.isConnected, false);
      expect(iotService.isActive, false);
    });

    test('IoT Service can start and stop monitoring', () async {
      // Test start
      await iotService.startSensors();
      expect(iotService.isActive, true);
      expect(iotService.isConnected, true);

      // Wait a moment for sensor data to update
      await Future.delayed(const Duration(milliseconds: 100));

      // Test stop
      await iotService.stopSensors();
      expect(iotService.isActive, false);
      expect(iotService.isConnected, false);
    });

    test('IoT Service simulates realistic sensor values', () async {
      await iotService.startSensors();

      // Allow some time for sensor simulation to run
      await Future.delayed(const Duration(seconds: 2));

      // Check that values are within realistic ranges
      expect(iotService.heartRate, inInclusiveRange(60.0, 120.0));
      expect(iotService.spo2, inInclusiveRange(95.0, 100.0));
      expect(iotService.bodyTemperature, inInclusiveRange(36.0, 37.5));
      expect(iotService.batteryLevel, inInclusiveRange(0.0, 100.0));

      await iotService.stopSensors();
    });

    test('IoT Service handles stress simulation', () async {
      await iotService.startSensors();

      // Trigger stress simulation
      await iotService.simulateStressEvent();

      // Allow time for stress response
      await Future.delayed(const Duration(seconds: 1));

      // Heart rate should be elevated during stress
      expect(iotService.heartRate, greaterThan(80.0));

      await iotService.stopSensors();
    });

    test('IoT Service device ID and user ID are set correctly', () {
      expect(iotService.deviceId, contains('AnxieEase'));
    });
  });
}
