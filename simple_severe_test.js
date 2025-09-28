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

async function testSevereAnxiety() {
  console.log("🔴 TESTING SEVERE ANXIETY DETECTION");
  console.log("═══════════════════════════════════");
  console.log("💓 Using heart rate: 115 BPM");
  console.log("📊 Expected severity: SEVERE (57% above baseline of 73.2)");
  console.log("🎯 Should trigger SEVERE notification with red alert");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const heartRate = 115; // 57% above baseline = SEVERE

  console.log("🚀 Sending severe anxiety data...");
  console.log("");

  for (let i = 1; i <= 4; i++) {
    console.log(`📤 Sending update ${i}/4 with HR: ${heartRate} BPM`);

    const data = {
      accelX: "0.0",
      accelY: "0.0",
      accelZ: "9.8",
      ambientTemp: "30.0",
      battPerc: 95,
      bodyTemp: 37.8, // Slightly elevated for severe
      gyroX: "0.0",
      gyroY: "0.0",
      gyroZ: "0.0",
      heartRate: heartRate,
      pitch: "0.0",
      roll: 0,
      spo2: 94, // Slightly lower for severe
      timestamp: new Date().toISOString().replace("T", " ").slice(0, 19),
      worn: 1,
      fcmToken: "CZZfrUKQ2WMEATCG6qfLX-AP49blcAa8YrxS_9YKK4jA6d0zs",
    };

    try {
      await deviceRef.set(data);
      console.log(
        `✅ Update ${i} sent successfully at ${new Date().toLocaleTimeString()}`
      );

      if (i < 4) {
        console.log("⏳ Waiting 10 seconds for next update...");
        await new Promise((resolve) => setTimeout(resolve, 10000));
      }
    } catch (error) {
      console.error(`❌ Error sending update ${i}:`, error);
    }
  }

  console.log("");
  console.log("🎯 SEVERE TEST COMPLETE!");
  console.log("════════════════════════");
  console.log("🔍 Expected result:");
  console.log("• You should receive a SEVERE anxiety notification");
  console.log("• Notification should have red color/severe sound");
  console.log("• Check your notification panel");
  console.log("");

  process.exit(0);
}

testSevereAnxiety().catch(console.error);
