const admin = require("firebase-admin");

// Simple FCM test - just provide your token as argument
const token = process.argv[2];

if (!token) {
  console.log("❌ Usage: node test_fcm_simple.js [YOUR_FCM_TOKEN]");
  console.log(
    "📋 Get your token from Flutter logs: '🔑 FCM registration token: [token]'"
  );
  process.exit(1);
}

// Initialize Firebase
try {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxiease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
} catch (error) {
  console.error("❌ Firebase init error:", error);
  process.exit(1);
}

async function sendSimpleTest() {
  try {
    console.log("🧪 Sending simple FCM test...");
    console.log("📱 MAKE SURE YOUR APP IS COMPLETELY CLOSED");

    const message = {
      notification: {
        title: "🚀 Simple FCM Test",
        body: "If you see this, FCM is working!",
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "anxiety_alerts",
        },
      },
      token: token,
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Message sent! ID:", response);
    console.log("⏰ Check your device now (within 10 seconds)");
  } catch (error) {
    console.error("❌ Send failed:", error);

    if (error.code === "messaging/registration-token-not-registered") {
      console.log("💡 Token invalid - make sure app was run recently");
    } else if (error.code === "messaging/invalid-registration-token") {
      console.log("💡 Token format wrong - check copy/paste");
    }
  }
}

sendSimpleTest().then(() => process.exit(0));


