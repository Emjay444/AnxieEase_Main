const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

async function checkDeviceAssignment() {
  try {
    console.log("🔍 Checking existing device assignment for AnxieEase001...\n");

    // Check device assignment
    const assignmentRef = admin
      .database()
      .ref("/devices/AnxieEase001/assignment");
    const assignmentSnapshot = await assignmentRef.once("value");

    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      console.log("📱 Current device assignment:");
      console.log(`   Assigned User: ${assignment.assignedUser || "Not set"}`);
      console.log(
        `   Active Session: ${assignment.activeSessionId || "Not set"}`
      );
      console.log(
        `   Assigned At: ${
          assignment.assignedAt
            ? new Date(assignment.assignedAt).toLocaleString()
            : "Not set"
        }`
      );
      console.log(`   Status: ${assignment.status || "Not set"}\n`);

      // If user is assigned, check their baseline
      if (assignment.assignedUser) {
        const userId = assignment.assignedUser;
        console.log(`👤 Checking baseline for user: ${userId}`);

        const baselineRef = admin
          .database()
          .ref(`/users/${userId}/profile/baseline`);
        const baselineSnapshot = await baselineRef.once("value");

        if (baselineSnapshot.exists()) {
          const baseline = baselineSnapshot.val();
          console.log("💓 User baseline found:");
          console.log(
            `   Baseline HR: ${baseline.baselineHR || "Not set"} BPM`
          );
          console.log(
            `   Calculated At: ${
              baseline.calculatedAt
                ? new Date(baseline.calculatedAt).toLocaleString()
                : "Not set"
            }`
          );
          console.log(`   Sample Count: ${baseline.sampleCount || "Not set"}`);
          console.log(`   Confidence: ${baseline.confidence || "Not set"}%`);
        } else {
          console.log("❌ No baseline found for this user");
        }
      }
    } else {
      console.log("❌ No assignment found for device AnxieEase001");
      console.log(
        "💡 Device needs to be assigned to a user for sustained detection to work"
      );
    }

    process.exit(0);
  } catch (error) {
    console.error("❌ Error checking device assignment:", error);
    process.exit(1);
  }
}

checkDeviceAssignment();
