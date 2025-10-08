const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

const db = admin.database();

const REAL_USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";
const DEVICE_ID = "AnxieEase001";

async function findBaseline() {
  console.log("🔍 Searching for baseline data...");

  try {
    // Check multiple possible locations for baseline
    console.log("\n1️⃣ Checking: /users/{userId}/baselines/{deviceId}");
    const baseline1 = await db
      .ref(`/users/${REAL_USER_ID}/baselines/${DEVICE_ID}`)
      .once("value");
    if (baseline1.exists()) {
      console.log("✅ Found baseline:", baseline1.val());
    } else {
      console.log("❌ No baseline found here");
    }

    console.log("\n2️⃣ Checking: /users/{userId}/baseline");
    const baseline2 = await db
      .ref(`/users/${REAL_USER_ID}/baseline`)
      .once("value");
    if (baseline2.exists()) {
      console.log("✅ Found baseline:", baseline2.val());
    } else {
      console.log("❌ No baseline found here");
    }

    console.log("\n3️⃣ Checking: /users/{userId}/profile/baseline");
    const baseline3 = await db
      .ref(`/users/${REAL_USER_ID}/profile/baseline`)
      .once("value");
    if (baseline3.exists()) {
      console.log("✅ Found baseline:", baseline3.val());
    } else {
      console.log("❌ No baseline found here");
    }

    console.log("\n4️⃣ Checking: /devices/{deviceId}/baseline");
    const baseline4 = await db
      .ref(`/devices/${DEVICE_ID}/baseline`)
      .once("value");
    if (baseline4.exists()) {
      console.log("✅ Found baseline:", baseline4.val());
    } else {
      console.log("❌ No baseline found here");
    }

    console.log("\n5️⃣ Checking entire user structure:");
    const userSnapshot = await db.ref(`/users/${REAL_USER_ID}`).once("value");
    if (userSnapshot.exists()) {
      console.log("User data structure:");
      const userData = userSnapshot.val();
      console.log(JSON.stringify(userData, null, 2));
    } else {
      console.log("❌ No user data found");
    }
  } catch (error) {
    console.error("❌ Error searching for baseline:", error);
  }

  process.exit(0);
}

findBaseline();
