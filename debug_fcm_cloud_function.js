const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function debugFCMAndCloudFunction() {
  console.log("🔧 === FCM & CLOUD FUNCTION DEBUG ===\n");

  try {
    // Test 1: Direct FCM to topic
    console.log("1️⃣ Testing direct FCM to topic...");
    const topicMessage = {
      notification: {
        title: "🔔 Direct Topic Test",
        body: "Testing FCM delivery to anxiety_alerts topic"
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          sound: "default"
        }
      },
      topic: "anxiety_alerts"
    };

    const topicResponse = await admin.messaging().send(topicMessage);
    console.log("✅ Topic message sent:", topicResponse);

    await new Promise(resolve => setTimeout(resolve, 3000));

    // Test 2: Test Cloud Function trigger
    console.log("\n2️⃣ Testing Cloud Function trigger...");
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    // Clear first
    await metricsRef.set(null);
    console.log("🧹 Cleared existing data");

    await new Promise(resolve => setTimeout(resolve, 2000));

    // Set initial data
    await metricsRef.set({
      heartRate: 70,
      anxietyDetected: {
        severity: "mild",
        timestamp: Date.now(),
        confidence: 0.6
      },
      timestamp: Date.now()
    });
    console.log("📊 Set initial data: mild");

    await new Promise(resolve => setTimeout(resolve, 3000));

    // Trigger change
    await metricsRef.set({
      heartRate: 115,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.9
      },
      timestamp: Date.now()
    });
    console.log("🚨 Triggered change: mild → severe");
    console.log("   This should activate onAnxietySeverityChangeV2 Cloud Function");

    console.log("\n🎯 === DEBUG RESULTS ===");
    console.log("📱 Expected notifications:");
    console.log("   1. Direct FCM topic test notification");
    console.log("   2. Cloud Function triggered notification (severe alert)");
    
    console.log("\n💡 If you received:");
    console.log("   ✅ Both notifications = System working perfectly");
    console.log("   ✅ Only #1 = Cloud Function issue");
    console.log("   ❌ Neither = FCM/device settings issue");

  } catch (error) {
    console.error("❌ Debug failed:", error);
  }

  process.exit(0);
}

debugFCMAndCloudFunction();
