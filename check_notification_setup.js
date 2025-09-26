const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function checkNotificationSetup() {
  console.log("🔍 CHECKING NOTIFICATION SETUP...");
  console.log("═".repeat(50));

  try {
    // Check device assignment
    console.log("📱 Checking device assignment...");
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    if (assignment.exists()) {
      const assignmentData = assignment.val();
      console.log("✅ Device assignment found:");
      console.log(
        "   User ID:",
        assignmentData.assignedUser || assignmentData.userId || "N/A"
      );
      console.log(
        "   Session ID:",
        assignmentData.activeSessionId || assignmentData.sessionId || "N/A"
      );
      console.log(
        "   Assignment time:",
        new Date(
          assignmentData.assignmentTimestamp || assignmentData.timestamp || 0
        ).toLocaleString()
      );
    } else {
      console.log(
        "❌ Device assignment NOT FOUND - this will prevent notifications!"
      );
      console.log(
        "   Run: node quick_assign_device.js to assign device to user"
      );
      return;
    }

    // Check FCM tokens
    console.log("\n🔑 Checking FCM tokens...");
    const deviceToken = await db
      .ref("/devices/AnxieEase001/fcmToken")
      .once("value");
    if (deviceToken.exists()) {
      console.log(
        "✅ Device FCM token exists:",
        "..." + deviceToken.val().slice(-8)
      );
    } else {
      console.log("❌ Device FCM token NOT FOUND");
    }

    // Check user FCM token if device is assigned
    const assignmentData = assignment.val();
    const userId = assignmentData.assignedUser || assignmentData.userId;
    if (userId) {
      const userToken = await db.ref(`/users/${userId}/fcmToken`).once("value");
      if (userToken.exists()) {
        console.log(
          "✅ User FCM token exists:",
          "..." + userToken.val().slice(-8)
        );
      } else {
        console.log("❌ User FCM token NOT FOUND");
      }
    }

    // Check rate limiting
    console.log("\n⏱️  Checking rate limiting...");
    const rateLimitRef = db.ref("/rate_limits/AnxieEase001");
    const rateLimit = await rateLimitRef.once("value");
    if (rateLimit.exists()) {
      const data = rateLimit.val();
      const now = Date.now();
      const lastNotification = data.lastNotificationTimestamp || 0;
      const timeSince = (now - lastNotification) / 1000;
      console.log(
        "Last notification:",
        new Date(lastNotification).toLocaleString()
      );
      console.log("Time since last:", timeSince.toFixed(1) + " seconds ago");
      console.log(
        "Rate limit active:",
        data.isRateLimited ? "🔴 YES - THIS BLOCKS NOTIFICATIONS" : "🟢 NO"
      );
      console.log(
        "Confirmation required:",
        data.confirmationRequired ? "🟡 YES" : "🟢 NO"
      );

      if (data.isRateLimited) {
        console.log("🚫 RATE LIMITING IS BLOCKING NOTIFICATIONS!");
        console.log("   Wait for rate limit to expire or reset it manually");
      }
    } else {
      console.log("✅ No rate limiting found - notifications should work");
    }

    // Check recent baseline data
    console.log("\n📊 Checking baseline data...");
    if (userId) {
      const baselineRef = db.ref(`/users/${userId}/baseline`);
      const baseline = await baselineRef.once("value");
      if (baseline.exists()) {
        const baselineData = baseline.val();
        console.log("✅ User baseline found:");
        console.log("   Resting HR:", baselineData.restingHeartRate || "N/A");
        console.log(
          "   Last updated:",
          new Date(baselineData.lastUpdated || 0).toLocaleString()
        );
      } else {
        console.log(
          "❌ User baseline NOT FOUND - anxiety detection may not work properly"
        );
      }
    }

    // Check recent current data
    console.log("\n📱 Recent device data:");
    const current = await db.ref("/devices/AnxieEase001/current").once("value");
    if (current.exists()) {
      const data = current.val();
      console.log("✅ Latest data:");
      console.log("   HR:", data.heartRate + " BPM");
      console.log("   Timestamp:", new Date(data.timestamp).toLocaleString());
      console.log(
        "   Time ago:",
        Math.round((Date.now() - data.timestamp) / 1000) + " seconds"
      );
    } else {
      console.log("❌ No current data found");
    }

    // Check function logs (recent alerts)
    console.log("\n🚨 Checking recent alerts...");
    if (userId) {
      const alertsRef = db.ref(`/devices/AnxieEase001/alerts`);
      const alerts = await alertsRef.limitToLast(3).once("value");
      if (alerts.exists()) {
        console.log("✅ Recent alerts found:");
        alerts.forEach((alert) => {
          const alertData = alert.val();
          console.log(
            `   - ${alertData.severity} alert at ${new Date(
              alertData.timestamp
            ).toLocaleString()}`
          );
        });
      } else {
        console.log("❌ No recent alerts found");
      }
    }
  } catch (error) {
    console.error("❌ Error checking setup:", error);
  }

  process.exit(0);
}

checkNotificationSetup();
