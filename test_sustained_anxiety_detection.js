// Sustained Anxiety Detection Test
// This test will send sustained elevated heart rate to trigger the new Cloud Function
const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

class AnxietyDetectionTester {
  async testSustainedAnxietyDetection() {
    console.log("🚨 Testing Sustained Anxiety Detection...\n");

    try {
      // Step 1: Set up device assignment
      const testUserId = "anxiety_test_" + Date.now();
      const sessionId = "session_" + Date.now();

      console.log("📱 Step 1: Setting up device assignment...");
      const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
      await assignmentRef.set({
        assignedUser: testUserId,
        activeSessionId: sessionId,
        assignedAt: admin.database.ServerValue.TIMESTAMP,
        assignedBy: "anxiety_test",
        description: "Testing sustained anxiety detection",
        status: "active",
      });

      // Set up user session
      const userSessionRef = db.ref(
        `/users/${testUserId}/sessions/${sessionId}/metadata`
      );
      await userSessionRef.set({
        deviceId: "AnxieEase001",
        startTime: admin.database.ServerValue.TIMESTAMP,
        status: "active",
        description: "Sustained anxiety detection test",
        totalDataPoints: 0,
      });

      // Set up user baseline (important for our new Cloud Function!)
      const userBaselineRef = db.ref(`/users/${testUserId}/baseline/heartRate`);
      await userBaselineRef.set(70); // Normal baseline

      console.log("✅ Device assigned to:", testUserId);
      console.log("✅ User baseline set to: 70 BPM");

      // Step 2: Send normal heart rate first (build history)
      console.log("\n💓 Step 2: Building normal heart rate history...");

      for (let i = 0; i < 3; i++) {
        const normalData = {
          heartRate: 68 + Math.floor(Math.random() * 6), // 68-74 BPM (normal)
          spo2: 98,
          bodyTemp: 98.6,
          worn: 1,
          timestamp: Date.now(),
          batteryLevel: 90 - i,
        };

        // Send to device current (triggers our Cloud Function)
        await db.ref("/devices/AnxieEase001/current").set(normalData);

        // Also add to user session data to build history
        const dataRef = db
          .ref(`/users/${testUserId}/sessions/${sessionId}/data`)
          .push();
        await dataRef.set(normalData);

        console.log(
          `📊 Normal HR sent: ${normalData.heartRate} BPM (${i + 1}/3)`
        );
        await new Promise((resolve) => setTimeout(resolve, 3000)); // Wait 3 seconds
      }

      console.log("✅ Normal heart rate baseline established");

      // Step 3: Send sustained elevated heart rate (should trigger anxiety detection)
      console.log("\n🚨 Step 3: Sending sustained elevated heart rate...");
      console.log(
        "⏰ This will take ~30 seconds to trigger sustained detection...\n"
      );

      // Send elevated heart rate for 35+ seconds (5 data points, 10 seconds apart)
      for (let i = 0; i < 4; i++) {
        const elevatedData = {
          heartRate: 95 + Math.floor(Math.random() * 8), // 95-103 BPM (35%+ above baseline)
          spo2: 97,
          bodyTemp: 98.8 + i * 0.1,
          worn: 1,
          timestamp: Date.now(),
          batteryLevel: 86 - i,
        };

        // Send to device current (triggers realTimeSustainedAnxietyDetection)
        await db.ref("/devices/AnxieEase001/current").set(elevatedData);

        // Also add to user session data
        const dataRef = db
          .ref(`/users/${testUserId}/sessions/${sessionId}/data`)
          .push();
        await dataRef.set(elevatedData);

        console.log(
          `🚨 Elevated HR sent: ${elevatedData.heartRate} BPM (${
            ((elevatedData.heartRate - 70) / 70) * 100
          }% above baseline) - ${i + 1}/4`
        );

        // Wait 10 seconds between data points
        if (i < 3) {
          console.log("⏳ Waiting 10 seconds for sustained detection...");
          await new Promise((resolve) => setTimeout(resolve, 10000));
        }
      }

      console.log("\n✅ 30+ seconds of elevated heart rate sent!");
      console.log("🔍 Checking for anxiety detection results...\n");

      // Step 4: Wait and check for anxiety alerts
      await new Promise((resolve) => setTimeout(resolve, 5000)); // Wait 5 more seconds

      // Check for user-specific anxiety alerts
      const userAlertsRef = db.ref(`/users/${testUserId}/alerts`);
      const alertsSnapshot = await userAlertsRef.once("value");
      const alerts = alertsSnapshot.val();

      if (alerts) {
        console.log("🎉 SUCCESS: Anxiety detection triggered!");
        console.log("🔔 Number of alerts:", Object.keys(alerts).length);

        // Show alert details
        Object.entries(alerts).forEach(([alertId, alert]) => {
          console.log(`📱 Alert ${alertId}:`);
          console.log(`   - Severity: ${alert.severity}`);
          console.log(`   - Heart Rate: ${alert.heartRate} BPM`);
          console.log(`   - Duration: ${alert.duration}s`);
          console.log(`   - Baseline: ${alert.baseline} BPM`);
          console.log(`   - Reason: ${alert.reason}`);
        });

        console.log(
          "\n✅ realTimeSustainedAnxietyDetection Cloud Function is working perfectly!"
        );
      } else {
        console.log("⚠️ No anxiety alerts found");
        console.log("💡 Possible reasons:");
        console.log("   - Cloud Function not deployed yet");
        console.log("   - Need more sustained data (30+ seconds required)");
        console.log("   - Baseline not high enough above threshold");

        // Check if data reached user session
        const userCurrentRef = db.ref(
          `/users/${testUserId}/sessions/${sessionId}/current`
        );
        const userCurrentSnapshot = await userCurrentRef.once("value");
        const userCurrent = userCurrentSnapshot.val();

        if (userCurrent) {
          console.log(
            "✅ Data reached user session:",
            userCurrent.heartRate,
            "BPM"
          );
        } else {
          console.log(
            "❌ Data not reaching user session - check Cloud Functions"
          );
        }
      }

      // Step 5: Check Firebase paths for debugging
      console.log("\n📊 Step 5: Firebase structure check...");

      const assignmentSnapshot = await assignmentRef.once("value");
      console.log(
        "Device assignment:",
        assignmentSnapshot.exists() ? "✅ Present" : "❌ Missing"
      );

      const userSessionDataRef = db.ref(
        `/users/${testUserId}/sessions/${sessionId}/data`
      );
      const sessionDataSnapshot = await userSessionDataRef.once("value");
      const sessionData = sessionDataSnapshot.val();
      console.log(
        "User session data points:",
        sessionData ? Object.keys(sessionData).length : 0
      );

      const baselineSnapshot = await userBaselineRef.once("value");
      console.log(
        "User baseline:",
        baselineSnapshot.exists() ? baselineSnapshot.val() + " BPM" : "Missing"
      );

      // Step 6: Clean up (comment out to keep data for inspection)
      console.log("\n🧹 Cleaning up test data...");
      await assignmentRef.remove();
      await db.ref(`/users/${testUserId}`).remove();
      console.log("✅ Test data cleaned up");

      console.log(
        "\n🎯 Test completed! Check your Firebase Functions logs for detailed Cloud Function execution info."
      );
    } catch (error) {
      console.error("\n❌ Test failed:", error.message);
      console.error("Error details:", error);
    }

    process.exit(0);
  }
}

const tester = new AnxietyDetectionTester();
tester.testSustainedAnxietyDetection();
