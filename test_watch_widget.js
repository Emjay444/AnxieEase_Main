const admin = require("firebase-admin");

// Initialize Firebase Admin with your service account key
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testWatchWidget() {
  try {
    console.log("🧪 Testing Watch Widget Updates...");

    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");

    // Test different heart rates to see if watch updates
    const heartRates = [75, 85, 95, 105, 115];

    for (let i = 0; i < heartRates.length; i++) {
      const hr = heartRates[i];
      console.log(`\n💓 Setting heart rate to: ${hr} bpm`);

      const testData = {
        heartRate: hr,
        isDeviceWorn: true,
        anxietyDetected: {
          severity: hr > 100 ? "moderate" : "mild",
          timestamp: Date.now(),
          confidence: 0.8,
        },
        timestamp: Date.now(),
      };

      await metricsRef.set(testData);
      console.log(`✅ Firebase updated with HR: ${hr}`);

      // Wait 2 seconds before next update
      if (i < heartRates.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 2000));
      }
    }

    console.log("\n🎯 Test complete! Check your watch widget for updates.");
    console.log(
      "📱 The heart rate should change from 75 → 85 → 95 → 105 → 115"
    );
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
}

testWatchWidget();
