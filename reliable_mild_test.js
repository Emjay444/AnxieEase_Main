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

async function testMildAnxiety() {
  console.log("🟡 TESTING MILD ANXIETY DETECTION");
  console.log("═══════════════════════════════════");
  console.log("💓 Using heart rate: 90 BPM");
  console.log("📊 Expected severity: MILD (23% above baseline of 73.2)");
  console.log("🎯 Should trigger MILD notification with yellow/green alert");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const heartRate = 90; // 23% above baseline = MILD

  console.log("🚀 Sending mild anxiety data...");
  console.log("");

  for (let i = 1; i <= 4; i++) {
    console.log(`📤 Sending update ${i}/4 with HR: ${heartRate} BPM`);

    const data = {
      accelX: "0.0",
      accelY: "0.0",
      accelZ: "9.8",
      ambientTemp: "30.0",
      battPerc: 95,
      bodyTemp: 37.0,
      gyroX: "0.0",
      gyroY: "0.0",
      gyroZ: "0.0",
      heartRate: heartRate,
      pitch: "0.0",
      roll: 0,
      spo2: 98,
      timestamp: new Date().toISOString().replace("T", " ").slice(0, 19),
      worn: 1,
      fcmToken: "CZZfrUKQ2WMEATCG6qfLX-AP49blcAa8YrxS_9YKK4jA6d0zs",
    };

    try {
      await deviceRef.set(data);
      console.log(`✅ Update ${i} sent successfully`);

      if (i < 4) {
        console.log("⏳ Waiting 10 seconds for next update...");
        await new Promise((resolve) => setTimeout(resolve, 10000));
      }
    } catch (error) {
      console.error(`❌ Error sending update ${i}:`, error);
    }
  }

  console.log("");
  console.log("🎯 MILD TEST COMPLETE!");
  console.log("═══════════════════════");
  console.log("✅ Expected: MILD anxiety notification (yellow/green)");
  console.log("🔊 Expected: Mild alert sound");
  console.log("📱 Check your notification panel");
  console.log("");

  process.exit(0);
}

testMildAnxiety().catch(console.error);
