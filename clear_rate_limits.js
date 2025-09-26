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

async function clearRateLimits() {
  console.log("🧹 CLEARING RATE LIMITS FOR TESTING...");
  console.log("═".repeat(50));

  try {
    // Get user ID from device assignment
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    if (!assignment.exists()) {
      console.log("❌ No device assignment found");
      return;
    }

    const userId = assignment.val().assignedUser || assignment.val().userId;
    console.log("👤 Clearing rate limits for user:", userId);

    // Clear all rate limit data
    await db.ref(`/rateLimits/${userId}`).remove();
    await db.ref(`/rate_limits/AnxieEase001`).remove();

    console.log("✅ Rate limits cleared successfully!");
    console.log("🎉 You can now test all severity levels immediately!");

    console.log("\n📋 TESTING RECOMMENDATIONS:");
    console.log("─".repeat(30));
    console.log("1. 🟡 Test mild: node test_mild_anxiety.js");
    console.log("2. 🟠 Test moderate: node test_moderate_anxiety.js");
    console.log("3. 🔴 Test critical: node test_critical_anxiety.js");
    console.log("4. Each test runs for 45-60 seconds");
    console.log("5. Wait 10 seconds between different tests");
  } catch (error) {
    console.error("❌ Error clearing rate limits:", error);
  }
}

clearRateLimits().catch(console.error);
