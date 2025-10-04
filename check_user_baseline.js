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

async function checkUserBaseline() {
  try {
    const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
    console.log(`🔍 Checking baseline for user: ${userId}`);

    const baselineRef = admin
      .database()
      .ref(`/users/${userId}/profile/baseline`);
    const snapshot = await baselineRef.once("value");

    if (snapshot.exists()) {
      console.log("✅ User already has baseline:");
      const baseline = snapshot.val();
      console.log(`   Baseline HR: ${baseline.baselineHR} BPM`);
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
      console.log(
        "❌ User does not have baseline - will create one with 73.2 BPM"
      );
    }

    process.exit(0);
  } catch (error) {
    console.error("❌ Error:", error);
    process.exit(1);
  }
}

checkUserBaseline();
