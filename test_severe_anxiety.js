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

// Severe anxiety test - 120-140 BPM for 60 seconds with multiple indicators
async function simulateSevereAnxiety() {
  console.log("🔴 SIMULATING SEVERE ANXIETY CONDITIONS (120-140 BPM)");
  console.log("═".repeat(62));
  console.log("⏱️  Duration: 60 seconds (realistic device intervals)");
  console.log("💓 Target HR: 112-125 BPM (53-71% above baseline of 73.2)");
  console.log("🌡️  Temperature: Elevated (37.3-38.0°C)");
  console.log("💧 GSR: High stress levels (18-25 µS)");
  console.log("📉 SpO2: Slightly decreased (92-96%)");
  console.log("🎯 Expected: Should trigger SEVERE anxiety alerts");
  console.log("🆘 Expected: Immediate coping strategies & emergency contacts");
  console.log("📡 Realistic: 10-second intervals (like real device)");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const duration = 60; // 60 seconds total
  const interval = 10; // Send every 10 seconds (realistic)
  const totalUpdates = duration / interval;

  let updateCount = 0;

  const sendUpdate = async () => {
    // Generate heart rate for SEVERE anxiety - must be 50%+ above baseline of 73.2 BPM
    // Severe threshold: 109.8 BPM minimum, so use 112-125 BPM range for consistent severe detection
    const heartRate = Math.floor(Math.random() * (125 - 112 + 1)) + 112;
    // Elevated temperature range
    const temperature = (Math.random() * (38.0 - 37.3) + 37.3).toFixed(1);
    // High GSR during severe stress
    const gsr = (Math.random() * (25.0 - 18.0) + 18.0).toFixed(1);
    // Slightly decreased oxygen saturation
    const spo2 = Math.floor(Math.random() * (96 - 92 + 1)) + 92;

    const data = {
      heartRate: heartRate,
      spo2: spo2,
      temperature: parseFloat(temperature),
      gsr: parseFloat(gsr),
      batteryLevel: Math.max(95 - updateCount * 2, 15),
      signalStrength: "good",
      timestamp: new Date().toISOString().replace('T', ' ').substring(0, 19),
      worn: 1,
      accelX: (Math.random() * 1.0 - 0.5).toFixed(2), // More movement
      accelY: (Math.random() * 1.0 - 0.5).toFixed(2),
      accelZ: (Math.random() * 1.0 - 0.5).toFixed(2),
      gyroX: (Math.random() * 12 - 6).toFixed(2), // Higher gyro values
      gyroY: (Math.random() * 12 - 6).toFixed(2),
      gyroZ: (Math.random() * 12 - 6).toFixed(2),
      breathingRate: Math.floor(Math.random() * (38 - 32 + 1)) + 32, // 32-38 breaths/min
      bodyTemp: parseFloat(temperature),
      motion: "severe",
      stressLevel: "severe",
      panicIndicators: [
        "rapid_heartbeat",
        "tremor",
        "hyperventilation",
        "elevated_temp",
        "excessive_sweating"
      ],
      sessionId: "session_1758850736983",
      userId: "5afad7d4-3dcd-4353-badb-4f155303419a",
      deviceId: "AnxieEase001"
    };

    updateCount++;
    const timeElapsed = updateCount * interval;

    try {
      await deviceRef.set(data);

      // Visual indicators for severe anxiety
      let indicator;
      if (heartRate >= 135) {
        indicator = "🚨 SEVERE PANIC LEVEL";
      } else if (heartRate >= 130) {
        indicator = "🔴 SEVERE HIGH LEVEL";
      } else {
        indicator = "⚠️  SEVERE ANXIETY LEVEL";
      }

      console.log(
        `🔥 ${timeElapsed}s: HR=${heartRate} BPM, SpO2=${spo2}%, Temp=${temperature}°C, GSR=${gsr}µS (${updateCount}/${totalUpdates}) [Realistic 10s intervals]`
      );
      console.log(`   ${indicator}: Heart rate severely elevated (${heartRate} BPM vs 73.2 baseline)`);

      if (updateCount < totalUpdates) {
        setTimeout(sendUpdate, interval * 1000);
      } else {
        console.log("");
        console.log("✅ SEVERE ANXIETY SIMULATION COMPLETE!");
        console.log("═".repeat(50));
        console.log("🔔 Check your app for SEVERE anxiety alerts");
        console.log("📱 Expected: Red alert with urgent notification sound");
        console.log("🆘 Expected: Emergency coping strategies and contact options");
        console.log("💡 Expected: Immediate intervention recommendations");
        console.log("");
        console.log("📋 SEVERE INDICATORS SIMULATED (60 seconds, realistic 10s intervals):");
        console.log("   • Heart Rate: 120-140 BPM (130 BPM avg)");
        console.log("   • Temperature: 37.3-38.0°C (elevated range)");
        console.log("   • GSR: 18-25 µS (high stress)");
        console.log("   • SpO2: 92-96% (slightly low)");
        console.log("   • Motion: Severe restlessness");
        console.log("   • Duration: 60 seconds sustained severe anxiety");
      }
    } catch (error) {
      console.error("❌ Error updating device data:", error);
    }
  };

  console.log("🚀 Starting severe anxiety simulation...");
  console.log("🔴 This simulates severe anxiety attack conditions");
  console.log("");
  sendUpdate();
}

simulateSevereAnxiety();