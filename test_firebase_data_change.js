const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testFirebaseDataChanges() {
  try {
    console.log(
      "🧪 Testing Firebase Data Changes (This should trigger Cloud Functions)..."
    );
    console.log("📱 Make sure your app is COMPLETELY CLOSED!");
    console.log("⏳ Waiting 5 seconds...\n");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    // Test scenarios that should trigger Cloud Functions
    const testScenarios = [
      {
        severity: "mild",
        hr: 85,
        desc: "Mild anxiety level",
      },
      {
        severity: "moderate",
        hr: 105,
        desc: "Moderate anxiety level",
      },
      {
        severity: "severe",
        hr: 125,
        desc: "Severe anxiety level",
      },
    ];

    for (let i = 0; i < testScenarios.length; i++) {
      const scenario = testScenarios[i];
      console.log(
        `\n📢 Test ${i + 1}/3: Setting Firebase data to ${scenario.severity}`
      );

      const testData = {
        heartRate: scenario.hr,
        batteryLevel: 75,
        isDeviceWorn: true,
        anxietyDetected: {
          severity: scenario.severity,
          timestamp: Date.now(),
          confidence: 0.85,
        },
        timestamp: Date.now(),
      };

      await metricsRef.set(testData);
      console.log(
        `✅ Firebase updated with severity: ${scenario.severity}, HR: ${scenario.hr}`
      );
      console.log(`   This should trigger Cloud Function if deployed...`);

      // Wait between updates
      if (i < testScenarios.length - 1) {
        console.log("⏳ Waiting 10 seconds before next change...");
        await new Promise((resolve) => setTimeout(resolve, 10000));
      }
    }

    console.log("\n🎯 Firebase data change tests completed!");
    console.log(
      "\n📱 If Cloud Functions are deployed, you should receive notifications."
    );
    console.log(
      "❌ If no notifications received, Cloud Functions are not deployed."
    );
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
}

testFirebaseDataChanges();

