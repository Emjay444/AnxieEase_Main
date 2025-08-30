const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testDeduplicationFix() {
  console.log("🔧 Testing Deduplication Fix for Multiple Notifications");
  console.log("");
  console.log("📱 CLOSE YOUR APP COMPLETELY!");
  console.log("⏳ Waiting 10 seconds for you to close the app...");

  await new Promise((resolve) => setTimeout(resolve, 10000));

  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    console.log("🧪 TEST: Rapid Firebase changes to trigger deduplication");

    // Clear data
    await metricsRef.set(null);
    console.log("🧹 Cleared data");

    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Set baseline
    const baselineData = {
      heartRate: 75,
      anxietyDetected: {
        severity: "mild",
        timestamp: Date.now(),
        confidence: 0.7,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(baselineData);
    console.log("📊 Set baseline: mild");

    await new Promise((resolve) => setTimeout(resolve, 3000));

    // Trigger severe alert
    const alertData = {
      heartRate: 130,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.95,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(alertData);
    console.log("🚨 Triggered: mild → severe");

    // Wait a moment then trigger another change
    await new Promise((resolve) => setTimeout(resolve, 2000));

    const moderateData = {
      heartRate: 110,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.85,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(moderateData);
    console.log("🟠 Triggered: severe → moderate");

    console.log("\n🎯 Test Complete!");
    console.log("📱 Check your device - you should see:");
    console.log("✅ 1 severe alert notification");
    console.log("✅ 1 moderate alert notification");
    console.log("❌ NO duplicate notifications");
    console.log("");
    console.log("💡 The Cloud Function now has:");
    console.log("   - 30-second deduplication window");
    console.log("   - Unique notification tags");
    console.log("   - Better duplicate prevention");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

testDeduplicationFix();
