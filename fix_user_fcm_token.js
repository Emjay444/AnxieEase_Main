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

async function fixUserFCMToken() {
  console.log("🔧 FIXING USER FCM TOKEN...");
  console.log("═".repeat(40));

  try {
    // Get device assignment to find user ID
    const assignment = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    if (!assignment.exists()) {
      console.log("❌ No device assignment found");
      return;
    }

    const userId = assignment.val().assignedUser || assignment.val().userId;
    console.log("👤 User ID:", userId);

    // Get device FCM token
    const deviceToken = await db
      .ref("/devices/AnxieEase001/fcmToken")
      .once("value");
    if (!deviceToken.exists()) {
      console.log("❌ No device FCM token found");
      return;
    }

    const fcmToken = deviceToken.val();
    console.log("📱 Using device token:", fcmToken.slice(-8));

    // Set user FCM token to same as device token
    await db.ref(`/users/${userId}/fcmToken`).set(fcmToken);
    console.log("✅ User FCM token updated successfully!");

    // Verify the update
    const userToken = await db.ref(`/users/${userId}/fcmToken`).once("value");
    if (userToken.exists()) {
      console.log("✅ Verification: User FCM token now exists");
    } else {
      console.log("❌ Verification failed: User FCM token still missing");
    }

    console.log("\n🎉 Fix completed! Try running your anxiety test again.");
  } catch (error) {
    console.error("❌ Error fixing FCM token:", error);
  }
}

fixUserFCMToken().catch(console.error);
