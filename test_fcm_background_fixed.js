const admin = require("firebase-admin");
const fs = require("fs");

// Initialize Firebase Admin SDK
try {
  // Check if service account key exists
  if (!fs.existsSync("./service-account-key.json")) {
    console.error("❌ service-account-key.json not found!");
    console.log(
      "📋 Please download it from Firebase Console > Project Settings > Service Accounts > Generate new private key"
    );
    process.exit(1);
  }

  // Initialize Firebase Admin
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxiease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });

  console.log("✅ Firebase Admin initialized successfully");
} catch (error) {
  console.error("❌ Error initializing Firebase Admin:", error);
  process.exit(1);
}

async function testBackgroundNotification() {
  try {
    console.log("\n🧪 Testing FIXED background FCM notification...");

    // Test notification with proper format for background delivery
    const message = {
      // Data payload for background processing
      data: {
        type: "anxiety_alert",
        severity: "moderate",
        heartRate: "85",
        timestamp: Date.now().toString(),
      },
      // Notification payload - FCM will display this automatically
      notification: {
        title: "🟠 Moderate Anxiety Alert",
        body: "Elevated anxiety levels detected. Heart rate: 85 bpm",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
          tag: "anxiety_alert",
        },
      },
      // Send to the anxiety_alerts topic
      topic: "anxiety_alerts",
    };

    console.log("📤 Sending background notification...");
    const response = await admin.messaging().send(message);
    console.log("✅ Notification sent successfully!");
    console.log("📨 Message ID:", response);

    console.log("\n📱 Testing Instructions:");
    console.log(
      "1. Make sure AnxieEase app is COMPLETELY CLOSED (not in recent apps)"
    );
    console.log("2. You should receive the notification within 5-10 seconds");
    console.log("3. The notification should appear even with app closed");
    console.log("\n🔧 If notification doesn't appear:");
    console.log(
      "   a) Check Android Settings > Apps > AnxieEase > Notifications"
    );
    console.log('   b) Ensure "Anxiety Alerts" channel is enabled');
    console.log(
      "   c) Check Battery Optimization (should be disabled for AnxieEase)"
    );
    console.log("   d) Check if Do Not Disturb mode is ON");
    console.log("   e) Ensure device has internet connection");
  } catch (error) {
    console.error("❌ Error sending notification:", error);

    if (error.code === "messaging/registration-token-not-registered") {
      console.log(
        "💡 The app needs to be run at least once to subscribe to the topic"
      );
    }
  }
}

// Send a high priority notification for severe alerts
async function testSevereNotification() {
  try {
    console.log("\n🚨 Testing SEVERE alert notification...");

    const message = {
      data: {
        type: "anxiety_alert",
        severity: "severe",
        heartRate: "120",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🔴 SEVERE Anxiety Alert",
        body: "URGENT: High anxiety levels detected! Heart rate: 120 bpm",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
          visibility: "public",
          tag: "severe_alert",
        },
      },
      topic: "anxiety_alerts",
    };

    const response = await admin.messaging().send(message);
    console.log("✅ Severe alert sent! Message ID:", response);
  } catch (error) {
    console.error("❌ Error sending severe notification:", error);
  }
}

// Run the test based on command line argument
const testType = process.argv[2];

if (testType === "severe") {
  testSevereNotification().then(() => {
    console.log("\n✨ Severe alert test completed");
    process.exit(0);
  });
} else {
  testBackgroundNotification().then(() => {
    console.log("\n✨ Background notification test completed");
    process.exit(0);
  });
}


