// SIMPLIFIED MOVEMENT DATA CHECKER
// Check if your device sends movement/accelerometer data

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

async function checkMovementData() {
  console.log("🔍 CHECKING FOR MOVEMENT DATA IN YOUR DEVICE");
  console.log("===========================================\n");

  try {
    // Check current device data
    const currentRef = db.ref("/devices/AnxieEase001/current");
    const currentSnapshot = await currentRef.once("value");

    if (currentSnapshot.exists()) {
      const currentData = currentSnapshot.val();

      console.log("📱 CURRENT DEVICE DATA:");
      console.log("=======================");
      console.log("Available fields:");
      Object.keys(currentData).forEach((key) => {
        console.log(`   ${key}: ${currentData[key]}`);
      });

      // Check for movement-related fields
      const movementFields = [
        "movementLevel",
        "movement",
        "accelerometer",
        "accelerometerX",
        "accelerometerY",
        "accelerometerZ",
        "gyroscope",
        "steps",
      ];

      console.log("\n🏃 MOVEMENT DATA CHECK:");
      console.log("=======================");

      let hasMovementData = false;
      movementFields.forEach((field) => {
        if (currentData[field] !== undefined) {
          console.log(`✅ ${field}: ${currentData[field]}`);
          hasMovementData = true;
        } else {
          console.log(`❌ ${field}: Not found`);
        }
      });

      console.log("\n🎯 ANALYSIS:");
      console.log("============");

      if (hasMovementData) {
        console.log("✅ Your device DOES send movement data!");
        console.log("✅ Exercise detection should work");
        console.log("✅ Tremor/restlessness detection available");
      } else {
        console.log("❌ No movement data detected");
        console.log("⚠️  Current anxiety detection is HEART RATE ONLY");
        console.log("⚠️  Cannot distinguish exercise from anxiety");
        console.log("⚠️  Walking/stairs might trigger false alerts");
      }

      console.log("\n🧠 ANXIETY DETECTION BEHAVIOR:");
      console.log("===============================");

      const heartRate = currentData.heartRate || 0;
      const baseline = 73.9; // Your correct baseline after fix

      console.log(`Current HR: ${heartRate} BPM`);
      console.log(`Your Baseline: ${baseline} BPM`);
      console.log(`Difference: +${(heartRate - baseline).toFixed(1)} BPM`);

      if (heartRate >= baseline + 15) {
        console.log("🚨 WOULD TRIGGER: Heart rate above anxiety threshold!");
        if (!hasMovementData) {
          console.log("⚠️  No movement context - could be exercise!");
        }
      } else if (heartRate >= baseline + 10) {
        console.log("⚡ ELEVATED: Close to anxiety threshold");
      } else {
        console.log("✅ NORMAL: Within healthy range");
      }
    } else {
      console.log("❌ No current device data found");
    }

    console.log("\n💡 RECOMMENDATIONS:");
    console.log("====================");
    console.log("1. Test anxiety alerts during different activities");
    console.log("2. Note false positives during exercise");
    console.log("3. If no movement data: Consider it pure HR monitoring");
    console.log("4. Real anxiety = high HR while resting/sitting");
  } catch (error) {
    console.error("❌ Error:", error.message);
  }
}

checkMovementData();
