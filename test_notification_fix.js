const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testDuplicateNotificationFix() {
  console.log("🔧 Testing Duplicate Notification Fix");
  console.log("");
  console.log("📋 Expected Behavior:");
  console.log(
    "✅ App OPEN: Only in-app notifications (no device notifications)"
  );
  console.log("✅ App CLOSED: Only 1 device notification from Cloud Function");
  console.log("");
  console.log("🧪 Starting test in 5 seconds...");
  console.log("📱 Keep your app OPEN for first test");

  await new Promise((resolve) => setTimeout(resolve, 5000));

  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    console.log("\n📱 TEST 1: App OPEN Test");
    console.log("🧹 Clearing data...");
    await metricsRef.set(null);

    await new Promise((resolve) => setTimeout(resolve, 2000));

    const testData = {
      heartRate: 130,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.9,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(testData);
    console.log("🚨 Triggered SEVERE alert");
    console.log(
      "📱 Check: You should see in-app notification but NO device notification"
    );

    await new Promise((resolve) => setTimeout(resolve, 5000));

    console.log("\n📱 TEST 2: App CLOSED Test");
    console.log("🚪 CLOSE YOUR APP NOW!");
    console.log("⏳ Waiting 10 seconds for you to close app...");

    await new Promise((resolve) => setTimeout(resolve, 10000));

    console.log("🧹 Clearing data...");
    await metricsRef.set(null);

    await new Promise((resolve) => setTimeout(resolve, 2000));

    const closedTestData = {
      heartRate: 125,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.85,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(closedTestData);
    console.log("🟠 Triggered MODERATE alert");
    console.log("📱 Check: You should see ONLY 1 device notification");

    console.log("\n🎯 Test Complete!");
    console.log("✅ If you see the expected behavior, the fix is working!");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

testDuplicateNotificationFix();
