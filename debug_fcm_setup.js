/**
 * Debug FCM Setup Script
 * Checks if your device has proper FCM token and rate limiting status
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
  console.log("✅ Firebase Admin initialized\n");
}

const db = admin.database();

const TEST_DEVICE_ID = "AnxieEase001";
const TEST_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";

async function debugFCMSetup() {
  console.log("🔍 Debugging FCM Setup\n");
  console.log("=".repeat(60));

  // 1. Check device assignment
  console.log("\n1️⃣ Checking Device Assignment:");
  console.log("-".repeat(60));
  try {
    const assignmentSnapshot = await db
      .ref(`/devices/${TEST_DEVICE_ID}/assignment`)
      .once("value");

    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      console.log("✅ Assignment found:");
      console.log(`   Assigned User: ${assignment.assignedUser || "N/A"}`);
      console.log(
        `   FCM Token: ${assignment.fcmToken ? "✅ EXISTS" : "❌ MISSING"}`
      );
      if (assignment.fcmToken) {
        console.log(
          `   Token (first 20 chars): ${assignment.fcmToken.substring(
            0,
            20
          )}...`
        );
      }
      console.log(`   Status: ${assignment.status || "N/A"}`);
      console.log(`   Session ID: ${assignment.activeSessionId || "N/A"}`);
    } else {
      console.log("❌ No assignment found for device");
    }
  } catch (error) {
    console.error(`❌ Error checking assignment: ${error}`);
  }

  // 2. Check user-level FCM token
  console.log("\n2️⃣ Checking User-Level FCM Token:");
  console.log("-".repeat(60));
  try {
    const userTokenSnapshot = await db
      .ref(`/users/${TEST_USER_ID}/fcmToken`)
      .once("value");

    if (userTokenSnapshot.exists()) {
      const token = userTokenSnapshot.val();
      console.log("✅ User FCM token found:");
      console.log(`   Token (first 20 chars): ${token.substring(0, 20)}...`);
    } else {
      console.log("❌ No FCM token found at user level");
    }
  } catch (error) {
    console.error(`❌ Error checking user token: ${error}`);
  }

  // 3. Check device-level FCM token
  console.log("\n3️⃣ Checking Device-Level FCM Token:");
  console.log("-".repeat(60));
  try {
    const deviceTokenSnapshot = await db
      .ref(`/devices/${TEST_DEVICE_ID}/fcmToken`)
      .once("value");

    if (deviceTokenSnapshot.exists()) {
      const token = deviceTokenSnapshot.val();
      console.log("✅ Device FCM token found:");
      console.log(`   Token (first 20 chars): ${token.substring(0, 20)}...`);
    } else {
      console.log(
        "⚠️ No FCM token found at device level (this is okay if assignment has it)"
      );
    }
  } catch (error) {
    console.error(`❌ Error checking device token: ${error}`);
  }

  // 4. Check rate limiting status
  console.log("\n4️⃣ Checking Rate Limiting Status:");
  console.log("-".repeat(60));
  try {
    const rateLimitSnapshot = await db
      .ref(`/users/${TEST_USER_ID}/lastAnxietyNotification`)
      .once("value");

    if (rateLimitSnapshot.exists()) {
      const lastNotification = rateLimitSnapshot.val();
      const now = Date.now();
      const timeSinceLastNotification = now - lastNotification;
      const minutesAgo = Math.floor(timeSinceLastNotification / 1000 / 60);
      const secondsAgo = Math.floor(timeSinceLastNotification / 1000);

      const RATE_LIMIT_WINDOW_MS = 5 * 60 * 1000; // 5 minutes
      const isBlocked = timeSinceLastNotification < RATE_LIMIT_WINDOW_MS;

      if (isBlocked) {
        const remainingSeconds = Math.ceil(
          (RATE_LIMIT_WINDOW_MS - timeSinceLastNotification) / 1000
        );
        console.log("🚫 RATE LIMITED:");
        console.log(
          `   Last notification: ${minutesAgo}m ${secondsAgo % 60}s ago`
        );
        console.log(`   Time remaining: ${remainingSeconds}s`);
        console.log(`   Status: BLOCKED ❌`);
      } else {
        console.log("✅ Rate limit passed:");
        console.log(
          `   Last notification: ${minutesAgo}m ${secondsAgo % 60}s ago`
        );
        console.log(`   Status: READY TO SEND ✅`);
      }
    } else {
      console.log("✅ No rate limit found - first notification will be sent");
    }
  } catch (error) {
    console.error(`❌ Error checking rate limit: ${error}`);
  }

  // 5. Check recent alerts
  console.log("\n5️⃣ Checking Recent Alerts:");
  console.log("-".repeat(60));
  try {
    const alertsSnapshot = await db
      .ref(`/devices/${TEST_DEVICE_ID}/alerts`)
      .limitToLast(5)
      .once("value");

    if (alertsSnapshot.exists()) {
      const alerts = alertsSnapshot.val();
      const alertIds = Object.keys(alerts);
      console.log(`✅ Found ${alertIds.length} recent alerts:`);

      alertIds.forEach((alertId, index) => {
        const alert = alerts[alertId];
        const timestamp = new Date(alert.timestamp || 0).toLocaleString();
        console.log(`\n   Alert ${index + 1} (${alertId}):`);
        console.log(`   - Severity: ${alert.severity || "N/A"}`);
        console.log(`   - Heart Rate: ${alert.heartRate || "N/A"} BPM`);
        console.log(`   - Timestamp: ${timestamp}`);
        console.log(`   - Source: ${alert.source || "N/A"}`);
      });
    } else {
      console.log("⚠️ No alerts found");
    }
  } catch (error) {
    console.error(`❌ Error checking alerts: ${error}`);
  }

  // 6. Enhanced rate limiting check
  console.log("\n6️⃣ Checking Enhanced Rate Limiting:");
  console.log("-".repeat(60));
  try {
    const enhancedRateLimitSnapshot = await db
      .ref(`/rateLimits/${TEST_USER_ID}`)
      .once("value");

    if (enhancedRateLimitSnapshot.exists()) {
      const rateLimits = enhancedRateLimitSnapshot.val();
      console.log("✅ Enhanced rate limits found:");

      Object.keys(rateLimits).forEach((severity) => {
        const data = rateLimits[severity];
        const now = Date.now();
        const nextAllowed = data.nextAllowedTime || 0;
        const isBlocked = nextAllowed > now;
        const timeRemaining = isBlocked
          ? Math.ceil((nextAllowed - now) / 1000)
          : 0;

        console.log(`\n   ${severity.toUpperCase()}:`);
        console.log(`   - Last response: ${data.lastResponse || "N/A"}`);
        console.log(
          `   - Status: ${
            isBlocked ? `BLOCKED for ${timeRemaining}s` : "READY ✅"
          }`
        );
      });
    } else {
      console.log("✅ No enhanced rate limits - all severities ready");
    }
  } catch (error) {
    console.error(`❌ Error checking enhanced rate limits: ${error}`);
  }

  console.log("\n" + "=".repeat(60));
  console.log("\n💡 RECOMMENDATIONS:");
  console.log("-".repeat(60));

  // Check what's missing
  const assignmentSnapshot = await db
    .ref(`/devices/${TEST_DEVICE_ID}/assignment`)
    .once("value");
  const assignment = assignmentSnapshot.val();

  if (!assignment || !assignment.fcmToken) {
    console.log("❌ CRITICAL: No FCM token in device assignment");
    console.log(
      "   → Run the app and check logs for: '🔑 Fresh FCM registration token'"
    );
    console.log("   → The app should automatically store the token");
  } else {
    console.log("✅ FCM token is configured correctly");
  }

  const rateLimitSnapshot = await db
    .ref(`/users/${TEST_USER_ID}/lastAnxietyNotification`)
    .once("value");
  if (rateLimitSnapshot.exists()) {
    const lastNotification = rateLimitSnapshot.val();
    const timeSince = Date.now() - lastNotification;
    if (timeSince < 5 * 60 * 1000) {
      console.log("⚠️ WARNING: Rate limit is active");
      console.log("   → Wait a few minutes before testing again");
      console.log("   → OR manually clear with: node clear_rate_limit.js");
    } else {
      console.log("✅ Rate limit window has passed");
    }
  }

  console.log("\n");
  process.exit(0);
}

debugFCMSetup().catch((error) => {
  console.error("\n❌ Debug failed:", error);
  process.exit(1);
});
