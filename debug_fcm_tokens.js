const admin = require("firebase-admin");

// Initialize Firebase Admin (uses service account from environment)
if (!admin.apps.length) {
  admin.initializeApp({
    databaseURL: "https://anxieease-sensors-default-rtdb.firebaseio.com/",
  });
}

const db = admin.database();

async function checkTokens() {
  const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
  const deviceId = "AnxieEase001";

  console.log("🔍 Checking FCM token locations...");

  // Check user-level token
  try {
    const userTokenRef = db.ref(`/users/${userId}/fcmToken`);
    const userTokenSnap = await userTokenRef.once("value");
    if (userTokenSnap.exists()) {
      const token = userTokenSnap.val();
      console.log(`✅ User token found: ${token.substring(0, 20)}...`);
    } else {
      console.log("❌ No user token found");
    }
  } catch (error) {
    console.log("❌ Error checking user token:", error.message);
  }

  // Check device-level token
  try {
    const deviceTokenRef = db.ref(`/devices/${deviceId}/fcmToken`);
    const deviceTokenSnap = await deviceTokenRef.once("value");
    if (deviceTokenSnap.exists()) {
      const token = deviceTokenSnap.val();
      console.log(`✅ Device token found: ${token.substring(0, 20)}...`);
    } else {
      console.log("❌ No device token found");
    }
  } catch (error) {
    console.log("❌ Error checking device token:", error.message);
  }

  process.exit(0);
}

checkTokens().catch(console.error);
