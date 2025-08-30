const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testDirectFCMToken() {
  try {
    console.log("🎯 Testing Direct FCM Token Delivery...");
    console.log("📱 CLOSE YOUR APP COMPLETELY and wait for notification!");
    console.log("⏳ Starting test in 5 seconds...\n");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Use the FCM token from your app logs
    const fcmToken =
      "cVkrxye5SmOUCy52tLe0fz:APA91bEErAmLuDi91mluTyG6PKjRjEvUhNV59p56kGb3AB1slFl-eUjZuntXIqiM7YohpsOmrp0WKQMU0FIC6-R2BoI7ZV5wFpFltQcGOZcIHATKzsuQ5-w";

    const message = {
      notification: {
        title: "🧪 Direct FCM Test",
        body: "This is a direct FCM token test. If you see this, FCM works!",
      },
      data: {
        type: "test",
        timestamp: Date.now().toString(),
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
      token: fcmToken, // Send directly to your device token
    };

    console.log("📤 Sending direct FCM message to your device token...");
    const response = await admin.messaging().send(message);
    console.log("✅ FCM message sent successfully:", response);
    console.log(
      "\n📱 Check your device now! You should see a notification even with app closed."
    );
    console.log(
      "❌ If no notification appears, there's a device/FCM delivery issue."
    );
  } catch (error) {
    console.error("❌ FCM test failed:", error);
    if (error.code === "messaging/registration-token-not-registered") {
      console.log(
        "🔄 Token is invalid or expired. Restart your app to get a new token."
      );
    }
  }
}

testDirectFCMToken();

