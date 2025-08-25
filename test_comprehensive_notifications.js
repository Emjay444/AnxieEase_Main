const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function comprehensiveNotificationTest() {
  console.log("🔍 === COMPREHENSIVE NOTIFICATION TEST ===");
  console.log("📱 This test works whether your app is OPEN or CLOSED\n");

  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    // Test 1: Clear and set baseline
    console.log("1️⃣ Setting up baseline data...");
    await metricsRef.set({
      heartRate: 75,
      anxietyDetected: {
        severity: "mild",
        timestamp: Date.now(),
        confidence: 0.7
      },
      timestamp: Date.now()
    });
    console.log("✅ Baseline set: mild severity");
    
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Test 2: Trigger moderate alert
    console.log("\n2️⃣ Triggering MODERATE severity change...");
    await metricsRef.set({
      heartRate: 95,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.85
      },
      timestamp: Date.now()
    });
    console.log("✅ Moderate alert triggered (should send notification)");
    
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Test 3: Trigger severe alert
    console.log("\n3️⃣ Triggering SEVERE severity change...");
    await metricsRef.set({
      heartRate: 120,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.95
      },
      timestamp: Date.now()
    });
    console.log("✅ Severe alert triggered (should send HIGH PRIORITY notification)");

    console.log("\n🎯 === TEST RESULTS ===");
    console.log("📱 If your app is OPEN, check logs for:");
    console.log("   ✅ '📊 Firebase data changed - saving record'");
    console.log("   ✅ '🚫 Local notifications disabled'");
    console.log("   ❌ Should NOT see '🔔 Firebase data changed - sending notification'");
    
    console.log("\n📱 For notifications, you should receive:");
    console.log("   🟠 1x Moderate alert notification");
    console.log("   🔴 1x Severe alert notification");
    console.log("   ❌ NO duplicate notifications");

    console.log("\n💡 If no notifications received:");
    console.log("   1. Check Cloud Functions are deployed (they are)");
    console.log("   2. Check Android battery optimization settings");
    console.log("   3. Check notification permissions");
    console.log("   4. Check FCM subscription to topic");

  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  console.log("\n⏳ Test complete - check your device for notifications!");
  process.exit(0);
}

comprehensiveNotificationTest();
