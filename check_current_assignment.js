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

async function checkCurrentAssignment() {
  console.log("🔍 CHECKING DEVICE AnxieEase001 ASSIGNMENT");
  console.log("═".repeat(50));

  try {
    // Check current assignment
    const assignmentSnapshot = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const assignment = assignmentSnapshot.val();

    if (!assignment) {
      console.log("❌ No assignment found for AnxieEase001");
      return;
    }

    console.log("📋 Current Assignment:");
    console.log(`   User ID: ${assignment.userId}`);
    console.log(`   Session ID: ${assignment.sessionId}`);
    console.log(`   Status: ${assignment.status}`);
    console.log(
      `   Assigned: ${new Date(assignment.assignedAt).toLocaleString()}`
    );

    // Check user's baseline
    const userSnapshot = await db
      .ref(`/users/${assignment.userId}/baseline`)
      .once("value");
    const baseline = userSnapshot.val();

    if (baseline) {
      console.log("\n💓 User Baseline Data:");
      console.log(`   Resting HR: ${baseline.restingHeartRate} BPM`);
      console.log(
        `   Created: ${new Date(baseline.createdAt).toLocaleString()}`
      );

      // Calculate threshold estimates
      const restingHR = baseline.restingHeartRate;
      console.log("\n🎯 Estimated Anxiety Thresholds:");
      console.log(
        `   Mild:     ${Math.round(restingHR * 1.15)} - ${Math.round(
          restingHR * 1.25
        )} BPM`
      );
      console.log(
        `   Moderate: ${Math.round(restingHR * 1.25)} - ${Math.round(
          restingHR * 1.35
        )} BPM`
      );
      console.log(
        `   Severe:   ${Math.round(restingHR * 1.35)} - ${Math.round(
          restingHR * 1.45
        )} BPM`
      );
      console.log(`   Critical: ${Math.round(restingHR * 1.45)}+ BPM`);
    }

    // Check current device data
    const currentSnapshot = await db
      .ref("/devices/AnxieEase001/current")
      .once("value");
    const current = currentSnapshot.val();

    if (current) {
      console.log("\n📊 Current Device Data:");
      console.log(`   Heart Rate: ${current.heartRate} BPM`);
      console.log(`   Temperature: ${current.temperature}°C`);
      console.log(`   GSR: ${current.gsr}`);
      console.log(
        `   Last Update: ${new Date(current.timestamp).toLocaleString()}`
      );
    }
  } catch (error) {
    console.error("❌ Error checking assignment:", error);
  }
}

checkCurrentAssignment()
  .then(() => {
    console.log("\n✅ Assignment check complete");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Script failed:", error);
    process.exit(1);
  });
