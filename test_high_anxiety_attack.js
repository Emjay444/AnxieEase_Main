const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

// High intensity anxiety test - 120+ BPM for 60 seconds with realistic 10-second intervals
async function simulateHighAnxietyAttack() {
  console.log("🔴 SIMULATING HIGH ANXIETY ATTACK (120+ BPM)");
  console.log("═".repeat(60));
  console.log("⏱️  Duration: 60 seconds (realistic device intervals)");
  console.log("💓 Target HR: 120-140 BPM (50-90% above baseline of 73.2)");
  console.log("🌡️  Temperature: Elevated (37.3-37.8°C)");
  console.log("📉 SpO2: Decreased (92-96%)");
  console.log("🎯 Expected: Should trigger SEVERE/CRITICAL anxiety alerts");
  console.log("🚨 Expected: Urgent intervention & calming techniques");
  console.log("📡 Realistic: 10-second intervals (like real device)");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const duration = 60; // 60 seconds total
  const interval = 10; // Send every 10 seconds (realistic)
  const totalUpdates = duration / interval; // 6 data points

  let updateCount = 0;

  const sendUpdate = async () => {
    // Generate random HR between 120-140 BPM
    const heartRate = Math.floor(Math.random() * (140 - 120 + 1)) + 120;
    // Higher temperature during anxiety
    const temperature = (Math.random() * (38.2 - 37.5) + 37.5).toFixed(1);
    // Higher GSR during stress
    const gsr = (Math.random() * (25.0 - 18.0) + 18.0).toFixed(1);

    const data = {
      heartRate: heartRate,
      spo2: Math.floor(Math.random() * (96 - 92 + 1)) + 92, // 92-96% (normal range during anxiety)
      temperature: parseFloat(temperature),
      gsr: parseFloat(gsr),
      motion: "elevated",
      timestamp: new Date().toISOString().replace("T", " ").slice(0, 19), // "2025-09-27 12:34:56" format
      deviceId: "AnxieEase001",
      batteryLevel: Math.max(95 - updateCount, 20),
      signalStrength: "good",
      // Add accelerometer data for movement analysis
      accelX: Math.random() * 20 - 10, // -10 to +10 m/s²
      accelY: Math.random() * 20 - 10,
      accelZ: Math.random() * 20 - 10,
      // Add gyroscope data for tremor detection
      gyroX: Math.random() * 10 - 5, // -5 to +5 rad/s
      gyroY: Math.random() * 10 - 5,
      gyroZ: Math.random() * 10 - 5,
      bodyTemp: parseFloat(temperature), // Add bodyTemp field
    };

    updateCount++;
    const elapsed = updateCount * interval;

    console.log(
      `⏱️  ${elapsed}s: HR=${heartRate} BPM, SpO2=${data.spo2}%, Temp=${temperature}°C, GSR=${gsr} (${updateCount}/${totalUpdates}) [Realistic 10s intervals]`
    );

    await deviceRef.set(data);

    if (updateCount < totalUpdates) {
      setTimeout(sendUpdate, interval * 1000);
    } else {
      console.log("");
      console.log("✅ High anxiety simulation complete!");
      console.log("🔔 Check your app for SEVERE/CRITICAL anxiety alerts");
      console.log("📱 Expected: Red alert with emergency notification");
      console.log(
        "💊 Expected: Breathing exercises or emergency contact suggestions"
      );
      process.exit(0);
    }
  };

  console.log("🚀 Starting continuous high anxiety simulation...");
  console.log("");
  sendUpdate();
}

simulateHighAnxietyAttack().catch((error) => {
  console.error("❌ Test failed:", error);
  process.exit(1);
});
