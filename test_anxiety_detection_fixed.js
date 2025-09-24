/**
 * 🎯 FIXED REAL USER ANXIETY DETECTION TEST
 *
 * This is an improved version with better error handling and verification
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

async function testAnxietyDetectionFixed() {
  console.log("\n🎯 FIXED REAL USER ANXIETY DETECTION TEST");
  console.log("========================================");

  try {
    // Step 1: Get device assignment and session ID
    console.log("\n🔍 Step 1: Getting device assignment...");
    const assignmentSnapshot = await db
      .ref(`/devices/${REAL_DEVICE_ID}/assignment`)
      .once("value");
    const assignment = assignmentSnapshot.val();

    if (!assignment || assignment.userId !== REAL_USER_ID) {
      throw new Error(`Device not assigned to user ${REAL_USER_ID}`);
    }

    const sessionId = assignment.sessionId;
    console.log(`✅ Session ID: ${sessionId}`);

    // Step 2: Setup user profile
    console.log("\n💓 Step 2: Setting up user profile...");

    // Set baseline
    await db.ref(`/users/${REAL_USER_ID}/baseline`).set({
      heartRate: 70,
      timestamp: Date.now(),
      source: "test_setup",
    });

    // Set FCM token
    await db.ref(`/users/${REAL_USER_ID}/fcmToken`).set(USER_FCM_TOKEN);

    console.log("✅ User baseline: 70 BPM (threshold: 84 BPM)");
    console.log("✅ FCM token stored");

    // Step 3: Clear any existing alerts
    console.log("\n🧹 Step 3: Clearing previous alerts...");
    await db.ref(`/users/${REAL_USER_ID}/alerts`).remove();
    console.log("✅ Previous alerts cleared");

    // Step 4: Send sustained elevated heart rate data
    console.log("\n🚨 Step 4: Sending sustained anxiety data...");
    console.log("This will take 45 seconds - sustained elevation above 84 BPM");
    console.log("🔔 WATCH YOUR PHONE FOR NOTIFICATIONS!");

    const dataPoints = [];

    // Send 22 data points over 44 seconds (2-second intervals)
    for (let i = 0; i < 22; i++) {
      const heartRate = 85 + Math.random() * 10; // 85-95 BPM (well above 84 threshold)
      const timestamp = Date.now();

      const testData = {
        heartRate: Math.round(heartRate * 10) / 10,
        timestamp: timestamp,
        deviceId: REAL_DEVICE_ID,
        source: "sustained_anxiety_test",
      };

      // Write to Firebase
      const dataRef = db
        .ref(`/users/${REAL_USER_ID}/sessions/${sessionId}/data`)
        .push();
      await dataRef.set(testData);

      dataPoints.push(testData);

      const elapsed = (i + 1) * 2;
      console.log(
        `   📈 ${elapsed}s: ${testData.heartRate} BPM (${
          testData.heartRate >= 84 ? "ELEVATED" : "normal"
        })`
      );

      if (i < 21) {
        // Don't wait after the last one
        await sleep(2000); // 2 second intervals
      }
    }

    console.log(
      `\n✅ Sent ${dataPoints.length} elevated heart rate readings over 44 seconds`
    );

    // Step 5: Wait for Firebase Functions to process
    console.log("\n⏳ Step 5: Waiting for anxiety detection processing...");
    console.log("Waiting 10 seconds for Firebase Cloud Functions...");
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
        `\n🔔 If you received a notification, the system is working perfectly!`
      );
    } else {
      console.log("❌ No anxiety alerts found");
      console.log("\nPossible issues:");
      console.log("1. Firebase Cloud Functions not deployed");
      console.log("2. Functions not triggered by database writes");
      console.log("3. Error in anxiety detection logic");

      // Check if we can at least verify the data was stored
      console.log("\n📊 Verifying heart rate data was stored...");
      const dataSnapshot = await db
        .ref(`/users/${REAL_USER_ID}/sessions/${sessionId}/data`)
        .once("value");
      const storedData = dataSnapshot.val();

      if (storedData) {
        const storedCount = Object.keys(storedData).length;
        console.log(`✅ ${storedCount} heart rate readings stored in Firebase`);
      } else {
        console.log("❌ No heart rate data found in Firebase");
      }
    }
  } catch (error) {
    console.error("❌ Test failed:", error.message);
    console.error("Stack:", error.stack);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Run the test
console.log("🚀 Starting improved anxiety detection test...");
console.log("📱 Close your app and watch for notifications!");

testAnxietyDetectionFixed();
