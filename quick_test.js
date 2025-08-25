const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function quickNotificationTest() {
  console.log("🚀 QUICK BACKGROUND NOTIFICATION TEST");
  console.log("📱 Make sure AnxieEase app is COMPLETELY CLOSED!");
  console.log("⏳ Sending test notification in 5 seconds...\n");

  await new Promise((resolve) => setTimeout(resolve, 5000));

  try {
    const message = {
      notification: {
        title: "🔔 Background Test SUCCESS!",
        body: "If you see this, background notifications are working!",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          sound: "default",
        },
      },
      topic: "anxiety_alerts",
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Test notification sent:", response);
    console.log(
      "📱 Check your device now! If you see the notification, your system is working!"
    );
  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

quickNotificationTest();
