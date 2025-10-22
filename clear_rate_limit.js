/**
 * Clear Rate Limiting Script
 * Clears all rate limiting for testing purposes
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
  console.log("✅ Firebase Admin initialized\n");
}

const db = admin.database();

const TEST_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";

async function clearRateLimits() {
  console.log("🧹 Clearing All Rate Limits\n");
  console.log("=".repeat(60));

  try {
    // 1. Clear persistent rate limit
    console.log("\n1️⃣ Clearing persistent rate limit...");
    await db.ref(`/users/${TEST_USER_ID}/lastAnxietyNotification`).remove();
    console.log("✅ Persistent rate limit cleared");

    // 2. Clear enhanced rate limits
    console.log("\n2️⃣ Clearing enhanced rate limits...");
    const rateLimitsSnapshot = await db
      .ref(`/rateLimits/${TEST_USER_ID}`)
      .once("value");

    if (rateLimitsSnapshot.exists()) {
      await db.ref(`/rateLimits/${TEST_USER_ID}`).remove();
      console.log("✅ Enhanced rate limits cleared");
    } else {
      console.log("ℹ️ No enhanced rate limits found");
    }

    console.log("\n" + "=".repeat(60));
    console.log("✅ All rate limits cleared!");
    console.log("\n💡 You can now test notifications immediately");
    console.log("   Run: node test_real_notifications.js direct mild\n");
  } catch (error) {
    console.error("\n❌ Error clearing rate limits:", error);
    process.exit(1);
  }

  process.exit(0);
}

clearRateLimits().catch((error) => {
  console.error("\n❌ Failed:", error);
  process.exit(1);
});
