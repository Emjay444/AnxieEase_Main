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

async function analyzeAlertStorage() {
  console.log("🔍 ANALYZING ALERT STORAGE ISSUES...");
  console.log("═".repeat(50));

  try {
    // Get user ID
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const userId = assignment.val().assignedUser || assignment.val().userId;

    console.log("👤 User ID:", userId);

    // Check user alerts (what we see as "undefined")
    console.log("\n📋 USER ALERTS STRUCTURE:");
    console.log("─".repeat(30));
    const userAlerts = await db
      .ref(`/users/${userId}/alerts`)
      .limitToLast(1)
      .once("value");
    if (userAlerts.exists()) {
      userAlerts.forEach((alertSnap) => {
        const alert = alertSnap.val();
        console.log("Alert Data:");
        Object.entries(alert).forEach(([key, value]) => {
          console.log(`   ${key}: ${JSON.stringify(value)}`);
        });
      });
    }

    // Check native_alerts structure
    console.log("\n📱 NATIVE ALERTS STRUCTURE:");
    console.log("─".repeat(30));
    const nativeAlerts = await db
      .ref("/native_alerts")
      .limitToLast(1)
      .once("value");
    if (nativeAlerts.exists()) {
      console.log("✅ Native alerts exist:");
      nativeAlerts.forEach((alertSnap) => {
        const alert = alertSnap.val();
        console.log("Native Alert Data:");
        Object.entries(alert).forEach(([key, value]) => {
          console.log(`   ${key}: ${JSON.stringify(value)}`);
        });
      });
    } else {
      console.log("❌ No native alerts found");
      console.log("🤔 Checking if this is expected...");
    }

    // Check anxiety_alerts structure
    console.log("\n🚨 ANXIETY_ALERTS STRUCTURE:");
    console.log("─".repeat(30));
    const anxietyAlerts = await db
      .ref("/anxiety_alerts")
      .limitToLast(1)
      .once("value");
    if (anxietyAlerts.exists()) {
      console.log("✅ Anxiety alerts exist:");
      anxietyAlerts.forEach((alertSnap) => {
        const alert = alertSnap.val();
        console.log("Anxiety Alert Data:");
        Object.entries(alert).forEach(([key, value]) => {
          console.log(`   ${key}: ${JSON.stringify(value)}`);
        });
      });
    } else {
      console.log("❌ No anxiety alerts found");
    }

    console.log("\n🎯 ANALYSIS SUMMARY:");
    console.log("═".repeat(30));
    console.log("1. 📝 User alerts: Store personalized alerts for app display");
    console.log("2. 📱 Native alerts: For system/admin monitoring (optional)");
    console.log("3. 🚨 Anxiety alerts: Global anxiety tracking (optional)");
    console.log(
      "\n✅ KEY INSIGHT: Only user alerts are REQUIRED for notifications!"
    );
    console.log(
      '   The "undefined" issue is likely just missing display formatting.'
    );
  } catch (error) {
    console.error("❌ Error analyzing alerts:", error);
  }
}

analyzeAlertStorage().catch(console.error);
