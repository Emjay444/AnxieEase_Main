const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/'
});
const db = admin.database();
async function checkFcmToken() {
  const userId = '5afad7d4-3dcd-4353-badb-4f155303419a';
  const userRef = db.ref(`users/${userId}`);
  const userSnapshot = await userRef.once('value');
  const userData = userSnapshot.val();
  if (userData && userData.fcmToken) {
    console.log('FCM token in Firebase:', userData.fcmToken);
  } else {
    console.log('No FCM token found for user:', userId);
  }
  process.exit(0);
}
checkFcmToken();