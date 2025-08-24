const admin = require("firebase-admin");

// Initialize Firebase Admin with your service account key
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.database();

async function simulateSeverityChange() {
  const metricsRef = db.ref("devices/AnxieEase001/Metrics");

  try {
    console.log("📊 Simulating anxiety severity change...");

    // Simulate a severity change
    const testData = {
      heartRate: 85,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.8,
      },
      timestamp: Date.now(),
    };

    await metricsRef.set(testData);
    console.log("✅ Test data written to Firebase Realtime Database");
    console.log(
      "📱 This should trigger the Cloud Function and send FCM notification"
    );

    // Wait a bit then change to severe
    setTimeout(async () => {
      const severeData = {
        heartRate: 95,
        anxietyDetected: {
          severity: "severe",
          timestamp: Date.now(),
          confidence: 0.9,
        },
        timestamp: Date.now(),
      };

      await metricsRef.set(severeData);
      console.log(
        "🔴 Changed to SEVERE - this should trigger urgent notification"
      );

      process.exit(0);
    }, 3000);
  } catch (error) {
    console.error("❌ Error:", error);
    process.exit(1);
  }
}

simulateSeverityChange();
