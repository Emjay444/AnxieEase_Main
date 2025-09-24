/**
 * 🔍 CHECK ALL USER DATA
 *
 * This script checks what data exists in Firebase for our user
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

async function checkAllUserData() {
  console.log("\n🔍 CHECKING ALL DATA FOR USER");
  console.log("=============================");
  console.log(`User ID: ${REAL_USER_ID}`);

  try {
    // Check everything under /users/{userId}
    console.log("\n📂 Checking /users/{userId}...");
    const userDataSnapshot = await db
      .ref(`/users/${REAL_USER_ID}`)
      .once("value");
    const userData = userDataSnapshot.val();

    if (userData) {
      console.log("✅ User data exists:");

      // Check baseline
      if (userData.baseline) {
        console.log(`   📊 Baseline: ${userData.baseline.heartRate} BPM`);
      } else {
        console.log("   ❌ No baseline found");
      }

      // Check FCM token
      if (userData.fcmToken) {
        console.log(
          `   📱 FCM Token: ${userData.fcmToken.substring(0, 20)}...`
        );
      } else {
        console.log("   ❌ No FCM token found");
      }

      // Check sessions
      if (userData.sessions) {
        const sessionKeys = Object.keys(userData.sessions);
        console.log(`   📋 Sessions: ${sessionKeys.length} found`);

        sessionKeys.forEach((sessionKey) => {
          const session = userData.sessions[sessionKey];
          console.log(`     Session ${sessionKey}:`);
          console.log(
            `       Status: ${session.metadata?.status || "unknown"}`
          );
          console.log(
            `       Device: ${session.metadata?.deviceId || "unknown"}`
          );

          if (session.data) {
            const dataCount = Object.keys(session.data).length;
            console.log(`       Data points: ${dataCount}`);
          } else {
            console.log(`       Data points: 0`);
          }
        });
      } else {
        console.log("   ❌ No sessions found");
      }

      // Check alerts
      if (userData.alerts) {
        const alertKeys = Object.keys(userData.alerts);
        console.log(`   🚨 Alerts: ${alertKeys.length} found`);
      } else {
        console.log("   ❌ No alerts found");
      }
    } else {
      console.log("❌ No data found for this user");
    }

    // Check device assignment
    console.log("\n📟 Checking device assignment...");
    const deviceSnapshot = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const assignment = deviceSnapshot.val();

    if (assignment) {
      console.log("✅ Device assignment found:");
      console.log(`   User: ${assignment.userId}`);
      console.log(`   Session: ${assignment.sessionId}`);
      console.log(`   Status: ${assignment.status}`);
      console.log(
        `   Match: ${assignment.userId === REAL_USER_ID ? "✅" : "❌"}`
      );
    } else {
      console.log("❌ No device assignment found");
    }

    // Check if there's data under the assigned session
    if (assignment && assignment.sessionId) {
      console.log(
        `\n📊 Checking specific session data: ${assignment.sessionId}`
      );
      const sessionDataSnapshot = await db
        .ref(`/users/${REAL_USER_ID}/sessions/${assignment.sessionId}`)
        .once("value");
      const sessionData = sessionDataSnapshot.val();

      if (sessionData) {
        console.log("✅ Session data exists:");
        console.log(`   Metadata: ${sessionData.metadata ? "✅" : "❌"}`);
        console.log(
          `   Data: ${
            sessionData.data
              ? Object.keys(sessionData.data).length + " points"
              : "❌ No data"
          }`
        );
      } else {
        console.log("❌ No data found for assigned session");
      }
    }
  } catch (error) {
    console.error("❌ Check failed:", error.message);
  }
}

checkAllUserData();
