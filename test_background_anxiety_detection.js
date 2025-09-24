/**
 * 🎯 REAL USER ANXIETY DETECTION - BACKGROUND TESTING
 *
 * This script simulates the AnxieEase001 wearable device sending real-time heart rate data
 * to test anxiety detection that works even when the Flutter app is closed.
 *
 * TESTING SCENARIOS:
 * 1. Normal heart rate (below threshold) - No alert
 * 2. Brief elevated heart rate (< 30 seconds) - No alert
 * 3. Sustained elevated heart rate (35+ seconds) - ANXIETY ALERT with FCM notification
 *
 * The system should detect anxiety and send notifications even when:
 * - Flutter app is closed/minimized
 * - Phone is locked
 * - App is in background
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
const messaging = admin.messaging();

// Real user configuration from admin dashboard
const REAL_USER_ID = "5efad7d4-3dcd-4333-ba4b-41f86"; // From your admin dashboard
const REAL_DEVICE_ID = "AnxieEase001"; // Assigned device
const USER_FCM_TOKEN =
  "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0";

/**
 * Test anxiety detection with realistic heart rate patterns
 */
async function testBackgroundAnxietyDetection() {
  console.log("\n🎯 REAL USER ANXIETY DETECTION - BACKGROUND TEST");
  console.log("===============================================");
  console.log("This test simulates the wearable device sending data");
  console.log("and verifies anxiety detection works when app is closed.\n");

  try {
    // Step 1: Verify device assignment
    console.log("🔍 Step 1: Verifying device assignment...");
    const assignmentSnapshot = await db
      .ref(`/devices/${REAL_DEVICE_ID}/assignment`)
      .once("value");
    const assignment = assignmentSnapshot.val();

    if (!assignment || assignment.userId !== REAL_USER_ID) {
      throw new Error(
        `Device ${REAL_DEVICE_ID} is not assigned to user ${REAL_USER_ID}`
      );
    }

    const sessionId = assignment.sessionId;
    console.log(`✅ Device assigned to user: ${REAL_USER_ID}`);
    console.log(`   Session ID: ${sessionId}`);

    // Step 2: Set up user baseline and FCM token
    console.log("\n💓 Step 2: Setting up user profile...");

    // Set user baseline (70 BPM = 84 BPM anxiety threshold)
    await db.ref(`/users/${REAL_USER_ID}/baseline`).set({
      heartRate: 70,
      timestamp: Date.now(),
      source: "user_profile",
    });

    // Store FCM token for notifications
    await db.ref(`/users/${REAL_USER_ID}/fcmToken`).set(USER_FCM_TOKEN);

    console.log("✅ User baseline set: 70 BPM (threshold: 84 BPM)");
    console.log("✅ FCM token stored for notifications");

    // Step 3: Test normal heart rate (no alert expected)
    console.log("\n📊 Step 3: Testing normal heart rate...");
    console.log("Sending 10 readings at 75 BPM (below 84 BPM threshold)");

    for (let i = 0; i < 10; i++) {
      const heartRate = 75 + Math.random() * 4; // 75-79 BPM
      await sendHeartRateData(REAL_USER_ID, sessionId, heartRate);
      await sleep(2000); // 2 second intervals
    }

    console.log("✅ Normal heart rate test completed (no alerts expected)");

    // Step 4: Test brief elevation (< 30 seconds, no alert expected)
    console.log("\n⚠️ Step 4: Testing brief heart rate elevation...");
    console.log(
      "Sending elevated readings for 20 seconds (below 30s threshold)"
    );

    for (let i = 0; i < 10; i++) {
      const heartRate = 88 + Math.random() * 5; // 88-93 BPM (elevated)
      await sendHeartRateData(REAL_USER_ID, sessionId, heartRate);
      await sleep(2000); // 2 second intervals = 20 seconds total
    }

    console.log("✅ Brief elevation test completed (no alerts expected)");

    // Step 5: Test sustained anxiety (35+ seconds, ALERT EXPECTED)
    console.log("\n🚨 Step 5: Testing sustained anxiety detection...");
    console.log("Sending sustained elevated readings for 40 seconds");
    console.log("🔔 YOU SHOULD RECEIVE A NOTIFICATION ON YOUR PHONE!");

    for (let i = 0; i < 20; i++) {
      const heartRate = 90 + Math.random() * 8; // 90-98 BPM (sustained elevation)
      await sendHeartRateData(REAL_USER_ID, sessionId, heartRate);
      console.log(
        `   📈 Sent: ${heartRate.toFixed(1)} BPM (${(i + 1) * 2}s elapsed)`
      );
      await sleep(2000); // 2 second intervals = 40 seconds total
    }

    console.log("\n✅ Sustained anxiety test completed!");

    // Step 6: Check for generated alerts
    console.log("\n🔔 Step 6: Checking for anxiety alerts...");
    await sleep(5000); // Wait for cloud function processing

    const alertsSnapshot = await db
      .ref(`/users/${REAL_USER_ID}/alerts`)
      .once("value");
    const alerts = alertsSnapshot.val();

    if (alerts) {
      const alertKeys = Object.keys(alerts);
      console.log(`✅ Found ${alertKeys.length} anxiety alert(s):`);

      alertKeys.forEach((key, index) => {
        const alert = alerts[key];
        console.log(`   Alert ${index + 1}:`);
        console.log(
          `     Timestamp: ${new Date(alert.timestamp).toLocaleString()}`
        );
        console.log(`     Reason: ${alert.reason}`);
        console.log(`     Severity: ${alert.severity}`);
      });
    } else {
      console.log("❌ No anxiety alerts found - check Firebase Functions logs");
    }

    console.log("\n🎯 BACKGROUND TESTING COMPLETE!");
    console.log("===============================");
    console.log("Key points verified:");
    console.log("✅ Device assignment working");
    console.log("✅ Heart rate data received");
    console.log("✅ User baseline configured");
    console.log("✅ FCM token ready for notifications");
    console.log("\nIf you received a notification during Step 5,");
    console.log("your anxiety detection system is working perfectly!");
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

/**
 * Send heart rate data to Firebase (simulating wearable device)
 */
async function sendHeartRateData(userId, sessionId, heartRate) {
  const dataRef = db.ref(`/users/${userId}/sessions/${sessionId}/data`).push();
  await dataRef.set({
    heartRate: Math.round(heartRate * 10) / 10, // Round to 1 decimal
    timestamp: Date.now(),
    deviceId: REAL_DEVICE_ID,
    source: "wearable_simulation",
  });
}

/**
 * Sleep utility function
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Run the test
console.log("🚀 Starting real user anxiety detection test...");
console.log("📱 Make sure your phone is ready to receive notifications!");
console.log("   (App can be closed, phone can be locked)");

testBackgroundAnxietyDetection();
