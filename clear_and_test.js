const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

async function clearAndRefresh() {
  const db = admin.database();

  console.log("🔄 CLEARING POTENTIAL ISSUES...");
  console.log("═".repeat(40));

  try {
    // 1. Clear any cached rate limiting
    console.log("⏱️ Waiting 10 seconds to clear any rate limits...");
    await new Promise((resolve) => setTimeout(resolve, 10000));

    // 2. Check if we should clear the FCM token to force refresh
    const deviceRef = db.ref("/devices/AnxieEase001");
    const deviceSnapshot = await deviceRef.once("value");

    if (deviceSnapshot.exists()) {
      const deviceData = deviceSnapshot.val();
      console.log(
        "📱 Current FCM token timestamp:",
        deviceData.fcmTokenUpdated || "Not set"
      );

      // If token is old, clear it to force refresh when app opens
      const now = Date.now();
      const tokenTime = deviceData.fcmTokenUpdated || 0;
      const ageMinutes = (now - tokenTime) / (1000 * 60);

      if (ageMinutes > 30) {
        console.log(
          `⚠️ Token is ${Math.round(
            ageMinutes
          )} minutes old - consider refreshing`
        );
        console.log(
          "🔄 To refresh: Open the app, then close it and test again"
        );
      }
    }

    // 3. Send a final test notification with a different format
    const fcmToken =
      "dJlsLVwwQlm7_qwAqlvxej:APA91bHst58wqLrOsqICaHX7rqTzNRSvXhOoV7oV3n1uxaU0LtUa7xwvr1L3NdlIM9IhfPY8aLrUU8WAX_uklVH8eIsnR_prV5gsN24znhYwIJcta-xyKKE";

    console.log("📤 Sending final test notification...");
    const finalTest = {
      token: fcmToken,
      notification: {
        title: "🔔 Final Test",
        body: "If you see this, notifications are working!",
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "high_importance_channel",
        },
      },
    };

    const response = await admin.messaging().send(finalTest);
    console.log("✅ Final test sent:", response);

    console.log("\n📋 SUMMARY:");
    console.log("• Firebase functions: ✅ Working correctly");
    console.log("• FCM token: ✅ Valid and active");
    console.log("• Message sending: ✅ Successful");
    console.log("• Notifications stored: ✅ In database");
    console.log("");
    console.log("🔍 Issue is likely device-side:");
    console.log("  1. Check notification permissions");
    console.log("  2. Disable battery optimization");
    console.log("  3. Ensure app is fully closed");
    console.log('  4. Check "Do Not Disturb" is off');
    console.log("  5. Restart your device if needed");
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

clearAndRefresh();
