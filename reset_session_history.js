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

async function resetSessionHistory() {
  console.log("🧹 RESETTING SESSION HISTORY FOR CLEAN TESTING...");
  console.log("═".repeat(50));

  try {
    // Get user ID and session
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    const userId = assignment.val().assignedUser;
    const sessionId = assignment.val().activeSessionId;

    console.log("👤 User ID:", userId);
    console.log("📋 Session ID:", sessionId);

    // Clear session history (keeps mixing old test data with new)
    await db.ref(`/users/${userId}/sessions/${sessionId}/history`).remove();
    console.log("✅ Cleared session history");

    // Also clear any device-level history
    await db.ref("/devices/AnxieEase001/history").remove();
    console.log("✅ Cleared device history");

    // Clear rate limits
    await db.ref(`/rateLimits/${userId}`).remove();
    await db.ref(`/rate_limits/AnxieEase001`).remove();
    console.log("✅ Cleared rate limits");

    console.log("\n🎉 CLEAN SLATE READY FOR TESTING!");
    console.log("═".repeat(40));
    console.log("✅ Now each test will start fresh without old data pollution");
    console.log("✅ Severity will be calculated from current test data only");
    console.log("✅ No rate limiting blocking notifications");

    console.log("\n📋 TESTING SEQUENCE:");
    console.log("1. Run one test: node test_mild_anxiety.js");
    console.log("2. Wait for notification and check severity");
    console.log("3. Run this script again before next test");
    console.log("4. Run next test for accurate severity detection");
  } catch (error) {
    console.error("❌ Error resetting session:", error);
  }
}

resetSessionHistory().catch(console.error);
