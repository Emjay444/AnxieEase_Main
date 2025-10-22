/**
 * Test Real-Time Anxiety Detection
 *
 * This script simulates elevated heart rate data to test if the
 * realTimeSustainedAnxietyDetection Cloud Function triggers and
 * sends anxiety alert notifications correctly.
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function testRealtimeAnxietyDetection() {
  console.log("🧪 Testing Real-Time Anxiety Detection\n");

  const deviceId = "AnxieEase001";

  try {
    // Step 1: Check current device state
    console.log("📊 Step 1: Checking current device state...");
    const currentRef = db.ref(`devices/${deviceId}/current`);
    const currentSnap = await currentRef.once("value");
    const currentData = currentSnap.val();

    console.log(`   Current heart rate: ${currentData?.heartRate || "N/A"}`);
    console.log(`   Device worn: ${currentData?.worn || 0}`);

    // Step 2: Check device assignment
    console.log("\n👤 Step 2: Checking device assignment...");
    const assignmentRef = db.ref(`devices/${deviceId}/assignment`);
    const assignmentSnap = await assignmentRef.once("value");
    const assignment = assignmentSnap.val();

    if (!assignment || !assignment.assignedUser) {
      console.log("   ❌ Device not assigned to a user");
      console.log("   Please assign the device to a user first.");
      process.exit(1);
    }

    console.log(`   ✅ Assigned to: ${assignment.assignedUser}`);
    console.log(`   Active session: ${assignment.activeSessionId || "None"}`);
    console.log(
      `   FCM Token: ${
        assignment.fcmToken
          ? assignment.fcmToken.substring(0, 30) + "..."
          : "None"
      }`
    );

    // Step 3: Simulate elevated heart rate sequence
    console.log("\n💓 Step 3: Simulating elevated heart rate sequence...");
    console.log(
      "   This will write heart rate values that should trigger anxiety detection\n"
    );

    const elevatedHeartRates = [95, 98, 102, 105, 108];

    for (let i = 0; i < elevatedHeartRates.length; i++) {
      const hr = elevatedHeartRates[i];

      console.log(
        `   [${i + 1}/${
          elevatedHeartRates.length
        }] Setting heart rate to ${hr} BPM...`
      );

      await currentRef.update({
        heartRate: hr,
        worn: 1, // Device is worn
        timestamp: new Date().toISOString(),
        bodyTemp: 36.5 + Math.random() * 0.5,
        spo2: 95 + Math.random() * 3,
      });

      console.log(`   ✅ Heart rate updated to ${hr} BPM`);

      // Wait 3 seconds between updates to simulate sustained elevated heart rate
      if (i < elevatedHeartRates.length - 1) {
        console.log("   ⏳ Waiting 3 seconds...\n");
        await new Promise((resolve) => setTimeout(resolve, 3000));
      }
    }

    console.log("\n✅ Test sequence completed!");
    console.log("\n📱 Check your device for anxiety alert notification");
    console.log("🔍 You can also check Cloud Function logs with:");
    console.log(
      "   npx firebase-tools functions:log --only realTimeSustainedAnxietyDetection -n 10"
    );

    // Step 4: Wait and check if alert was created
    console.log("\n⏳ Waiting 5 seconds for Cloud Function to process...\n");
    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log("📋 Step 4: Checking if anxiety alert was created...");
    const alertsRef = db.ref(`devices/${deviceId}/alerts`);
    const alertsSnap = await alertsRef
      .orderByChild("timestamp")
      .limitToLast(1)
      .once("value");

    if (alertsSnap.exists()) {
      const alerts = alertsSnap.val();
      const latestAlertId = Object.keys(alerts)[0];
      const latestAlert = alerts[latestAlertId];

      console.log("✅ Latest alert found:");
      console.log(`   Alert ID: ${latestAlertId}`);
      console.log(`   Severity: ${latestAlert.severity}`);
      console.log(`   Timestamp: ${latestAlert.timestamp}`);
      console.log(`   Message: ${latestAlert.message}`);
    } else {
      console.log("⚠️  No alerts found in RTDB");
      console.log("   This might mean:");
      console.log("   - Function needs more time to process");
      console.log("   - Heart rate threshold not met");
      console.log("   - Rate limiting active (5 min between alerts)");
    }

    // Reset heart rate to normal
    console.log("\n🔄 Resetting heart rate to normal levels...");
    await currentRef.update({
      heartRate: 75,
      timestamp: new Date().toISOString(),
    });
    console.log("✅ Heart rate reset to 75 BPM");
  } catch (error) {
    console.error("❌ Error during test:", error);
    process.exit(1);
  }

  process.exit(0);
}

// Run the test
testRealtimeAnxietyDetection();
