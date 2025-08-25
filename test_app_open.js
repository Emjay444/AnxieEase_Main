const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testWithAppOpen() {
  console.log("📱 === TESTING WITH APP OPEN ===");
  console.log("🔍 This will show the new log messages from our fix");
  console.log("⏳ Starting test in 5 seconds (make sure app is open)...\n");
  
  await new Promise(resolve => setTimeout(resolve, 5000));

  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    console.log("🧪 Triggering Firebase data change...");
    await metricsRef.set({
      heartRate: 108,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.88
      },
      timestamp: Date.now()
    });

    console.log("✅ Firebase data updated to moderate severity");
    console.log("\n🔍 Check your app logs for these NEW messages:");
    console.log("   ✅ '📊 Firebase data changed - saving record for: moderate'");
    console.log("   ✅ '🚫 Local notifications disabled - Cloud Functions handle notifications'");
    console.log("   ❌ Should NOT see: '🔔 Firebase data changed - sending notification'");
    
    console.log("\n📱 For notifications:");
    console.log("   ✅ Should receive 1 notification from Cloud Function");
    console.log("   ❌ Should NOT receive duplicate notifications");

  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

testWithAppOpen();
