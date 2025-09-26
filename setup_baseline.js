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

async function setupProperBaseline() {
  console.log("🔧 SETTING UP PROPER BASELINE DATA...");
  console.log("═".repeat(45));

  try {
    // Get device assignment
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const userId = assignment.val().assignedUser || assignment.val().userId;
    console.log("👤 User ID:", userId);

    // Set proper baseline data
    const properBaseline = {
      restingHeartRate: 73.2, // Proper resting HR
      lastUpdated: Date.now(),
      dataPoints: 100, // Sufficient data points
      createdBy: "test_setup",
      validated: true,
      note: "Baseline for anxiety detection testing - matches device assignment data",
    };

    await db.ref(`/users/${userId}/baseline`).set(properBaseline);
    console.log("✅ Set baseline resting HR: 73.2 BPM");

    // Also ensure the assignment has baseline data
    await db
      .ref(`/devices/AnxieEase001/assignment/supabaseSync/baselineHR`)
      .set(73.2);
    console.log("✅ Updated assignment baseline HR: 73.2 BPM");

    console.log("\n✅ BASELINE SETUP COMPLETE!");
    console.log("Now anxiety detection should work with:");
    console.log("• Mild: 91+ BPM (24% above 73.2)");
    console.log("• Moderate: 95+ BPM (30% above 73.2)");
    console.log("• Severe: 110+ BPM (50% above 73.2)");
    console.log("• Critical: 130+ BPM (78% above 73.2)");
  } catch (error) {
    console.error("❌ Error setting up baseline:", error);
  }
}

setupProperBaseline().catch(console.error);
