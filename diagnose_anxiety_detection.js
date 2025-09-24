/**
 * 🔍 DIAGNOSE ANXIETY DETECTION ISSUE
 *
 * This script checks what happened during the test:
 * 1. Did the heart rate data get stored?
 * 2. Were any alerts generated?
 * 3. Are Firebase Functions running?
 * 4. Is the FCM token valid?
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

async function diagnoseAnxietyDetection() {
  console.log("\n🔍 DIAGNOSING ANXIETY DETECTION ISSUE");
  console.log("====================================");

  try {
    // Check if heart rate data was stored
    console.log("\n📊 Step 1: Checking stored heart rate data...");
    const userSessionsSnapshot = await db
      .ref(`/users/${REAL_USER_ID}/sessions`)
      .once("value");
    const sessions = userSessionsSnapshot.val();

    if (!sessions) {
      console.log("❌ No sessions found for user");
      return;
    }

    const sessionKeys = Object.keys(sessions);
    console.log(`✅ Found ${sessionKeys.length} session(s)`);

    // Check the latest session
    const latestSessionKey = sessionKeys[sessionKeys.length - 1];
    const latestSession = sessions[latestSessionKey];

    console.log(`\n📋 Latest Session: ${latestSessionKey}`);
    console.log(`   Device: ${latestSession.metadata?.deviceId}`);
    console.log(`   Status: ${latestSession.metadata?.status}`);

    // Check heart rate data in the latest session
    if (latestSession.data) {
      const dataPoints = Object.values(latestSession.data);
      console.log(`   Data points: ${dataPoints.length}`);

      if (dataPoints.length > 0) {
        // Show some recent heart rate readings
        const recentData = dataPoints.slice(-10);
        console.log(`\n📈 Last 10 heart rate readings:`);
        recentData.forEach((point, index) => {
          const time = new Date(point.timestamp).toLocaleTimeString();
          console.log(`     ${time}: ${point.heartRate} BPM`);
        });

        // Check if any readings were above threshold (84 BPM)
        const elevatedReadings = dataPoints.filter((p) => p.heartRate >= 84);
        console.log(
          `\n⚡ Elevated readings (≥84 BPM): ${elevatedReadings.length}/${dataPoints.length}`
        );
      }
    } else {
      console.log("❌ No heart rate data found in latest session");
    }

    // Check if any alerts were generated
    console.log("\n🚨 Step 2: Checking for anxiety alerts...");
    const alertsSnapshot = await db
      .ref(`/users/${REAL_USER_ID}/alerts`)
      .once("value");
    const alerts = alertsSnapshot.val();

    if (alerts) {
      const alertKeys = Object.keys(alerts);
      console.log(`✅ Found ${alertKeys.length} alert(s):`);

      alertKeys.forEach((key, index) => {
        const alert = alerts[key];
        const time = new Date(alert.timestamp).toLocaleString();
        console.log(`   Alert ${index + 1}:`);
        console.log(`     Time: ${time}`);
        console.log(`     Reason: ${alert.reason}`);
        console.log(`     Severity: ${alert.severity}`);
      });
    } else {
      console.log("❌ No anxiety alerts found");
      console.log(
        "   This suggests the Firebase Cloud Function didn't trigger"
      );
    }

    // Check user baseline
    console.log("\n💓 Step 3: Checking user baseline...");
    const baselineSnapshot = await db
      .ref(`/users/${REAL_USER_ID}/baseline`)
      .once("value");
    const baseline = baselineSnapshot.val();

    if (baseline) {
      console.log(`✅ User baseline: ${baseline.heartRate} BPM`);
      console.log(
        `   Anxiety threshold: ${Math.round(baseline.heartRate * 1.2)} BPM`
      );
    } else {
      console.log("❌ No baseline found for user");
    }

    // Check FCM token
    console.log("\n📱 Step 4: Checking FCM token...");
    const fcmTokenSnapshot = await db
      .ref(`/users/${REAL_USER_ID}/fcmToken`)
      .once("value");
    const fcmToken = fcmTokenSnapshot.val();

    if (fcmToken) {
      console.log(`✅ FCM token stored: ${fcmToken.substring(0, 20)}...`);
    } else {
      console.log("❌ No FCM token found for user");
    }

    // Check device assignment
    console.log("\n📟 Step 5: Checking device assignment...");
    const deviceAssignmentSnapshot = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const assignment = deviceAssignmentSnapshot.val();

    if (assignment && assignment.userId === REAL_USER_ID) {
      console.log(`✅ Device properly assigned to user`);
      console.log(`   Session: ${assignment.sessionId}`);
    } else {
      console.log("❌ Device assignment issue");
    }

    console.log("\n🎯 DIAGNOSIS SUMMARY");
    console.log("===================");

    if (!sessions) {
      console.log("❌ ISSUE: No user sessions found - data not being stored");
    } else if (!alerts) {
      console.log(
        "⚠️ LIKELY ISSUE: Firebase Cloud Functions not processing the data"
      );
      console.log("   Possible causes:");
      console.log("   1. Cloud Functions not deployed");
      console.log("   2. Functions not triggered by database writes");
      console.log("   3. Error in anxiety detection logic");
      console.log("   4. Insufficient sustained duration");
    } else {
      console.log("✅ System working - alerts were generated");
    }
  } catch (error) {
    console.error("❌ Diagnosis failed:", error.message);
  }
}

diagnoseAnxietyDetection();
