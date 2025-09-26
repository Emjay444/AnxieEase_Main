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

async function checkBaselineData() {
  console.log("📊 CHECKING BASELINE DATA...");
  console.log("═".repeat(40));

  try {
    // Get device assignment
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    if (!assignment.exists()) {
      console.log("❌ No device assignment found");
      return;
    }

    const userId = assignment.val().assignedUser || assignment.val().userId;
    console.log("👤 User ID:", userId);

    // Check baseline data
    const baselineRef = db.ref(`/users/${userId}/baseline`);
    const baseline = await baselineRef.once("value");

    if (baseline.exists()) {
      console.log("✅ User baseline found:");
      const data = baseline.val();
      console.log("   Resting HR:", data.restingHeartRate || "Not set");
      console.log(
        "   Last updated:",
        data.lastUpdated ? new Date(data.lastUpdated).toLocaleString() : "Never"
      );
      console.log("   Data points:", data.dataPoints || "None");
    } else {
      console.log("❌ No baseline data found - CREATING DEFAULT BASELINE");

      // Create baseline data
      const defaultBaseline = {
        restingHeartRate: 73.2, // From your assignment data
        lastUpdated: Date.now(),
        dataPoints: 50, // Minimum for detection
        createdBy: "test_setup",
        note: "Default baseline for testing anxiety detection",
      };

      await baselineRef.set(defaultBaseline);
      console.log("✅ Created baseline with resting HR: 73.2 BPM");
    }

    // Check user session history
    console.log("\n📈 Checking user session history...");
    const historyRef = db.ref(`/users/${userId}/sensors/session_history`);
    const history = await historyRef.once("value");

    if (history.exists()) {
      const historyData = history.val();
      const entries = Object.keys(historyData).length;
      console.log(`✅ Found ${entries} session history entries`);

      // Show latest entry
      const latestKey = Object.keys(historyData).sort().pop();
      const latest = historyData[latestKey];
      console.log(
        "   Latest entry:",
        new Date(latest.timestamp).toLocaleString()
      );
      console.log("   Latest HR:", latest.heartRate, "BPM");
    } else {
      console.log("❌ No session history found - will build during testing");
    }
  } catch (error) {
    console.error("❌ Error checking baseline:", error);
  }
}

checkBaselineData().catch(console.error);
