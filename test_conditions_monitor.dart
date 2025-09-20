import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:anxiease/services/anxiety_detection_engine.dart';
import 'lib/firebase_options.dart';

/// Real-time anxiety detection condition monitoring
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🔍 REAL-TIME ANXIETY CONDITION MONITOR");
  const separator = '==================================================';
  print(separator);

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("✅ Firebase initialized - monitoring AnxieEase001");

    final database = FirebaseDatabase.instance;
    final deviceRef = database.ref('devices/AnxieEase001/current');
    final engine = AnxietyDetectionEngine();
    
    print("\n🎯 MONITORING CONDITIONS:");
    print("  📊 Heart Rate Thresholds:");
    print("     - Mild Anxiety: 20-30% above baseline");
    print("     - High Anxiety: 30%+ above baseline");
    print("  🫁 SpO2 Thresholds:");
    print("     - Low: ≤94% (moderate concern)");
    print("     - Critical: ≤90% (emergency)");
    print("  🏃 Movement: 0.0-1.0 scale");
    print("\n⏱️  Starting real-time monitoring...");
    print("   (Press Ctrl+C to stop)\n");

    // Set up real-time listener
    int detectionCount = 0;
    DateTime? lastAlert;
    double? baselineHR;
    
    deviceRef.onValue.listen((event) {
      final timestamp = DateTime.now().toString().substring(11, 19);
      
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        
        final hr = (data['heartRate'] ?? 0).toDouble();
        final spo2 = (data['spO2'] ?? 100).toDouble();
        final temp = (data['bodyTemp'] ?? 36.5).toDouble();
        final movement = (data['movement'] ?? 0.0).toDouble();
        final worn = data['worn'] ?? false;
        
        // Set baseline HR from first reading if not set
        if (baselineHR == null && hr > 0) {
          baselineHR = hr;
          print("📏 Baseline HR set to: ${baselineHR!.toInt()} bpm");
        }
        
        if (baselineHR != null && hr > 0) {
          // Run anxiety detection
          final result = engine.detectAnxiety(
            currentHeartRate: hr,
            restingHeartRate: baselineHR!,
            currentSpO2: spo2,
            currentMovement: movement,
            bodyTemperature: temp,
          );
          
          detectionCount++;
          
          // Calculate HR percentage above baseline
          final hrIncrease = ((hr - baselineHR!) / baselineHR!) * 100;
          
          // Color-coded output based on conditions
          String status = "🟢 NORMAL";
          String details = "";
          
          if (result.triggered) {
            if (result.confidenceLevel >= 80) {
              status = "🔴 HIGH ANXIETY";
            } else if (result.confidenceLevel >= 60) {
              status = "🟡 MILD ANXIETY";
            }
            lastAlert = DateTime.now();
          }
          
          // SpO2 status
          String spo2Status = "🟢";
          if (spo2 <= 90) {
            spo2Status = "🚨 CRITICAL";
          } else if (spo2 <= 94) {
            spo2Status = "🟡 LOW";
          }
          
          // HR status  
          String hrStatus = "🟢";
          if (hrIncrease >= 30) {
            hrStatus = "🔴 HIGH";
          } else if (hrIncrease >= 20) {
            hrStatus = "🟡 ELEVATED";
          }
          
          print("[$timestamp] Detection #$detectionCount");
          print("  💓 HR: ${hr.toInt()} bpm (+${hrIncrease.toStringAsFixed(1)}%) $hrStatus");
          print("  🫁 SpO2: ${spo2.toInt()}% $spo2Status");
          print("  🌡️  Temp: ${temp.toStringAsFixed(1)}°C");
          print("  🏃 Movement: ${movement.toStringAsFixed(2)}");
          print("  👕 Worn: ${worn ? '✅' : '❌'}");
          
          if (result.triggered) {
            print("  🚨 ANXIETY DETECTED: $status");
            print("     Confidence: ${result.confidenceLevel}%");
            print("     Reason: ${result.reason}");
            print("     Alert Type: ${result.requiresUserConfirmation ? 'CONFIRMATION NEEDED' : 'IMMEDIATE'}");
            
            if (result.abnormalMetrics.isNotEmpty) {
              final abnormal = result.abnormalMetrics.entries
                  .where((e) => e.value)
                  .map((e) => e.key)
                  .join(", ");
              print("     Abnormal: $abnormal");
            }
          } else {
            print("  ✅ Status: $status");
          }
          
          // Check condition thresholds
          print("  📊 CONDITION CHECK:");
          print("     HR Threshold (20%): ${(baselineHR! * 1.2).toInt()} bpm ${hr >= baselineHR! * 1.2 ? '⚠️  EXCEEDED' : '✅'}");
          print("     HR Threshold (30%): ${(baselineHR! * 1.3).toInt()} bpm ${hr >= baselineHR! * 1.3 ? '🚨 EXCEEDED' : '✅'}");
          print("     SpO2 Low (94%): ${spo2 <= 94 ? '⚠️  TRIGGERED' : '✅'}");
          print("     SpO2 Critical (90%): ${spo2 <= 90 ? '🚨 TRIGGERED' : '✅'}");
          
          print("");
          
        } else {
          print("[$timestamp] Waiting for valid heart rate data...");
        }
        
      } else {
        print("[$timestamp] No sensor data available");
      }
    });

    // Keep the app running
    print("📡 Listening for real-time sensor data...");
    print("💡 Adjust your device sensors to test different conditions!");
    
    // Summary every 30 seconds
    Stream.periodic(Duration(seconds: 30)).listen((_) {
      print("\n📊 MONITORING SUMMARY (${DateTime.now().toString().substring(11, 19)}):");
      print("   Detections processed: $detectionCount");
      print("   Last alert: ${lastAlert?.toString().substring(11, 19) ?? 'None'}");
      print("   Baseline HR: ${baselineHR?.toInt() ?? 'Not set'} bpm");
      print("");
    });

  } catch (e) {
    print("❌ Monitoring failed: $e");
    print("\n💡 Troubleshooting:");
    print("  1. Ensure your IoT device is connected");
    print("  2. Check Firebase connection");
    print("  3. Verify device is sending data to AnxieEase001");
  }
}