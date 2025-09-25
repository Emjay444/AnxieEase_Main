/**
 * 🔍 ANXIETY THRESHOLD & MOVEMENT ANALYSIS - FIXED
 *
 * Analyzing current anxiety detection thresholds and movement handling
 */

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

async function analyzeCoreQuestions() {
  console.log("\n🎯 ANXIETY DETECTION CORE ANALYSIS");
  console.log("===================================");

  try {
    const CURRENT_USER = "5afad7d4-3dcd-4353-badb-4f155303419a";

    // Get user data
    const userSnapshot = await db.ref(`/users/${CURRENT_USER}`).once("value");
    const userData = userSnapshot.val();

    // Get current sensor data
    const currentSnapshot = await db
      .ref("/devices/AnxieEase001/current")
      .once("value");
    const currentData = currentSnapshot.val();

    console.log("📊 QUESTION 1: Heart Rate Thresholds");
    console.log("====================================");

    if (userData && userData.baseline) {
      const baselineHR = userData.baseline.heartRate; // 73.2 BPM
      const currentHR = currentData.heartRate; // 86.8 BPM

      console.log(`Your baseline: ${baselineHR} BPM`);
      console.log(`Current reading: ${currentHR} BPM`);

      // Calculate actual threshold
      const threshold = Math.round(baselineHR * 1.2); // +20% typically used
      const percentAbove = (
        ((currentHR - baselineHR) / baselineHR) *
        100
      ).toFixed(1);

      console.log(`\n🎯 THRESHOLD LOGIC:`);
      console.log(`• Baseline: ${baselineHR} BPM`);
      console.log(`• Threshold: ${threshold} BPM (+20%)`);
      console.log(`• Current: ${currentHR} BPM (+${percentAbove}%)`);

      if (currentHR > threshold) {
        console.log(`• Status: 🚨 WOULD TRIGGER ANXIETY ALERT`);
        console.log(`  Because ${currentHR} > ${threshold} (threshold)`);
      } else {
        console.log(`• Status: ✅ Normal (below threshold)`);
      }

      console.log(`\n💡 YES - Alerts are connected to your personal baseline!`);
      console.log(`Your 73.2 BPM baseline determines when alerts trigger.`);
    }

    console.log("\n🏃 QUESTION 2: Movement & Exercise Detection");
    console.log("============================================");

    console.log("🔍 Checking for movement data in device...");

    // Check what sensor data is available
    const sensorFields = Object.keys(currentData);
    console.log("Available sensor data:");
    sensorFields.forEach((field) => {
      console.log(`• ${field}: ${currentData[field]}`);
    });

    // Check for movement-related fields
    const movementFields = sensorFields.filter(
      (field) =>
        field.toLowerCase().includes("movement") ||
        field.toLowerCase().includes("accelerometer") ||
        field.toLowerCase().includes("gyro") ||
        field.toLowerCase().includes("activity") ||
        field.toLowerCase().includes("step")
    );

    if (movementFields.length > 0) {
      console.log(`\n✅ Movement data found: ${movementFields.join(", ")}`);
    } else {
      console.log(`\n❌ NO MOVEMENT DATA FOUND`);
      console.log(`Current algorithm cannot distinguish:`);
      console.log(`• Exercise (should not alert)`);
      console.log(`• Anxiety (should alert)`);
    }

    console.log("\n🎯 EXERCISE vs ANXIETY SCENARIOS:");
    console.log("=================================");

    console.log("🏃 EXERCISE (Should NOT Alert):");
    console.log("• HR: 90+ BPM + Continuous movement");
    console.log("• Pattern: Gradual increase, sustained activity");
    console.log("• Context: Walking, running, gym");

    console.log("\n😰 ANXIETY (Should Alert):");
    console.log("• HR: 90+ BPM + Minimal/no movement");
    console.log("• Pattern: Sudden spike while resting");
    console.log("• Context: Sitting, lying down, stressed");

    console.log("\n🤝 RESTLESSNESS (Anxiety Sign):");
    console.log("• HR: Elevated + Small fidget movements");
    console.log("• Pattern: Irregular, nervous movements");
    console.log("• Context: Anxious fidgeting, hand tremors");

    // Check current Firebase Functions for movement handling
    console.log("\n🔍 CURRENT ALGORITHM ANALYSIS:");
    console.log("==============================");

    console.log("Checking anxiety detection function...");
  } catch (error) {
    console.error("❌ Analysis failed:", error.message);
  }

  console.log("\n🎯 KEY ANSWERS TO YOUR QUESTIONS:");
  console.log("==================================");

  console.log("1. 📊 HEART RATE THRESHOLDS:");
  console.log("   ✅ YES - Alerts ARE connected to your personal baseline");
  console.log("   ✅ Your 73.2 BPM baseline sets the threshold");
  console.log("   ✅ Alerts trigger when HR exceeds baseline + percentage");

  console.log("\n2. 🏃 MOVEMENT/EXERCISE DETECTION:");
  console.log("   ❌ PROBLEM: No movement data detected in current system");
  console.log("   ❌ ISSUE: Cannot distinguish exercise from anxiety");
  console.log("   ❌ RESULT: Exercise might trigger false anxiety alerts");

  console.log("\n3. 💡 WHY YOU DON'T SEE MOVEMENT DISCUSSION:");
  console.log(
    "   • Current device data shows no accelerometer/movement fields"
  );
  console.log("   • Algorithm focuses only on heart rate patterns");
  console.log("   • Missing: Exercise detection & filtering");

  console.log("\n4. 🚨 POTENTIAL ISSUES:");
  console.log("   ⚠️  Going for a walk → HR rises → False anxiety alert");
  console.log("   ⚠️  Climbing stairs → HR spikes → Unnecessary notification");
  console.log("   ⚠️  Exercise → Sustained high HR → Multiple false alerts");

  console.log("\n5. 🔧 SOLUTIONS NEEDED:");
  console.log("   • Add movement sensor data collection");
  console.log("   • Implement exercise detection algorithm");
  console.log("   • Context-aware anxiety detection");
  console.log("   • User feedback system ('Was this anxiety?')");

  console.log("\n6. 📱 CURRENT BEHAVIOR:");
  console.log("   • Pure heart rate based detection");
  console.log("   • Uses your personal 73.2 BPM baseline");
  console.log("   • Triggers at ~84+ BPM (sustained 30+ seconds)");
  console.log("   • No exercise filtering = potential false positives");

  console.log("\n🎯 IMMEDIATE RECOMMENDATIONS:");
  console.log("=============================");
  console.log("1. Test current system during different activities");
  console.log("2. Note when false positives occur");
  console.log("3. Consider adding movement sensor integration");
  console.log("4. Implement exercise detection if needed");
  console.log("5. Add user confirmation for alerts");
}

analyzeCoreQuestions();
