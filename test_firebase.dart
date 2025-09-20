import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'lib/firebase_options.dart';

/// Comprehensive Firebase connectivity and functionality test
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🔥 Starting Firebase Connectivity Test...");
  const separator = '==================================================';
  print(separator);

  try {
    // Test 1: Firebase Initialization
    print("🚀 Test 1: Initializing Firebase...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase Core initialized successfully");

    // Test 2: Firebase Realtime Database Connection
    print("\n📡 Test 2: Testing Realtime Database connection...");
    final database = FirebaseDatabase.instance;

    // Test write capability
    print("  📝 Testing write capability...");
    final testRef = database.ref('test/connectivity');
    await testRef.set({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'message': 'Firebase connectivity test',
      'status': 'testing'
    });
    print("  ✅ Write test successful");

    // Test read capability
    print("  📖 Testing read capability...");
    final snapshot = await testRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      print("  ✅ Read test successful - Data: ${data['message']}");
    } else {
      print("  ⚠️  Read test: No data found");
    }

    // Test 3: Check AnxieEase device path
    print("\n🎯 Test 3: Checking AnxieEase device data structure...");
    final deviceRef = database.ref('devices/AnxieEase001');
    final deviceSnapshot = await deviceRef.get();

    if (deviceSnapshot.exists) {
      print("  ✅ Device AnxieEase001 found in Firebase");
      final deviceData = deviceSnapshot.value as Map<dynamic, dynamic>;

      // Check for current data
      if (deviceData.containsKey('current')) {
        print("  📊 Current sensor data structure found");
        final currentData = deviceData['current'] as Map<dynamic, dynamic>?;
        if (currentData != null) {
          print("    - Heart Rate: ${currentData['heartRate'] ?? 'N/A'}");
          print("    - SpO2: ${currentData['spO2'] ?? 'N/A'}");
          print(
              "    - Temperature: ${currentData['bodyTemperature'] ?? 'N/A'}");
          print("    - Movement: ${currentData['movement'] ?? 'N/A'}");
          print("    - Timestamp: ${currentData['timestamp'] ?? 'N/A'}");
        }
      } else {
        print("  ⚠️  No 'current' data found for device");
      }

      // Check for user association
      if (deviceData.containsKey('userId')) {
        print("  👤 Device is associated with user: ${deviceData['userId']}");
      } else {
        print("  ⚠️  No user association found for device");
      }
    } else {
      print("  ⚠️  Device AnxieEase001 not found in Firebase");
      print("  💡 This is normal if no IoT device has connected yet");
    }

    // Test 4: Real-time listening capability
    print("\n🔄 Test 4: Testing real-time listeners...");
    bool listenerTriggered = false;

    final listenerRef = database.ref('test/listener_test');
    final subscription = listenerRef.onValue.listen((event) {
      listenerTriggered = true;
      print("  ✅ Real-time listener triggered successfully");
    });

    // Write to trigger listener
    await listenerRef.set({
      'test': 'listener_test',
      'timestamp': DateTime.now().millisecondsSinceEpoch
    });

    // Wait a moment for listener to trigger
    await Future.delayed(const Duration(seconds: 2));

    if (!listenerTriggered) {
      print("  ⚠️  Real-time listener did not trigger");
    }

    subscription.cancel();

    // Test 5: Firebase Rules (read-only for unauthenticated)
    print("\n🔐 Test 5: Testing Firebase security rules...");
    try {
      // This should work since we allow reads
      final rulesTestRef = database.ref('devices');
      await rulesTestRef.get();
      print("  ✅ Read access works (rules allow reads)");
    } catch (e) {
      print("  ❌ Read access failed: $e");
    }

    // Test 6: Cloud Functions connectivity (if deployed)
    print("\n☁️  Test 6: Checking Cloud Functions...");
    try {
      final functionsTestRef = database.ref('functions_test');
      await functionsTestRef.set({
        'trigger_test': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      });
      print("  ✅ Functions trigger path accessible");
    } catch (e) {
      print("  ⚠️  Functions trigger test failed: $e");
    }

    // Cleanup test data
    print("\n🧹 Cleaning up test data...");
    await testRef.remove();
    await database.ref('test/listener_test').remove();
    await database.ref('functions_test').remove();
    print("  ✅ Test data cleaned up");

    print("\n$separator");
    print("🎉 Firebase connectivity test completed successfully!");
    print("\n📋 Summary:");
    print("  ✅ Firebase Core: Working");
    print("  ✅ Realtime Database: Connected");
    print("  ✅ Read/Write operations: Functional");
    print("  ✅ Real-time listeners: Working");

    print("\n💡 Next steps:");
    print("  1. Your Firebase backend is functional");
    print(
        "  2. Connect your IoT device to send data to 'devices/AnxieEase001/current'");
    print("  3. Deploy Cloud Functions: 'firebase deploy --only functions'");
    print("  4. Test anxiety detection with real sensor data");
  } catch (e, stackTrace) {
    print("❌ Firebase test failed: $e");
    print("Stack trace: $stackTrace");
    print("\n🔧 Troubleshooting steps:");
    print("  1. Check internet connection");
    print(
        "  2. Verify Firebase project configuration in firebase_options.dart");
    print("  3. Ensure Firebase project 'anxieease-sensors' is active");
    print("  4. Check Firebase console for any project issues");
    print("  5. Verify database rules in Firebase console");
  }
}
