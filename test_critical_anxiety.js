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

// Critical anxiety test - 140+ BPM for 45 seconds with multiple indicators
async function simulateCriticalAnxiety() {
  console.log("🚨 SIMULATING CRITICAL ANXIETY EMERGENCY (140+ BPM)");
  console.log("═".repeat(60));
  console.log("⏱️  Duration: 45 seconds");
  console.log("💓 Target HR: 135-150 BPM (84-105% above baseline of 73.2)");
  console.log("🌡️  Temperature: Elevated (37.5-38.5°C)");
  console.log("💧 GSR: Very High (25-35 µS)");
  console.log("📉 SpO2: Slightly decreased (90-95%)");
  console.log("🎯 Expected: Should trigger CRITICAL/EMERGENCY anxiety alerts");
  console.log(
    "🚑 Expected: Emergency contact suggestions & immediate intervention"
  );
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const duration = 45; // 45 seconds
  const interval = 2; // Update every 2 seconds
  const totalUpdates = duration / interval;

  let updateCount = 0;

  const sendUpdate = async () => {
    // Generate heart rate for CRITICAL anxiety - must be 80%+ above baseline of 73.2 BPM
    // Critical threshold: 131.8 BPM minimum, so use 135-150 BPM range for critical detection
    const heartRate = Math.floor(Math.random() * (150 - 135 + 1)) + 135;
    // Elevated temperature during severe anxiety/panic
    const temperature = (Math.random() * (38.5 - 37.5) + 37.5).toFixed(1);
    // Very high GSR during severe stress
    const gsr = (Math.random() * (35.0 - 25.0) + 25.0).toFixed(1);
    // Slightly decreased oxygen saturation during hyperventilation
    const spo2 = Math.floor(Math.random() * (95 - 90 + 1)) + 90;

    const data = {
      heartRate: heartRate,
      spo2: spo2,
      temperature: parseFloat(temperature),
      gsr: parseFloat(gsr),
      motion: "severe", // Severe agitation/movement
      timestamp: Date.now(),
      deviceId: "AnxieEase001",
      batteryLevel: Math.max(95 - updateCount, 20),
      signalStrength: "good",
      // Add significant accelerometer data for severe movement/tremors
      accelX: Math.random() * 40 - 20, // -20 to +20 m/s² (severe movement)
      accelY: Math.random() * 40 - 20,
      accelZ: Math.random() * 40 - 20,
      // Add significant gyroscope data for severe tremors
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
      `🚨 ${elapsed}s: HR=${heartRate} BPM, SpO2=${spo2}%, Temp=${temperature}°C, GSR=${gsr}µS (${updateCount}/${totalUpdates})`
    );

    // Add extra warning for dangerous levels
    if (heartRate > 150) {
      console.log(
        `⚠️  WARNING: Heart rate extremely high (${heartRate} BPM) - EMERGENCY LEVEL`
      );
    }
    if (spo2 < 93) {
      console.log(
        `⚠️  WARNING: Oxygen saturation low (${spo2}%) - Possible hyperventilation`
      );
    }

    await deviceRef.set(data);

    if (updateCount < totalUpdates) {
      setTimeout(sendUpdate, interval * 1000);
    } else {
      console.log("");
      console.log("🚨 CRITICAL ANXIETY SIMULATION COMPLETE!");
      console.log("═".repeat(50));
      console.log("🔔 Check your app for CRITICAL/EMERGENCY anxiety alerts");
      console.log(
        "📱 Expected: Dark red alert with emergency notification sound"
      );
      console.log(
        "🚑 Expected: Emergency contact options and immediate breathing exercises"
      );
      console.log(
        "⚡ Expected: High-priority notification that bypasses Do Not Disturb"
      );
      console.log(
        "🏥 Expected: Possible recommendation to seek immediate medical attention"
      );
      console.log("");
      console.log("📋 CRITICAL INDICATORS SIMULATED:");
      console.log(
        `   • Heart Rate: 140-160 BPM (${
          Math.floor(Math.random() * (160 - 140 + 1)) + 140
        } BPM avg)`
      );
      console.log(`   • Temperature: 37.5-38.5°C (elevated)`);
      console.log(`   • GSR: 25-35 µS (extremely high stress)`);
      console.log(`   • SpO2: 90-95% (hyperventilation effect)`);
      console.log(`   • Motion: Severe agitation/tremors`);
      console.log(`   • Duration: 45 seconds sustained`);

      process.exit(0);
    }
  };

  console.log("🚀 Starting CRITICAL anxiety emergency simulation...");
  console.log("⚠️  This simulates a severe panic attack scenario");
  console.log("");
  sendUpdate();
}

simulateCriticalAnxiety().catch((error) => {
  console.error("❌ Test failed:", error);
  process.exit(1);
});
