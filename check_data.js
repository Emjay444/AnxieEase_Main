const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function checkCurrentData() {
  console.log("🔍 CHECKING CURRENT FIREBASE DATA");
  console.log("═".repeat(40));

  try {
    const currentRef = await db
      .ref("/devices/AnxieEase001/current")
      .once("value");
    const current = currentRef.val();

    console.log("📊 Current Device Data:");
    if (current) {
      console.log(`Heart Rate: ${current.heartRate || "Missing"} BPM`);
      console.log(`SpO2: ${current.spo2 || "Missing"}%`);
      console.log(`Temperature: ${current.temperature || "Missing"}°C`);
      console.log(`Timestamp: ${new Date(current.timestamp).toLocaleString()}`);
      console.log(`Complete Data:`, current);
    } else {
      console.log("❌ No current data found");
    }
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

checkCurrentData().then(() => process.exit(0));
