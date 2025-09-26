const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxiease-main-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function analyzeUserNodes() {
  console.log("🔍 FIREBASE USER NODES ANALYSIS");
  console.log("=".repeat(50));

  const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
  const sessionId = "session_1758850736983";

  try {
    // Check 1: User baseline
    console.log("\n📊 1. USER BASELINE:");
    const baselineRef = db.ref(`/users/${userId}/baseline`);
    const baselineSnapshot = await baselineRef.once("value");

    if (baselineSnapshot.exists()) {
      const baseline = baselineSnapshot.val();
      console.log("✅ EXISTS:", JSON.stringify(baseline, null, 2));
    } else {
      console.log("❌ MISSING: /users/{userId}/baseline");
      console.log(
        "   Purpose: Personalized heart rate thresholds for anxiety detection"
      );
    }

    // Check 2: User session data
    console.log("\n📋 2. USER SESSION METADATA:");
    const sessionMetaRef = db.ref(
      `/users/${userId}/sessions/${sessionId}/metadata`
    );
    const sessionMetaSnapshot = await sessionMetaRef.once("value");

    if (sessionMetaSnapshot.exists()) {
      const sessionMeta = sessionMetaSnapshot.val();
      console.log("✅ EXISTS:", JSON.stringify(sessionMeta, null, 2));
    } else {
      console.log("❌ MISSING: /users/{userId}/sessions/{sessionId}/metadata");
      console.log("   Purpose: Track user session details and statistics");
    }

    // Check 3: User session history
    console.log("\n📈 3. USER SESSION HISTORY:");
    const sessionHistoryRef = db.ref(
      `/users/${userId}/sessions/${sessionId}/history`
    );
    const sessionHistorySnapshot = await sessionHistoryRef.once("value");

    if (sessionHistorySnapshot.exists()) {
      const history = sessionHistorySnapshot.val();
      const historyCount = Object.keys(history).length;
      console.log(`✅ EXISTS: ${historyCount} history entries`);
      console.log("   Latest entries:", Object.keys(history).slice(-3));
    } else {
      console.log("❌ MISSING: /users/{userId}/sessions/{sessionId}/history");
      console.log(
        "   Purpose: User-specific sensor data for privacy & analytics"
      );
    }

    // Check 4: User alerts
    console.log("\n🚨 4. USER ANXIETY ALERTS:");
    const alertsRef = db.ref(`/alerts/${userId}`);
    const alertsSnapshot = await alertsRef.once("value");

    if (alertsSnapshot.exists()) {
      const alerts = alertsSnapshot.val();
      const alertCount = Object.keys(alerts).length;
      console.log(`✅ EXISTS: ${alertCount} alerts found`);
    } else {
      console.log("❌ MISSING: /alerts/{userId}");
      console.log("   Purpose: Anxiety detection results and notifications");
    }

    // Check 5: FCM Token
    console.log("\n📱 5. FCM TOKEN:");
    const fcmRef = db.ref(`/users/${userId}/fcmToken`);
    const fcmSnapshot = await fcmRef.once("value");

    if (fcmSnapshot.exists()) {
      const token = fcmSnapshot.val();
      console.log(`✅ EXISTS: ${token.substring(0, 20)}...`);
    } else {
      console.log("❌ MISSING: /users/{userId}/fcmToken");
      console.log("   Purpose: Push notifications delivery");
    }

    // Check 6: User sessions list
    console.log("\n📂 6. ALL USER SESSIONS:");
    const allSessionsRef = db.ref(`/users/${userId}/sessions`);
    const allSessionsSnapshot = await allSessionsRef.once("value");

    if (allSessionsSnapshot.exists()) {
      const sessions = allSessionsSnapshot.val();
      const sessionCount = Object.keys(sessions).length;
      console.log(`✅ EXISTS: ${sessionCount} sessions found`);
      Object.keys(sessions).forEach((sid, index) => {
        console.log(`   ${index + 1}. ${sid}`);
      });
    } else {
      console.log("❌ MISSING: /users/{userId}/sessions");
      console.log("   Purpose: Track all user sessions across time");
    }

    console.log("\n🎯 SCHEMA HEALTH SUMMARY:");
    console.log("=".repeat(50));
  } catch (error) {
    console.error("❌ Error analyzing user nodes:", error.message);
  }
}

analyzeUserNodes().catch(console.error);
