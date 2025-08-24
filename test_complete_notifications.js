const admin = require("firebase-admin");

// Initialize Firebase Admin with your service account key
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testNotificationSystem() {
  try {
    console.log("🧪 === COMPREHENSIVE NOTIFICATION SYSTEM TEST ===");

    // Test 1: Update Firebase Realtime Database (triggers Cloud Function)
    console.log("\n📊 Test 1: Triggering Cloud Function via Firebase DB...");
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    const testData = {
      heartRate: 90,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.85,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(testData);
    console.log("✅ Firebase DB updated - should trigger Cloud Function");

    // Wait 3 seconds, then test severe alert
    setTimeout(async () => {
      console.log("\n🚨 Test 2: Triggering SEVERE alert...");
      const severeData = {
        heartRate: 120,
        anxietyDetected: {
          severity: "severe",
          timestamp: Date.now(),
          confidence: 0.95,
        },
        timestamp: Date.now(),
      };

      await metricsRef.set(severeData);
      console.log("✅ SEVERE alert sent via Cloud Function");

      // Test 3: Direct FCM to device
      setTimeout(async () => {
        console.log("\n📱 Test 3: Direct FCM to device...");
        const deviceToken =
          "cVkrxye5SmOUCy52tLe0fz:APA91bEErAmLuDi91mluTyG6PKjRjEvUhNV59p56kGb3AB1slFl-eUjZuntXIqiM7YohpsOmrp0WKQMU0FIC6-R2BoI7ZV5wFpFltQcGOZcIHATKzsuQ5-w";

        const directMessage = {
          token: deviceToken,
          data: {
            type: "test_alert",
            severity: "severe",
            heartRate: "120",
            timestamp: Date.now().toString(),
          },
          notification: {
            title: "🧪 [TEST] Direct FCM Notification",
            body: "This is a direct test notification - app should be CLOSED to see this!",
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

        const response = await admin.messaging().send(directMessage);
        console.log("✅ Direct FCM sent:", response);

        console.log("\n🎯 === TEST COMPLETE ===");
        console.log("📱 Check your device for notifications!");
        console.log(
          "⚠️  Make sure AnxieEase app is CLOSED to see FCM notifications"
        );

        process.exit(0);
      }, 3000);
    }, 3000);
  } catch (error) {
    console.error("❌ Test failed:", error);
    process.exit(1);
  }
}

testNotificationSystem();
