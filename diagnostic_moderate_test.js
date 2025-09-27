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

async function diagnosticTest() {
  console.log("🔍 DIAGNOSTIC TEST - MODERATE ANXIETY");
  console.log("═════════════════════════════════════");
  console.log("🎯 Goal: Send EXACTLY 100 BPM for 40 seconds");
  console.log("📊 100 BPM = 36.6% above 73.2 baseline = MODERATE");
  console.log("⏱️  Will send 4 updates, 10 seconds apart");
  console.log("📡 Using device: AnxieEase001");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const heartRate = 100; // Fixed heart rate for consistent testing

  for (let i = 1; i <= 4; i++) {
    console.log(`📤 Sending update ${i}/4: HR=${heartRate} BPM`);
    
    const data = {
      accelX: "0.0",
      accelY: "0.0", 
      accelZ: "9.8",
      ambientTemp: "30.0",
      battPerc: 95,
      bodyTemp: 37.2,
      gyroX: "0.0",
      gyroY: "0.0",
      gyroZ: "0.0",
      heartRate: heartRate,
      pitch: "0.0",
      roll: 0,
      spo2: 97,
      timestamp: new Date().toISOString().replace("T", " ").slice(0, 19),
      worn: 1,
      fcmToken: "CZZfrUKQ2WMEATCG6qfLX-AP49blcAa8YrxS_9YKK4jA6d0zs",
    };

    try {
      await deviceRef.set(data);
      console.log(`✅ Update ${i} sent successfully at ${new Date().toLocaleTimeString()}`);
      
      if (i < 4) {
        console.log("⏳ Waiting 10 seconds for next update...");
        await new Promise(resolve => setTimeout(resolve, 10000));
      }
    } catch (error) {
      console.error(`❌ Error sending update ${i}:`, error);
    }
  }
  
  console.log("");
  console.log("🎯 DIAGNOSTIC COMPLETE!");
  console.log("═══════════════════════");
  console.log("🔍 What to check:");
  console.log("1. Did you receive a MODERATE anxiety notification?");
  console.log("2. Check Firebase Console for function execution");
  console.log("3. Check if device assignment exists");
  console.log("4. Check if user baseline exists");
  console.log("");
  console.log("📊 Expected behavior:");
  console.log(`• Heart Rate: ${heartRate} BPM`);
  console.log(`• Percentage above baseline: ${((heartRate - 73.2) / 73.2 * 100).toFixed(1)}%`);
  console.log("• Should classify as: MODERATE");
  console.log("• Should trigger: 🟠 Moderate Anxiety Alert");
  
  process.exit(0);
}

diagnosticTest().catch(console.error);