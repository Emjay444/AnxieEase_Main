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

async function testCriticalAnxiety() {
  console.log("🚨 TESTING CRITICAL ANXIETY DETECTION");
  console.log("════════════════════════════════════");
  console.log("💓 Using heart rate: 140 BPM");
  console.log("📊 Expected severity: CRITICAL (91% above baseline of 73.2)");
  console.log("🎯 Should trigger CRITICAL notification with emergency alert");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const heartRate = 140; // 91% above baseline = CRITICAL
  
  console.log("🚀 Sending critical anxiety data...");
  console.log("");

  for (let i = 1; i <= 4; i++) {
    console.log(`📤 Sending update ${i}/4 with HR: ${heartRate} BPM`);
    
    const data = {
      accelX: "0.0",
      accelY: "0.0", 
      accelZ: "9.8",
      ambientTemp: "30.0",
      battPerc: 95,
      bodyTemp: 38.2,
      gyroX: "0.0",
      gyroY: "0.0",
      gyroZ: "0.0",
      heartRate: heartRate,
      pitch: "0.0",
      roll: 0,
      spo2: 92,
      timestamp: new Date().toISOString().replace("T", " ").slice(0, 19),
      worn: 1,
      fcmToken: "CZZfrUKQ2WMEATCG6qfLX-AP49blcAa8YrxS_9YKK4jA6d0zs",
    };

    try {
      await deviceRef.set(data);
      console.log(`✅ Update ${i} sent successfully`);
      
      if (i < 4) {
        console.log("⏳ Waiting 10 seconds for next update...");
        await new Promise(resolve => setTimeout(resolve, 10000));
      }
    } catch (error) {
      console.error(`❌ Error sending update ${i}:`, error);
    }
  }
  
  console.log("");
  console.log("🎯 CRITICAL TEST COMPLETE!");
  console.log("═══════════════════════════");
  console.log("✅ Expected: CRITICAL anxiety notification (dark red/emergency)");
  console.log("🔊 Expected: Critical alert sound");
  console.log("📱 Check your notification panel");
  console.log("");
  
  process.exit(0);
}

testCriticalAnxiety().catch(console.error);