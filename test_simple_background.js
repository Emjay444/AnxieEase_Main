// Simple background notification test with service account
const admin = require("firebase-admin");

// Use the same initialization as your existing scripts
const serviceAccount = require("./service-account-key.json");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

async function testBackgroundNotification() {
  const deviceId = "AnxieEase001";

  try {
    // Get the current device token
    const tokenSnap = await admin
      .database()
      .ref(`/devices/${deviceId}/fcmToken`)
      .once("value");
    const token = tokenSnap.val();

    if (!token) {
      console.log("❌ No FCM token found");
      return;
    }

    console.log(`🔑 Using current token: ...${token.slice(-8)}`);
    console.log(
      "\n📱 CLOSE YOUR APP COMPLETELY NOW! Test starts in 5 seconds..."
    );

    // Wait 5 seconds for user to close app
    for (let i = 5; i >= 1; i--) {
      console.log(`⏰ ${i}...`);
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }

    // Test: Simple notification message (should work when app is closed)
    const message = {
      token,
      notification: {
        title: "🚨 Background Test",
        body: "If you see this, background notifications work!",
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          // Remove channelId to avoid channel issues
        },
      },
    };

    console.log("\n📤 Sending background notification...");
    const response = await admin.messaging().send(message);
    console.log("✅ Background notification sent successfully!");
    console.log("📱 Message ID:", response);
    console.log(
      "\n🧪 Check your device! The notification should appear even with app closed."
    );
  } catch (error) {
    console.error("❌ Error:", error);
    if (error.code === "messaging/registration-token-not-registered") {
      console.log("💡 Token expired. Run Flutter app to refresh the token.");
    }
  }
}

testBackgroundNotification();
