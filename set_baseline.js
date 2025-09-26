const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

async function setUserBaseline() {
  const db = admin.database();
  const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
  const baselineRef = db.ref(`/users/${userId}/baseline/heartRate`);

  await baselineRef.set(73); // Set baseline to 73 BPM
  console.log(`✅ Set baseline for user ${userId}: 73 BPM`);
}

setUserBaseline()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Failed to set baseline:", e);
    process.exit(1);
  });
