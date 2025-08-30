// Test Firebase Database trigger to see if Cloud Functions respond
const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testDatabaseTrigger() {
  console.log("🧪 Testing Firebase Database trigger for anxiety detection...");

  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    // First, read current data
    console.log("\n📊 Reading current Firebase data...");
    const snapshot = await metricsRef.once("value");
    const currentData = snapshot.val();
    console.log("Current data:", JSON.stringify(currentData, null, 2));

    // Test different severity levels
    const testCases = [
      { severity: "mild", heartRate: 75, description: "Mild anxiety test" },
      {
        severity: "moderate",
        heartRate: 90,
        description: "Moderate anxiety test",
      },
      {
        severity: "severe",
        heartRate: 110,
        description: "Severe anxiety test",
      },
    ];

    for (const testCase of testCases) {
      console.log(`\n🔥 Testing ${testCase.description}...`);

      const testData = {
        heartRate: testCase.heartRate,
        anxietyDetected: {
          severity: testCase.severity,
          timestamp: Date.now(),
          confidence: 0.85,
        },
        timestamp: Date.now(),
      };

      // Write data to Firebase - this should trigger the Cloud Function
      await metricsRef.set(testData);
      console.log(`✅ Data written to Firebase:`, testData);
      console.log(`⏳ Waiting for Cloud Function to process...`);

      // Wait a moment for Cloud Function to process
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }

    console.log("\n🎉 Database trigger test completed!");
    console.log(
      "📱 Check your device for notifications if Cloud Functions are active"
    );
  } catch (error) {
    console.error("❌ Database trigger test failed:", error);
  }
}

// Run the test
testDatabaseTrigger();
