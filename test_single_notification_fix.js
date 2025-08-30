const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testSingleNotification() {
  console.log("🧪 Testing Single Notification Fix");
  console.log("📱 Make sure your app is OPEN to see the fix in action");
  console.log("⏳ Changing Firebase data in 5 seconds...\n");

  await new Promise((resolve) => setTimeout(resolve, 5000));

  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    // Clear data first
    await metricsRef.set(null);
    console.log("🧹 Cleared existing data");

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
    console.log("📊 Set baseline: mild severity");

    await new Promise((resolve) => setTimeout(resolve, 3000));

    // Trigger change
    const changeData = {
      heartRate: 120,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.95,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(changeData);
    console.log("🚨 Triggered change: mild → severe");
    console.log(
      "📱 You should now receive ONLY 1 notification (from Cloud Function)"
    );
    console.log("✅ Local app listener will NOT create duplicate notification");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

testSingleNotification();
