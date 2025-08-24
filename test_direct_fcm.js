const admin = require("firebase-admin");

// Initialize Firebase Admin with your service account key
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function sendDirectFCM() {
  try {
    // Your device token from the logs
    const deviceToken =
      "cVkrxye5SmOUCy52tLe0fz:APA91bEErAmLuDi91mluTyG6PKjRjEvUhNV59p56kGb3AB1slFl-eUjZuntXIqiM7YohpsOmrp0WKQMU0FIC6-R2BoI7ZV5wFpFltQcGOZcIHATKzsuQ5-w";

    console.log("🔔 Sending direct FCM notification to device...");

    const message = {
      token: deviceToken,
      data: {
        type: "anxiety_alert",
        severity: "severe",
        heartRate: "95",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🔴 [DIRECT] Severe Alert",
        body: "URGENT: High risk detected! HR: 95 bpm",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Direct FCM notification sent successfully:", response);

    process.exit(0);
  } catch (error) {
    console.error("❌ Error sending direct FCM notification:", error);
    process.exit(1);
  }
}

sendDirectFCM();
