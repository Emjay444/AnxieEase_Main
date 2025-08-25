const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function comprehensiveNotificationDiagnostic() {
  console.log("🔍 === COMPREHENSIVE NOTIFICATION DIAGNOSTIC ===\n");

  try {
    // 1. Test Cloud Functions are active
    console.log("📡 1. Testing Cloud Functions deployment...");
    try {
      const db = admin.database();
      const testRef = db.ref("devices/AnxieEase001/Metrics");

      // First, clear any existing data
      await testRef.set(null);
      console.log("✅ Cleared existing data");

      // Wait a moment
      await new Promise((resolve) => setTimeout(resolve, 2000));

      // Set initial data
      const initialData = {
        heartRate: 75,
        anxietyDetected: {
          severity: "mild",
          timestamp: Date.now(),
          confidence: 0.8,
        },
        timestamp: Date.now(),
      };

      await testRef.set(initialData);
      console.log("✅ Set initial mild severity");

      // Wait, then trigger a change
      await new Promise((resolve) => setTimeout(resolve, 3000));

      const changeData = {
        heartRate: 115,
        anxietyDetected: {
          severity: "severe",
          timestamp: Date.now(),
          confidence: 0.9,
        },
        timestamp: Date.now(),
      };

      await testRef.set(changeData);
      console.log("✅ Triggered severity change: mild -> severe");
      console.log("   📱 Check your device for notification!");
    } catch (error) {
      console.log("❌ Cloud Function test failed:", error.message);
    }

    // 2. Test FCM topic subscription
    console.log("\n📢 2. Testing FCM topic subscription...");
    try {
      const testMessage = {
        notification: {
          title: "🔔 Direct FCM Test",
          body: "Testing background notification delivery",
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

      const response = await admin.messaging().send(testMessage);
      console.log("✅ Direct FCM sent to topic:", response);
      console.log("   📱 Check your device for notification!");
    } catch (error) {
      console.log("❌ FCM topic test failed:", error.message);
    }

    // 3. Check Firebase connection
    console.log("\n🔗 3. Testing Firebase connection...");
    try {
      const snapshot = await admin
        .database()
        .ref("devices/AnxieEase001/Metrics")
        .once("value");
      const data = snapshot.val();
      console.log("✅ Firebase connection successful");
      console.log("📊 Current data:", JSON.stringify(data, null, 2));
    } catch (error) {
      console.log("❌ Firebase connection failed:", error.message);
    }

    console.log("\n🎯 === DIAGNOSTIC COMPLETE ===");
    console.log("📱 INSTRUCTIONS:");
    console.log("1. Make sure your AnxieEase app is COMPLETELY CLOSED");
    console.log("2. Check your phone for notifications within 30 seconds");
    console.log("3. If no notifications, check device settings:");
    console.log("   - Notification permissions for AnxieEase");
    console.log("   - Battery optimization (disable for AnxieEase)");
    console.log("   - Background app restrictions");
    console.log("   - Do Not Disturb mode");
  } catch (error) {
    console.error("❌ Diagnostic failed:", error);
  } finally {
    process.exit(0);
  }
}

comprehensiveNotificationDiagnostic();
