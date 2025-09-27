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

// Moderate anxiety test - 95-105 BPM for 60 seconds with realistic 10-second intervals
async function simulateModerateAnxiety() {
  console.log("🟠 SIMULATING MODERATE ANXIETY CONDITIONS (95-105 BPM)");
  console.log("═".repeat(62));
  console.log("⏱️  Duration: 60 seconds (realistic device intervals)");
  console.log("💓 Target HR: 96-108 BPM (31-48% above baseline of 73.2)");
  console.log("🌡️  Temperature: Slightly elevated (37.0-37.6°C)");
  console.log("📈 SpO2: Normal to slightly low (95-98%)");
  console.log("🎯 Expected: Should trigger MODERATE anxiety alerts");
  console.log("🧘 Expected: Active breathing exercises & coping strategies");
  console.log("📡 Realistic: 10-second intervals (like real device)");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const duration = 60; // 60 seconds total
  const interval = 10; // Send every 10 seconds (realistic)
  const totalUpdates = duration / interval; // 6 data points

  let updateCount = 0;

  const sendUpdate = async () => {
    // Generate heart rate for MODERATE anxiety - must be 30%+ above baseline of 73.2 BPM
    // Moderate threshold: 95.2 BPM minimum, so use 96-108 BPM range for consistent moderate detection
    const heartRate = Math.floor(Math.random() * (108 - 96 + 1)) + 96;
    // Slightly elevated temperature
    const temperature = (Math.random() * (37.6 - 37.0) + 37.0).toFixed(1);
    // Normal to slightly decreased oxygen saturation
    const spo2 = Math.floor(Math.random() * (98 - 95 + 1)) + 95;

    const data = {
      // Match device field names exactly from screenshot
      accelX: (Math.random() * 0.4 - 0.2).toFixed(2), // -0.2 to +0.2 (moderate movement)
      accelY: (Math.random() * 0.4 - 0.2).toFixed(2),
      accelZ: (Math.random() * 0.4 - 0.2).toFixed(2),
      ambientTemp: (Math.random() * (32 - 28) + 28).toFixed(1), // 28-32°C ambient
      battPerc: Math.max(95 - updateCount, 20),
      bodyTemp: parseFloat(temperature),
      gyroX: (Math.random() * 0.02 - 0.01).toFixed(2), // -0.01 to +0.01 rad/s
      gyroY: (Math.random() * 0.02 - 0.01).toFixed(2),
      gyroZ: (Math.random() * 0.02 - 0.01).toFixed(2),
      heartRate: heartRate,
      pitch: (Math.random() * 3 - 1.5).toFixed(1), // -1.5 to +1.5 degrees
      roll: Math.floor(Math.random() * 21 - 10), // -10 to +10 degrees
      spo2: spo2,
      timestamp: new Date().toISOString().replace("T", " ").slice(0, 19), // "2025-09-26 23:53:29" format
      worn: Math.random() > 0.1 ? 1 : 0, // 90% chance worn
      fcmToken: "CZZfrUKQ2WMEATCG6qfLX-AP49blcAa8YrxS_9YKK4jA6d0zs", // Match device token
    };

    updateCount++;
    const elapsed = updateCount * interval;

    console.log(
      `🟠 ${elapsed.toFixed(
        1
      )}s: HR=${heartRate} BPM, SpO2=${spo2}%, Temp=${temperature}°C (${updateCount}/${totalUpdates}) [Realistic 10s intervals]`
    );

    // Add warnings for concerning levels - updated for higher HR
    if (heartRate > 100) {
      console.log(
        `🚨 MODERATE ANXIETY LEVEL: Heart rate significantly elevated (${heartRate} BPM vs 73.2 baseline)`
      );
    } else if (heartRate > 95) {
      console.log(
        `⚠️  MODERATE WARNING: Heart rate elevated (${heartRate} BPM vs 73.2 baseline)`
      );
    }

    await deviceRef.set(data);

    if (updateCount < totalUpdates) {
      setTimeout(sendUpdate, interval * 1000);
    } else {
      console.log("");
      console.log("✅ MODERATE ANXIETY SIMULATION COMPLETE!");
      console.log("═".repeat(45));
      console.log("🔔 Check your app for MODERATE anxiety alerts");
      console.log("📱 Expected: Orange alert with moderate notification sound");
      console.log(
        "🧘 Expected: Active breathing exercises and coping strategies"
      );
      console.log(
        "💡 Expected: Stress management tips and grounding techniques"
      );
      console.log("");
      console.log(
        "📋 SUSTAINED MODERATE INDICATORS (60 seconds, realistic 10s intervals):"
      );
      console.log(`   • Heart Rate: 91-99 BPM (consistently elevated for 50s)`);
      console.log(`   • Temperature: 37.0-37.6°C (slightly elevated)`);
      console.log(`   • GSR: 14-20 µS (moderately elevated, sustained)`);
      console.log(`   • SpO2: 95-98% (normal to slightly low)`);
      console.log(`   • Motion: Moderate restlessness`);
      console.log(
        `   • Updates: ${totalUpdates} data points every 2.5 seconds`
      );

      process.exit(0);
    }
  };

  console.log("🚀 Starting sustained moderate anxiety simulation...");
  console.log("🟠 This simulates continuous moderate anxiety for 50 seconds");
  console.log("");
  sendUpdate();
}

simulateModerateAnxiety().catch((error) => {
  console.error("❌ Test failed:", error);
  process.exit(1);
});
