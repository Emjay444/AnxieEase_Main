const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

async function pushTestAlert() {
  const db = admin.database();
  const deviceId = process.env.DEVICE_ID || "AnxieEase001";
  const alertsRef = db.ref(`/devices/${deviceId}/alerts`).push();

  const alert = {
    severity: "mild",
    heartRate: 88,
    type: "anxiety_alert",
    timestamp: Date.now(),
  };

  await alertsRef.set(alert);
  console.log(`✅ Pushed test alert ${alertsRef.key} for ${deviceId}`);
}

pushTestAlert()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("❌ Failed to push alert:", e);
    process.exit(1);
  });
