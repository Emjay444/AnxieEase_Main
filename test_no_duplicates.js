const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testNoDuplicateNotifications() {
  console.log("🎯 === FINAL TEST: NO MORE DUPLICATE NOTIFICATIONS ===");
  console.log("📱 This should show exactly 1 notification (not 2!)");
  console.log("⏳ Starting test in 5 seconds...\n");
  
  await new Promise(resolve => setTimeout(resolve, 5000));

  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    console.log("🧪 Triggering Firebase data change...");
    await metricsRef.set({
      heartRate: 118,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.92
      },
      timestamp: Date.now()
    });

    console.log("✅ Firebase updated to SEVERE severity");
    console.log("\n🔍 What should happen now:");
    console.log("   1. Cloud Function detects change");
    console.log("   2. Cloud Function sends FCM notification");
    console.log("   3. Your device receives 1 notification");
    console.log("   4. App logs show: '🚫 Foreground notification creation disabled'");
    console.log("   5. Local listener saves to Supabase but creates NO notification");

    console.log("\n📱 Expected result:");
    console.log("   ✅ Exactly 1 severe alert notification");
    console.log("   ❌ NO duplicate notifications");

    console.log("\n🎯 SUCCESS CRITERIA:");
    console.log("   - If you get 1 notification = FIXED! ✅");
    console.log("   - If you get 2 notifications = Still has issue ❌");

  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

testNoDuplicateNotifications();
