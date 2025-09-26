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

// Mild anxiety test - 84-91 BPM for 60 seconds with realistic 10-second intervals
async function simulateMildAnxiety() {
  console.log("� SIMULATING MILD ANXIETY CONDITIONS (84-91 BPM)");
  console.log("═".repeat(60));
  console.log("⏱️  Duration: 60 seconds (realistic device intervals)");
  console.log("💓 Target HR: 84-91 BPM (15-25% above baseline of 73.2)");
  console.log("🌡️  Temperature: Normal range (36.8-37.2°C)");
  console.log("💧 GSR: Slightly elevated (8-14 µS)");
  console.log("� SpO2: Normal (97-99%)");
  console.log("🎯 Expected: Should trigger MILD anxiety alerts");
  console.log("🌱 Expected: Gentle breathing exercises & mindfulness tips");
  console.log("📡 Realistic: 10-second intervals (like real device)");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const duration = 60; // 60 seconds total
  const interval = 10; // Send every 10 seconds (realistic)
  const totalUpdates = duration / interval;

  let updateCount = 0;

  const sendUpdate = async () => {
    // Generate mild heart rate for MILD anxiety (84-91 BPM) - 15-25% above baseline of 73.2
    const heartRate = Math.floor(Math.random() * (91 - 84 + 1)) + 84;
    // Normal temperature range
    const temperature = (Math.random() * (37.2 - 36.8) + 36.8).toFixed(1);
    // Slightly elevated GSR
    const gsr = (Math.random() * (14.0 - 8.0) + 8.0).toFixed(1);
    // Normal oxygen saturation
    const spo2 = Math.floor(Math.random() * (99 - 97 + 1)) + 97;

    const data = {
      heartRate: heartRate,
      spo2: spo2,
      temperature: parseFloat(temperature),
      gsr: parseFloat(gsr),
      motion: "mild", // Mild restlessness/movement
      timestamp: Date.now(), // Use numeric timestamp (milliseconds)
      deviceId: "AnxieEase001",
      batteryLevel: Math.max(95 - updateCount, 20),
      signalStrength: "good",
      // Add mild accelerometer data for gentle movement
      accelX: Math.random() * 2 - 1, // -1 to +1 m/s² (mild movement)
      accelY: Math.random() * 2 - 1,
      accelZ: Math.random() * 2 - 1,
      // Add mild gyroscope data for slight restlessness
      gyroX: Math.random() * 20 - 10, // -10 to +10 rad/s (severe rotation/tremor)
      gyroY: Math.random() * 20 - 10,
      gyroZ: Math.random() * 20 - 10,
      bodyTemp: parseFloat(temperature),
      // Additional critical indicators
      breathingRate: Math.floor(Math.random() * (35 - 25 + 1)) + 25, // 25-35 breaths/min (hyperventilation)
      stressLevel: "critical",
      panicIndicators: [
        "rapid_heartbeat",
        "tremor",
        "hyperventilation",
        "elevated_temp",
      ],
    };

    updateCount++;
    const elapsed = updateCount * interval;

    console.log(
      `� ${elapsed}s: HR=${heartRate} BPM, SpO2=${spo2}%, Temp=${temperature}°C, GSR=${gsr}µS (${updateCount}/${totalUpdates}) [Realistic 10s intervals]`
    );

    // Add warnings for mild anxiety levels
    if (heartRate > 88) {
      console.log(
        `⚠️  MILD ANXIETY LEVEL: Heart rate elevated (${heartRate} BPM vs 73.2 baseline)`
      );
    } else if (heartRate > 84) {
      console.log(
        `💛 MILD WARNING: Heart rate slightly elevated (${heartRate} BPM vs 73.2 baseline)`
      );
    }

    await deviceRef.set(data);

    if (updateCount < totalUpdates) {
      setTimeout(sendUpdate, interval * 1000);
    } else {
      console.log("");
      console.log("✅ MILD ANXIETY SIMULATION COMPLETE!");
      console.log("═".repeat(45));
      console.log("🔔 Check your app for MILD anxiety alerts");
      console.log("📱 Expected: Yellow alert with mild notification sound");
      console.log(
        "🌱 Expected: Gentle breathing exercises and mindfulness tips"
      );
      console.log("💡 Expected: Early intervention suggestions");
      console.log("");
      console.log(
        "📋 MILD INDICATORS SIMULATED (60 seconds, realistic 10s intervals):"
      );
      console.log(
        `   • Heart Rate: 84-91 BPM (${Math.round((84 + 91) / 2)} BPM avg)`
      );
      console.log(`   • Temperature: 36.8-37.2°C (normal range)`);
      console.log(`   • GSR: 8-14 µS (slightly elevated)`);
      console.log(`   • SpO2: 97-99% (normal)`);
      console.log(`   • Motion: Mild restlessness`);
      console.log(`   • Duration: 60 seconds sustained`);

      process.exit(0);
    }
  };

  console.log("🚀 Starting mild anxiety simulation...");
  console.log("🌱 This simulates sustained mild anxiety conditions");
  console.log("");
  sendUpdate();
}

simulateMildAnxiety().catch((error) => {
  console.error("❌ Test failed:", error);
  process.exit(1);
});
