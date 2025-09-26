const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();
const messaging = admin.messaging();

async function testDirectNotification() {
  console.log("🔔 TESTING DIRECT NOTIFICATION...");
  console.log("═".repeat(40));

  try {
    // Get FCM token
    const deviceToken = await db
      .ref("/devices/AnxieEase001/fcmToken")
      .once("value");
    const fcmToken = deviceToken.val();
    console.log("📱 Using FCM token:", fcmToken.slice(-8));

    // Send test moderate anxiety notification
    const notificationConfig = {
      channelId: "moderate_anxiety_alerts",
      sound: "moderate_alert",
      priority: "high",
      androidPriority: "high",
    };

    const message = {
      token: fcmToken,
      notification: {
        title: "🟠 Moderate Anxiety Detected",
        body: "Your heart rate is elevated (95-105 BPM). Try some breathing exercises.",
      },
      android: {
        notification: {
          channelId: notificationConfig.channelId,
          sound: notificationConfig.sound,
          priority: notificationConfig.androidPriority,
        },
        priority: notificationConfig.priority,
      },
      data: {
        severity: "moderate",
        heartRate: "100",
        timestamp: Date.now().toString(),
        deviceId: "AnxieEase001",
      },
    };

    console.log("📤 Sending test notification...");
    const result = await messaging.send(message);
    console.log("✅ Notification sent successfully!");
    console.log("📱 Message ID:", result);
    console.log("");
    console.log("🔔 Check your phone now - you should receive:");
    console.log("   • Orange moderate anxiety alert");
    console.log("   • Custom moderate_alert.mp3 sound");
    console.log('   • "Try some breathing exercises" message');
  } catch (error) {
    console.error("❌ Error sending notification:", error);

    if (error.code === "messaging/invalid-registration-token") {
      console.log("💡 The FCM token might be invalid or expired");
      console.log("   Try restarting the app to get a fresh token");
    }
  }
}

testDirectNotification().catch(console.error);
