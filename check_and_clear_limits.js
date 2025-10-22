/**
 * Check and Clear Rate Limits
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();
const TEST_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";

async function checkAndClearRateLimits() {
  console.log("🔍 Checking Rate Limits for User:", TEST_USER_ID);
  console.log("=".repeat(60));

  try {
    // Check persistent rate limit
    const lastNotifSnapshot = await db
      .ref(`/users/${TEST_USER_ID}/lastAnxietyNotification`)
      .once("value");

    if (lastNotifSnapshot.exists()) {
      const lastNotifTime = lastNotifSnapshot.val();
      const timeSince = Date.now() - lastNotifTime;
      const minutesSince = Math.floor(timeSince / 1000 / 60);
      const secondsSince = Math.floor(timeSince / 1000);

      console.log("\n📍 PERSISTENT RATE LIMIT:");
      console.log(
        `   Last notification: ${new Date(lastNotifTime).toLocaleString()}`
      );
      console.log(`   Time since: ${minutesSince}m ${secondsSince % 60}s ago`);
      console.log(`   Cooldown: 5 minutes`);

      if (timeSince < 5 * 60 * 1000) {
        const remainingSeconds = Math.ceil((5 * 60 * 1000 - timeSince) / 1000);
        console.log(`   ⏳ BLOCKING: ${remainingSeconds}s remaining`);
      } else {
        console.log(`   ✅ READY: Cooldown passed`);
      }
    } else {
      console.log("\n📍 PERSISTENT RATE LIMIT:");
      console.log("   ✅ No rate limit found - ready to send");
    }

    // Check enhanced rate limits
    const rateLimitsSnapshot = await db
      .ref(`/rateLimits/${TEST_USER_ID}`)
      .once("value");

    if (rateLimitsSnapshot.exists()) {
      const rateLimits = rateLimitsSnapshot.val();
      console.log("\n📍 ENHANCED RATE LIMITS:");

      Object.keys(rateLimits).forEach((severity) => {
        const limit = rateLimits[severity];
        const nextAllowed = limit.nextAllowedTime || 0;
        const now = Date.now();

        if (nextAllowed > now) {
          const remainingSeconds = Math.ceil((nextAllowed - now) / 1000);
          console.log(
            `   ${severity}: ⏳ BLOCKING (${remainingSeconds}s remaining)`
          );
        } else {
          console.log(`   ${severity}: ✅ READY`);
        }
      });
    } else {
      console.log("\n📍 ENHANCED RATE LIMITS:");
      console.log("   ✅ No enhanced rate limits found - ready to send");
    }

    // Now clear everything
    console.log("\n" + "=".repeat(60));
    console.log("🧹 CLEARING ALL RATE LIMITS...\n");

    await db.ref(`/users/${TEST_USER_ID}/lastAnxietyNotification`).remove();
    console.log("✅ Persistent rate limit cleared");

    await db.ref(`/rateLimits/${TEST_USER_ID}`).remove();
    console.log("✅ Enhanced rate limits cleared");

    console.log("\n" + "=".repeat(60));
    console.log("✅ ALL RATE LIMITS CLEARED!");
    console.log(
      "\n💡 Now rebuilding and deploying the function with correct region..."
    );
    console.log("   This will fix the cross-region trigger issue");

    process.exit(0);
  } catch (error) {
    console.error("\n❌ Error:", error);
    process.exit(1);
  }
}

checkAndClearRateLimits();
