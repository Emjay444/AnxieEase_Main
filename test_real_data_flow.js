/**
 * 🎯 CORRECTED ANXIETY DETECTION TEST
 *
 * This test simulates the REAL data flow:
 * 1. Device writes to /devices/{deviceId}/current
 * 2. Firebase Function detects anxiety and sends notification
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

const REAL_USER_ID = "5efad7d4-3dcd-4333-ba4b-41f86";
const REAL_DEVICE_ID = "AnxieEase001";
const USER_FCM_TOKEN =
  "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0";

async function testRealDataFlow() {
  console.log("\n🎯 TESTING REAL ANXIETY DETECTION DATA FLOW");
  console.log("===========================================");

  try {
    // Step 1: Set up proper device assignment format
    console.log("\n📟 Step 1: Setting up proper device assignment...");
    const sessionId = `session_${Date.now()}`;

    await db.ref(`/devices/${REAL_DEVICE_ID}/assignment`).set({
      assignedUser: REAL_USER_ID, // Function expects 'assignedUser' not 'userId'
      activeSessionId: sessionId, // Function expects 'activeSessionId' not 'sessionId'
      deviceId: REAL_DEVICE_ID,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
    });

    console.log(`✅ Device assignment corrected:`);
    console.log(`   assignedUser: ${REAL_USER_ID}`);
    console.log(`   activeSessionId: ${sessionId}`);

    // Step 2: Set up user profile with FCM token
    console.log("\n💓 Step 2: Setting up user baseline and FCM token...");

    // Set user baseline
    await db.ref(`/users/${REAL_USER_ID}/baseline`).set({
      heartRate: 70,
      timestamp: Date.now(),
      source: "corrected_test",
    });

    // Set FCM token
    await db.ref(`/users/${REAL_USER_ID}/fcmToken`).set(USER_FCM_TOKEN);

    console.log("✅ User baseline: 70 BPM (threshold: 84 BPM)");
    console.log("✅ FCM token stored");

    // Step 3: Clear previous alerts
    console.log("\n🧹 Step 3: Clearing previous alerts...");
    await db.ref(`/users/${REAL_USER_ID}/alerts`).remove();
    console.log("✅ Previous alerts cleared");

    // Step 4: Simulate device sending data to /devices/{deviceId}/current
    console.log("\n🚨 Step 4: Simulating wearable device data...");
    console.log("This simulates the REAL data flow from AnxieEase001 device");
    console.log("🔔 WATCH YOUR PHONE FOR NOTIFICATIONS!");

    // Send sustained elevated heart rate data to device/current (triggers Firebase Function)
    for (let i = 0; i < 25; i++) {
      const heartRate = 85 + Math.random() * 10; // 85-95 BPM (above 84 threshold)
      const timestamp = Date.now();

      const deviceData = {
        heartRate: Math.round(heartRate * 10) / 10,
        timestamp: timestamp,
        deviceId: REAL_DEVICE_ID,
        batteryLevel: 85 - i, // Simulate decreasing battery
        source: "wearable_device",
        sessionId: sessionId,
      };

      // Write to device current path (this triggers the Firebase Function!)
      await db.ref(`/devices/${REAL_DEVICE_ID}/current`).set(deviceData);

      const elapsed = (i + 1) * 2;
      console.log(
        `   📈 ${elapsed}s: ${deviceData.heartRate} BPM → /devices/${REAL_DEVICE_ID}/current`
      );

      if (i < 24) {
        await sleep(2000); // 2 second intervals
      }
    }

    console.log(
      `\n✅ Sent 25 elevated readings over 50 seconds to device/current path`
    );

    // Step 5: Wait for Firebase Function processing
    console.log("\n⏳ Step 5: Waiting for Firebase Function to process...");
    console.log(
      "The realTimeSustainedAnxietyDetection function should trigger..."
    );
    await sleep(10000);

    // Step 6: Check for alerts
    console.log("\n🔔 Step 6: Checking for anxiety alerts...");
    const alertsSnapshot = await db
      .ref(`/users/${REAL_USER_ID}/alerts`)
      .once("value");
    const alerts = alertsSnapshot.val();

    if (alerts) {
      const alertKeys = Object.keys(alerts);
      console.log(`🎉 SUCCESS! Found ${alertKeys.length} anxiety alert(s):`);

      alertKeys.forEach((key, index) => {
        const alert = alerts[key];
        console.log(`   Alert ${index + 1}:`);
        console.log(`     Time: ${new Date(alert.timestamp).toLocaleString()}`);
        console.log(`     Reason: ${alert.reason}`);
        console.log(`     Severity: ${alert.severity}`);
        console.log(`     Device: ${alert.deviceId}`);
      });

      console.log(
        `\n🔔 If you received a notification, the complete system is working!`
      );
    } else {
      console.log("❌ No anxiety alerts found");
      console.log("\nLet's check the latest function logs...");
    }

    // Step 7: Show current device state
    console.log("\n📊 Step 7: Current device state...");
    const currentSnapshot = await db
      .ref(`/devices/${REAL_DEVICE_ID}/current`)
      .once("value");
    const currentData = currentSnapshot.val();

    if (currentData) {
      console.log(`✅ Latest device reading: ${currentData.heartRate} BPM`);
      console.log(
        `   Timestamp: ${new Date(currentData.timestamp).toLocaleString()}`
      );
      console.log(`   Battery: ${currentData.batteryLevel}%`);
    }
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Run the test
console.log("🚀 Starting corrected real-data-flow anxiety test...");
console.log("📱 Close your app and watch for notifications!");

testRealDataFlow();
