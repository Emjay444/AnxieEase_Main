const admin = require("firebase-admin");
const fs = require("fs");

// Initialize Firebase Admin SDK
try {
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

async function debugFCMSetup() {
  console.log("\n🔍 FCM Debug Analysis");
  console.log("=" * 50);

  // Step 1: Test basic FCM connectivity
  try {
    console.log("\n1️⃣ Testing Firebase connectivity...");
    const testMessage = {
      data: { test: "connectivity" },
      topic: "test_topic_12345", // Non-existent topic
    };

    try {
      await admin.messaging().send(testMessage);
      console.log("✅ Firebase messaging service is accessible");
    } catch (error) {
      if (
        error.code === "messaging/topic-message-rate-exceeded" ||
        error.code === "messaging/invalid-argument"
      ) {
        console.log(
          "✅ Firebase messaging service is working (expected error for test topic)"
        );
      } else {
        console.log("❌ Firebase connectivity issue:", error.code);
        return;
      }
    }
  } catch (error) {
    console.log("❌ Firebase connection failed:", error);
    return;
  }

  // Step 2: Test anxiety_alerts topic
  console.log("\n2️⃣ Testing anxiety_alerts topic...");
  try {
    const topicMessage = {
      data: {
        type: "debug_test",
        severity: "test",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🔧 FCM Debug Test",
        body: "Testing anxiety_alerts topic delivery",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          defaultSound: true,
        },
      },
      topic: "anxiety_alerts",
    };

    const response = await admin.messaging().send(topicMessage);
    console.log("✅ Message sent to anxiety_alerts topic");
    console.log("📨 Message ID:", response);

    console.log("\n📱 CLOSE YOUR APP COMPLETELY NOW");
    console.log("⏱️  Wait 10 seconds for notification...");

    // Wait 10 seconds
    await new Promise((resolve) => setTimeout(resolve, 10000));

    console.log("\n❓ Did you receive the notification?");
    console.log("If NO, let's try direct token method...");
  } catch (error) {
    console.log("❌ Topic message failed:", error);

    if (error.code === "messaging/topic-message-rate-exceeded") {
      console.log("⚠️  Topic rate limit hit. This is normal during testing.");
    }
  }
}

async function testWithDirectToken() {
  console.log("\n3️⃣ Testing with direct FCM token...");
  console.log("\n📋 Please provide your FCM token:");
  console.log("1. Run your Flutter app");
  console.log(
    "2. Look for this line in logs: '🔑 FCM registration token: [your_token]'"
  );
  console.log(
    "3. Copy the token and run: node debug_fcm_step_by_step.js [your_token]"
  );

  const token = process.argv[2];
  if (!token) {
    console.log(
      "❌ No token provided. Usage: node debug_fcm_step_by_step.js [FCM_TOKEN]"
    );
    return;
  }

  console.log("🎯 Testing direct token:", token.substring(0, 20) + "...");

  try {
    const directMessage = {
      data: {
        type: "direct_test",
        severity: "moderate",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🎯 Direct FCM Test",
        body: "Testing direct token delivery - app should be CLOSED",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      token: token,
    };

    console.log("📤 Sending direct message...");
    const response = await admin.messaging().send(directMessage);
    console.log("✅ Direct message sent successfully!");
    console.log("📨 Message ID:", response);

    console.log("\n📱 You should receive notification within 5-10 seconds");
    console.log("💡 If still no notification, the issue is device settings");
  } catch (error) {
    console.log("❌ Direct message failed:", error);

    if (error.code === "messaging/registration-token-not-registered") {
      console.log("💡 Token is invalid or app was uninstalled");
    } else if (error.code === "messaging/invalid-registration-token") {
      console.log("💡 Token format is incorrect");
    }
  }
}

async function showDeviceCheckList() {
  console.log("\n4️⃣ Device Settings Checklist:");
  console.log("=" * 40);
  console.log("📱 Go to: Settings > Apps > AnxieEase > Notifications");
  console.log("✅ Ensure 'Anxiety Alerts' channel is ON");
  console.log("✅ Set importance to 'High' or 'Urgent'");
  console.log("");
  console.log("🔋 Go to: Settings > Apps > AnxieEase > Battery");
  console.log("✅ Set to 'Unrestricted' or 'Don't optimize'");
  console.log("✅ Allow background activity");
  console.log("");
  console.log("🔇 Check: Do Not Disturb settings");
  console.log("✅ DND should be OFF or AnxieEase should be in exceptions");
  console.log("");
  console.log("📶 Check: Internet connection");
  console.log("✅ WiFi or mobile data should be active");
  console.log("");
  console.log("🔄 Try: Restart your device");
  console.log("✅ Sometimes Android caches notification settings");
}

// Main execution
if (process.argv[2]) {
  testWithDirectToken();
} else {
  debugFCMSetup().then(() => {
    showDeviceCheckList();
    console.log("\n✨ Debug completed. Try the direct token test next!");
  });
}


