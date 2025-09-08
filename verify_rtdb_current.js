// Quick verification: print devices/AnxieEase001/current
const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});
const db = admin.database();
(async () => {
  try {
    const snap = await db.ref("devices/AnxieEase001/current").once("value");
    console.log(JSON.stringify(snap.val(), null, 2));
  } catch (e) {
    console.error(e);
  } finally {
    admin.app().delete();
  }
})();
