const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
});

const db = admin.database();

async function checkFirebaseStructure() {
  console.log("🔍 Checking Firebase structure...\n");

  try {
    // Check entire device node
    const deviceRef = db.ref("devices/AnxieEase001");
    const deviceSnapshot = await deviceRef.once("value");
    const deviceData = deviceSnapshot.val();

    console.log("📱 Complete Device Data Structure:");
    console.log(JSON.stringify(deviceData, null, 2));

    // Check users root
    const usersRef = db.ref("users");
    const usersSnapshot = await usersRef.once("value");
    const users = usersSnapshot.val();

    console.log("\n👥 Users in Firebase:");
    if (users) {
      Object.keys(users).forEach((userId) => {
        console.log(
          `   ${userId}: FCM Token = ${
            users[userId].fcmToken ? "Present" : "Missing"
          }`
        );
      });
    } else {
      console.log("   No users found");
    }
  } catch (error) {
    console.error("Error:", error);
  }

  process.exit(0);
}

checkFirebaseStructure();
