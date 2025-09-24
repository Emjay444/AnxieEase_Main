// Fixed Sustained Anxiety Detection Test
// This test sends data with proper timestamps to trigger sustained detection
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

class FixedAnxietyDetectionTester {
  async testFixedSustainedDetection() {
    console.log("🔧 Testing FIXED Sustained Anxiety Detection...\n");

    try {
      // Step 1: Set up device assignment
      const testUserId = "fixed_test_" + Date.now();
      const sessionId = "session_" + Date.now();

      console.log("📱 Step 1: Setting up device assignment...");
      const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
      await assignmentRef.set({
        assignedUser: testUserId,
        activeSessionId: sessionId,
        assignedAt: admin.database.ServerValue.TIMESTAMP,
        assignedBy: "fixed_test",
        description: "Testing FIXED sustained anxiety detection",
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
        description: "Fixed sustained anxiety detection test",
        totalDataPoints: 0,
      });

      // Set up user baseline
      const userBaselineRef = db.ref(`/users/${testUserId}/baseline/heartRate`);
      await userBaselineRef.set(70); // Normal baseline

      console.log("✅ Device assigned to:", testUserId);
      console.log("✅ User baseline set to: 70 BPM (threshold will be 84 BPM)");

      // Step 2: Build user session history with REALISTIC timestamps
      console.log("\n💓 Step 2: Building realistic user session history...");

      const baseTime = Date.now() - 60000; // Start 1 minute ago
      const userSessionDataRef = db.ref(
        `/users/${testUserId}/sessions/${sessionId}/data`
      );

      // Add sustained elevated data points over 35+ seconds
      const historyDataPoints = [
        { heartRate: 68, timestamp: baseTime, worn: 1, spo2: 98 }, // 60s ago (normal)
        { heartRate: 71, timestamp: baseTime + 10000, worn: 1, spo2: 98 }, // 50s ago (normal)
        { heartRate: 96, timestamp: baseTime + 25000, worn: 1, spo2: 97 }, // 35s ago (ELEVATED - START)
        { heartRate: 98, timestamp: baseTime + 35000, worn: 1, spo2: 97 }, // 25s ago (ELEVATED)
        { heartRate: 95, timestamp: baseTime + 45000, worn: 1, spo2: 97 }, // 15s ago (ELEVATED)
        { heartRate: 97, timestamp: baseTime + 55000, worn: 1, spo2: 97 }, // 5s ago (ELEVATED)
      ];

      console.log(
        "📊 Adding historical data points with 35+ second sustained elevation:"
      );
      for (const dataPoint of historyDataPoints) {
        const dataRef = userSessionDataRef.push();
        await dataRef.set(dataPoint);

        const secondsAgo = Math.floor(
          (Date.now() - dataPoint.timestamp) / 1000
        );
        const status = dataPoint.heartRate >= 84 ? "🚨 ELEVATED" : "✅ Normal";
        console.log(
          `   ${secondsAgo}s ago: ${dataPoint.heartRate} BPM ${status}`
        );
      }

      console.log(
        "✅ User session history established with sustained elevated period"
      );

      // Step 3: Send current elevated data (should trigger detection with 30s+ history)
      console.log("\n🚨 Step 3: Sending current elevated heart rate...");

      const currentElevatedData = {
        heartRate: 99, // Above 84 BPM threshold
        spo2: 97,
        bodyTemp: 99.1,
        worn: 1,
        timestamp: Date.now(),
        batteryLevel: 82,
      };

      console.log(
        `🚨 Current data: ${currentElevatedData.heartRate} BPM (ELEVATED - should complete 30+ second sustained period)`
      );

      // Send to device current (triggers Cloud Function)
      await db.ref("/devices/AnxieEase001/current").set(currentElevatedData);

      console.log("✅ Data sent to trigger Cloud Function...");

      // Step 4: Wait and check for anxiety detection
      console.log("\n⏳ Step 4: Waiting for anxiety detection (10 seconds)...");
      await new Promise((resolve) => setTimeout(resolve, 10000));

      // Check for user anxiety alerts
      const userAlertsRef = db.ref(`/users/${testUserId}/alerts`);
      const alertsSnapshot = await userAlertsRef.once("value");
      const alerts = alertsSnapshot.val();

      if (alerts) {
        console.log("\n🎉 SUCCESS! Anxiety detection triggered!");
        console.log("🔔 Number of alerts:", Object.keys(alerts).length);

        Object.entries(alerts).forEach(([alertId, alert]) => {
          console.log(`📱 Alert ${alertId}:`);
          console.log(`   ✅ Severity: ${alert.severity}`);
          console.log(`   ✅ Heart Rate: ${alert.heartRate} BPM`);
          console.log(`   ✅ Duration: ${alert.duration}s`);
          console.log(`   ✅ Baseline: ${alert.baseline} BPM`);
          console.log(`   ✅ Reason: ${alert.reason}`);
          console.log(
            `   ✅ Timestamp: ${new Date(alert.timestamp).toLocaleString()}`
          );
        });

        console.log(
          "\n🎯 FIXED: realTimeSustainedAnxietyDetection is working perfectly!"
        );
      } else {
        console.log("\n⚠️ No anxiety alerts found yet...");

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
          console.log(
            "💡 The detection may take a few more seconds to process..."
          );
        } else {
          console.log(
            "❌ Data not reaching user session - check Cloud Functions"
          );
        }
      }

      // Step 5: Check recent function logs
      console.log("\n📊 Step 5: Data structure verification...");

      const sessionDataSnapshot = await userSessionDataRef.once("value");
      const sessionData = sessionDataSnapshot.val();
      console.log(
        "✅ User session data points:",
        sessionData ? Object.keys(sessionData).length : 0
      );

      if (sessionData) {
        const dataPoints = Object.values(sessionData).sort(
          (a, b) => a.timestamp - b.timestamp
        );
        console.log("📊 Chronological heart rate data:");
        dataPoints.slice(-4).forEach((point, index) => {
          const status = point.heartRate >= 84 ? "🚨" : "✅";
          console.log(
            `   ${status} ${point.heartRate} BPM at ${new Date(
              point.timestamp
            ).toLocaleTimeString()}`
          );
        });
      }

      // Step 6: Wait a bit more and check again
      console.log("\n⏳ Final check in 5 seconds...");
      await new Promise((resolve) => setTimeout(resolve, 5000));

      const finalAlertsSnapshot = await userAlertsRef.once("value");
      const finalAlerts = finalAlertsSnapshot.val();

      if (finalAlerts && !alerts) {
        console.log("🎉 SUCCESS! Anxiety detection triggered on final check!");
        console.log("🔔 Total alerts:", Object.keys(finalAlerts).length);
      }

      // Optional: Keep data for inspection (comment out to keep)
      console.log("\n🧹 Cleaning up test data...");
      await assignmentRef.remove();
      await db.ref(`/users/${testUserId}`).remove();
      console.log("✅ Test data cleaned up");

      console.log("\n🎯 Fixed Sustained Anxiety Detection Test Complete!");
    } catch (error) {
      console.error("\n❌ Test failed:", error.message);
      console.error("Error details:", error);
    }

    process.exit(0);
  }
}

const tester = new FixedAnxietyDetectionTester();
tester.testFixedSustainedDetection();
