// Test anxiety detection logic locally without Firebase Functions
const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin locally
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

// Import the anxiety detection logic
// const { analyzeMultiParameterAnxiety } = require('./functions/lib/multiParameterAnxietyDetection');

// For now, let's just test the current data and see what's happening
async function testCurrentData() {
  console.log("🧪 TESTING ANXIETY DETECTION LOGIC");
  console.log("═".repeat(50));

  try {
    // Get the current device data from Firebase
    const currentDataRef = await db
      .ref("/devices/AnxieEase001/current")
      .once("value");
    const currentData = currentDataRef.val();

    console.log("📊 Current Device Data:");
    console.log(JSON.stringify(currentData, null, 2));

    if (!currentData || !currentData.heartRate) {
      console.log("❌ No current data found");
      return;
    }

    // Check if we have assignment and user data
    const assignmentRef = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const assignment = assignmentRef.val();

    if (!assignment || !assignment.userId) {
      console.log("❌ No user assignment found");
      return;
    }

    console.log(`👤 Assigned User: ${assignment.userId}`);

    // Get user's baseline
    const baselineRef = await db
      .ref(`/users/${assignment.userId}/baseline`)
      .once("value");
    const baseline = baselineRef.val();

    if (!baseline || !baseline.restingHeartRate) {
      console.log("❌ No baseline found for user");
      return;
    }

    // Test if data would trigger thresholds
    const heartRate = currentData.heartRate;
    const restingHR = baseline.restingHeartRate;
    const elevation = heartRate - restingHR;
    const percentage = (elevation / restingHR) * 100;

    console.log("\n🎯 THRESHOLD ANALYSIS:");
    console.log("─".repeat(30));
    console.log(`Current HR: ${heartRate} BPM`);
    console.log(`Baseline: ${restingHR} BPM`);
    console.log(`Elevation: +${elevation.toFixed(1)} BPM`);
    console.log(`Percentage: +${percentage.toFixed(1)}%`);

    // Check thresholds based on the code we analyzed
    const basicThreshold = restingHR * 1.2; // 20% above
    const veryHighThreshold = restingHR * 1.3; // 30% above
    const mildLevel = restingHR + 15; // +15 BPM
    const moderateLevel = restingHR + 25; // +25 BPM
    const severeLevel = restingHR + 35; // +35 BPM

    console.log("\n� THRESHOLD CHECKS:");
    console.log(
      `Basic (20%): ${basicThreshold.toFixed(1)} BPM - ${
        heartRate >= basicThreshold ? "✅ TRIGGERED" : "❌ Not triggered"
      }`
    );
    console.log(
      `Very High (30%): ${veryHighThreshold.toFixed(1)} BPM - ${
        heartRate >= veryHighThreshold ? "✅ TRIGGERED" : "❌ Not triggered"
      }`
    );
    console.log(
      `Mild Level: ${mildLevel.toFixed(1)} BPM - ${
        heartRate >= mildLevel ? "✅ TRIGGERED" : "❌ Not triggered"
      }`
    );
    console.log(
      `Moderate Level: ${moderateLevel.toFixed(1)} BPM - ${
        heartRate >= moderateLevel ? "✅ TRIGGERED" : "❌ Not triggered"
      }`
    );
    console.log(
      `Severe Level: ${severeLevel.toFixed(1)} BPM - ${
        heartRate >= severeLevel ? "✅ TRIGGERED" : "❌ Not triggered"
      }`
    );

    // Check if SpO2 exists (required field)
    console.log("\n🫁 DATA VALIDATION:");
    console.log(
      `SpO2 present: ${
        currentData.spo2 ? "✅ Yes (" + currentData.spo2 + "%)" : "❌ Missing"
      }`
    );
    console.log(
      `Temperature present: ${
        currentData.temperature
          ? "✅ Yes (" + currentData.temperature + "°C)"
          : "❌ Missing"
      }`
    );
    console.log(
      `Movement data: ${
        currentData.accelX !== undefined ? "✅ Present" : "❌ Missing"
      }`
    );

    if (!currentData.spo2) {
      console.log("\n🚨 ISSUE FOUND: SpO2 data is missing!");
      console.log(
        "The Cloud Function requires both heartRate AND spo2 fields."
      );
      console.log(
        'Without spo2, the function will exit early with "Missing required metrics data"'
      );
    }
  } catch (error) {
    console.error("❌ Error testing data:", error);
  }
}

testCurrentData()
  .then(() => {
    console.log("\n🏁 Test completed");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Test failed:", error);
    process.exit(1);
  });
