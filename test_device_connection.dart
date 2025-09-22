import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// Simple test script to verify device connection and data reading from Firebase
/// This helps debug device linking issues
void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();

  final database = FirebaseDatabase.instance;

  // Test device ID from your screenshot
  final deviceId = 'AnxieEase001';

  print('🔍 Testing device connection for: $deviceId');
  print('📱 Checking Firebase path: /devices/$deviceId');

  try {
    // Check if device exists
    final deviceRef = database.ref('devices/$deviceId');
    final snapshot = await deviceRef.once();

    if (!snapshot.snapshot.exists) {
      print('❌ Device not found in Firebase at /devices/$deviceId');
      return;
    }

    print('✅ Device found in Firebase');

    // Check current data
    final currentRef = deviceRef.child('current');
    final currentSnapshot = await currentRef.once();

    if (!currentSnapshot.snapshot.exists) {
      print('❌ No current data found at /devices/$deviceId/current');
      return;
    }

    print('✅ Current data found');

    // Parse and display the data
    final data =
        Map<String, dynamic>.from(currentSnapshot.snapshot.value as Map);

    print('📊 Device Data:');
    print('   - Battery: ${data['battPerc']}%');
    print('   - Heart Rate: ${data['heartRate']} bpm');
    print('   - Body Temp: ${data['bodyTemp']}°C');
    print('   - Ambient Temp: ${data['ambientTemp']}°C');
    print('   - Timestamp: ${data['timestamp']}');
    print('   - Status: ${data['status']}');

    // Check timestamp freshness
    final timestampValue = data['timestamp'];
    if (timestampValue != null) {
      DateTime? dataTime;

      if (timestampValue is String) {
        try {
          dataTime = DateTime.parse(timestampValue);
        } catch (e) {
          print('⚠️  Could not parse timestamp: $timestampValue');
        }
      }

      if (dataTime != null) {
        final timeDifference = DateTime.now().difference(dataTime);
        print('⏰ Data age: ${timeDifference.inSeconds} seconds old');

        if (timeDifference.inSeconds < 60) {
          print('✅ Device data is fresh (recent)');
        } else {
          print('⚠️  Device data is stale (over 60 seconds old)');
        }
      }
    }

    // Determine if device should be considered "connected"
    final hasRecentData = timestampValue != null;
    final hasBattery = data['battPerc'] != null;
    final deviceSendingData = hasRecentData && (hasBattery || data.isNotEmpty);
    final isExplicitlyDisconnected =
        (data['connectionStatus'] ?? '').toString().toLowerCase() ==
                'disconnected' ||
            data['isConnected'] == false;

    final isConnected = !isExplicitlyDisconnected && deviceSendingData;

    print('🔄 Connection Analysis:');
    print('   - Has Recent Data: $hasRecentData');
    print('   - Has Battery Info: $hasBattery');
    print('   - Sending Data: $deviceSendingData');
    print('   - Explicitly Disconnected: $isExplicitlyDisconnected');
    print(
        '   - Final Status: ${isConnected ? "CONNECTED ✅" : "DISCONNECTED ❌"}');

    if (isConnected) {
      print('');
      print('🎉 Device validation should PASS - device linking should work!');
    } else {
      print('');
      print(
          '❌ Device validation would FAIL - this explains why device linking doesn\'t work');
    }
  } catch (e) {
    print('❌ Error testing device connection: $e');
  }
}
