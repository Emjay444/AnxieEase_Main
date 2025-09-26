const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

// Simple test with known working format from moderate test
async function testDurationCalculation() {
  console.log("🧪 TESTING DURATION CALCULATION FIX...");
  console.log("═".repeat(45));

  const deviceRef = db.ref("/devices/AnxieEase001/current");

  console.log("📤 Sending test data with numeric timestamps...");

  // Send 3 updates with high heart rate using numeric timestamps
  for (let i = 0; i < 3; i++) {
    const data = {
      heartRate: 95, // Well above 84 BPM threshold
      spo2: 98,
      timestamp: Date.now(), // Numeric timestamp
      accelX: "0.10",
      accelY: "0.05",
      accelZ: "9.80",
      ambientTemp: "30.4",
      battPerc: 85,
      bodyTemp: 37.0,
      gyroX: "0.01",
      gyroY: "0.00",
      gyroZ: "0.01",
      pitch: "11.3",
      roll: -12,
      worn: 1,
    };

    await deviceRef.set(data);
    console.log(
      `   ${i + 1}. Sent HR=95 BPM at ${new Date().toLocaleTimeString()}`
    );

    if (i < 2) {
      await new Promise((resolve) => setTimeout(resolve, 15000)); // 15 second intervals
    }
  }

  console.log("\n⏳ Waiting 10 seconds for Firebase function processing...");
  await new Promise((resolve) => setTimeout(resolve, 10000));

  console.log(
    "✅ Test complete. Check Firebase logs for duration calculation."
  );
  console.log(
    '🎯 If still shows "NaN", the issue is in the Firebase function logic.'
  );
}

testDurationCalculation().catch(console.error);
