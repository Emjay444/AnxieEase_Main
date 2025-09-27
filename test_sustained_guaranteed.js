const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function testSustainedAnxiety() {
  console.log("🚨 TESTING SUSTAINED ANXIETY (GUARANTEED TO TRIGGER)");
  console.log("════════════════════════════════════════════════════════════");
  console.log("💓 Target: 15 consecutive readings above 88 BPM");
  console.log("⏱️  Duration: 150+ seconds of sustained elevation");
  console.log("🎯 Expected: DEFINITELY should trigger notifications");
  console.log("");

  const deviceId = "AnxieEase001";
  const baseline = 73.2;
  const targetHR = 90; // Well above threshold of 87.84
  
  console.log(`🚀 Starting SUSTAINED anxiety test with HR=${targetHR} BPM...`);
  console.log(`📊 Baseline: ${baseline} BPM, Threshold: ${baseline * 1.2} BPM`);
  console.log("");

  for (let i = 1; i <= 15; i++) {
    const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
    
    const data = {
      deviceId: deviceId,
      heartRate: targetHR + Math.random() * 3, // 90-93 BPM - consistently high
      spo2: 97 + Math.floor(Math.random() * 3),
      temperature: 36.8 + Math.random() * 0.4,
      gsr: 10 + Math.random() * 4,
      batteryLevel: 95 - i,
      signalStrength: "good",
      timestamp: timestamp,
      worn: 1,
      accelX: Math.random() * 2 - 1,
      accelY: Math.random() * 2 - 1,
      accelZ: Math.random() * 2 - 1,
      gyroX: Math.random() * 10 - 5,
      gyroY: Math.random() * 10 - 5,
      gyroZ: Math.random() * 10 - 5,
      breathingRate: 28 + Math.floor(Math.random() * 8),
      bodyTemp: 36.8 + Math.random() * 0.4,
      motion: "mild",
      stressLevel: "high",
      panicIndicators: ["rapid_heartbeat", "elevated_temp"],
      sessionId: "session_1758850736983",
      userId: "5afad7d4-3dcd-4353-badb-4f155303419a"
    };

    try {
      await db.ref(`/devices/${deviceId}/current`).set(data);
      const hr = Math.round(data.heartRate);
      console.log(`🔥 ${i * 10}s: HR=${hr} BPM, SpO2=${data.spo2}%, Temp=${data.temperature.toFixed(1)}°C (${i}/15) [HIGH SUSTAINED]`);
      
      // Wait 10 seconds between updates for realistic timing
      if (i < 15) {
        await new Promise(resolve => setTimeout(resolve, 10000));
      }
      
    } catch (error) {
      console.error(`❌ Error updating device data:`, error);
    }
  }

  console.log("");
  console.log("✅ SUSTAINED ANXIETY TEST COMPLETE!");
  console.log("═════════════════════════════════════════════");
  console.log("🔔 Check Firebase logs for sustained anxiety detection");
  console.log("📱 Check your device for anxiety notifications");
  console.log("");
  console.log("📋 SUSTAINED INDICATORS SIMULATED (150 seconds):");
  console.log(`   • Heart Rate: ${targetHR}-${targetHR+3} BPM (consistently HIGH)`);
  console.log("   • Duration: 150+ seconds of sustained elevation");
  console.log("   • Above threshold for entire duration");
  console.log("   • Should trigger multiple 10+ second detections");
}

testSustainedAnxiety();