const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function sendTestMessage() {
  try {
    console.log("🔔 Sending test message to anxiety_alerts topic...");

    const message = {
      topic: "anxiety_alerts",
      notification: {
        title: "Test Notification",
        body: "This is a test message to verify FCM is working.",
      },
      data: {
        type: "test",
        timestamp: Date.now().toString(),
      },
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Test message sent successfully:", response);
    console.log("📱 Check your device for the notification!");
  } catch (error) {
    console.error("❌ Error sending test message:", error);
  }
}

sendTestMessage();
