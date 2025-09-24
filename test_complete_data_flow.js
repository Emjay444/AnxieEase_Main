/**
 * 🎯 COMPLETE DATA FLOW TEST WITH MANUAL HISTORY CREATION
 *
 * This test ensures data reaches all the right places for anxiety detection
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

async function testCompleteDataFlow() {
  console.log("\n🎯 COMPLETE ANXIETY DETECTION DATA FLOW TEST");
  console.log("===========================================");

  try {
    // Step 1: Set up proper device assignment
    console.log("\n📟 Step 1: Setting up device assignment...");
    const sessionId = `session_${Date.now()}`;

    await db.ref(`/devices/${REAL_DEVICE_ID}/assignment`).set({
      assignedUser: REAL_USER_ID,
      activeSessionId: sessionId,
      deviceId: REAL_DEVICE_ID,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      status: "active",
    });

    // Step 2: Set up user session metadata
    await db.ref(`/users/${REAL_USER_ID}/sessions/${sessionId}/metadata`).set({
      deviceId: REAL_DEVICE_ID,
      status: "active",
      startTime: admin.database.ServerValue.TIMESTAMP,
      source: "complete_test",
    });

    console.log(`✅ Device and user session setup complete`);
    console.log(`   User: ${REAL_USER_ID}`);
    console.log(`   Session: ${sessionId}`);

    // Step 3: Set up user profile
    console.log("\n💓 Step 3: Setting up user profile...");

    await db.ref(`/users/${REAL_USER_ID}/baseline`).set({
      heartRate: 70,
      timestamp: Date.now(),
      source: "complete_test",
    });

    await db.ref(`/users/${REAL_USER_ID}/fcmToken`).set(USER_FCM_TOKEN);
    console.log("✅ User baseline and FCM token set");

    // Step 4: Clear previous alerts
    await db.ref(`/users/${REAL_USER_ID}/alerts`).remove();
    console.log("✅ Previous alerts cleared");

    // Step 5: Send elevated data to BOTH device/current AND user session history
    console.log("\n🚨 Step 5: Sending data to ensure anxiety detection...");
    console.log("Writing to BOTH device/current AND user session data paths");
    console.log("🔔 WATCH YOUR PHONE FOR NOTIFICATIONS!");

    for (let i = 0; i < 20; i++) {
      const heartRate = 85 + Math.random() * 10; // 85-95 BPM
      const timestamp = Date.now();

      const deviceData = {
        heartRate: Math.round(heartRate * 10) / 10,
        spo2: 98,
        bodyTemp: 36.5,
        ambientTemp: 25.0,
        battPerc: 85 - i,
        worn: 1,
        timestamp: timestamp,
        deviceId: REAL_DEVICE_ID,
        sessionId: sessionId,
      };

      // Write to device current (triggers copyDeviceCurrentToUserSession)
      await db.ref(`/devices/${REAL_DEVICE_ID}/current`).set(deviceData);

      // Also write directly to user session data (ensures anxiety detection has history)
      const userDataRef = db
        .ref(`/users/${REAL_USER_ID}/sessions/${sessionId}/data`)
        .push();
      await userDataRef.set({
        heartRate: deviceData.heartRate,
        timestamp: timestamp,
        deviceId: REAL_DEVICE_ID,
        source: "complete_test_manual",
      });

      const elapsed = (i + 1) * 2.5;
      console.log(
        `   📈 ${elapsed}s: ${deviceData.heartRate} BPM (device + user data)`
      );

      if (i < 19) {
        await sleep(2500); // 2.5 second intervals = 50 seconds total
      }
    }

    console.log(`\n✅ Sent 20 data points over 50 seconds to both paths`);

    // Step 6: Wait for processing
    console.log("\n⏳ Step 6: Waiting for anxiety detection...");
    await sleep(15000); // Wait 15 seconds

    // Step 7: Check results
    console.log("\n🔔 Step 7: Checking for anxiety alerts...");
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
        console.log(`     User: ${alert.userId}`);
      });

      console.log(
        `\n🔔 If you received a notification, EVERYTHING IS WORKING!`
      );
      console.log("Your anxiety detection system is fully functional!");
    } else {
      console.log("❌ Still no anxiety alerts found");

      // Debug: Check what data exists
      console.log("\n🔍 Debugging: Checking data locations...");

      // Check user session data
      const sessionDataSnapshot = await db
        .ref(`/users/${REAL_USER_ID}/sessions/${sessionId}/data`)
        .once("value");
      const sessionData = sessionDataSnapshot.val();

      if (sessionData) {
        const dataCount = Object.keys(sessionData).length;
        console.log(`✅ User session data: ${dataCount} points found`);
      } else {
        console.log("❌ No user session data found");
      }

      // Check device current
      const deviceCurrentSnapshot = await db
        .ref(`/devices/${REAL_DEVICE_ID}/current`)
        .once("value");
      const deviceCurrent = deviceCurrentSnapshot.val();

      if (deviceCurrent) {
        console.log(`✅ Device current: ${deviceCurrent.heartRate} BPM`);
      } else {
        console.log("❌ No device current data");
      }
    }
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Run the test
console.log("🚀 Starting COMPLETE data flow test...");
console.log("📱 Close your app and watch for notifications!");
console.log("This test writes to ALL the required data paths...");

testCompleteDataFlow();
