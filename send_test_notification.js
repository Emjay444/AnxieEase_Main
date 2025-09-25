const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/'
});

const db = admin.database();

async function sendTestNotification() {
  console.log('🚀 Sending test notification...\n');
  
  try {
    const userId = '5efad7d4-3dd1-4355-badb-4f68bc0ab4df';
    
    // First check if user has FCM token
    const userRef = db.ref(`users/${userId}`);
    const userSnapshot = await userRef.once('value');
    const userData = userSnapshot.val();
    
    if (!userData || !userData.fcmToken) {
      console.log('❌ No FCM token found. Creating test notification in database...');
      
      // Create test notification in database for when app opens
      const testNotification = {
        title: 'AnxieEase Test Alert',
        message: 'This is a test notification from your anxiety detection system!',
        type: 'test',
        severity: 'mild',
        heartRate: 95,
        timestamp: Date.now(),
        read: false,
        source: 'manual_test'
      };
      
      await db.ref(`users/${userId}/notifications`).push(testNotification);
      console.log('✅ Test notification saved to database!');
      console.log('📱 Open your Flutter app to see the notification on homepage/notification screen');
      
    } else {
      console.log('✅ FCM token found! Sending push notification...');
      
      // Send actual push notification
      const message = {
        notification: {
          title: 'AnxieEase Test Alert',
          body: 'This is a test notification from your anxiety detection system!'
        },
        data: {
          type: 'test',
          severity: 'mild',
          heartRate: '95',
          timestamp: Date.now().toString()
        },
        token: userData.fcmToken
      };
      
      const response = await admin.messaging().send(message);
      console.log('✅ Push notification sent!', response);
      
      // Also save to database
      const testNotification = {
        title: 'AnxieEase Test Alert',
        message: 'This is a test notification from your anxiety detection system!',
        type: 'test',
        severity: 'mild',
        heartRate: 95,
        timestamp: Date.now(),
        read: false,
        source: 'manual_test',
        fcmResponse: response
      };
      
      await db.ref(`users/${userId}/notifications`).push(testNotification);
      console.log('✅ Notification also saved to database');
    }
    
    // Trigger the device to send current data for anxiety detection
    console.log('\n🔍 Current device status:');
    const deviceData = await db.ref('devices/AnxieEase001/current').once('value');
    const currentData = deviceData.val();
    
    if (currentData) {
      console.log(`   Heart Rate: ${currentData.heartRate} BPM`);
      console.log(`   Timestamp: ${new Date(currentData.timestamp).toLocaleString()}`);
      
      // Create a test anxiety trigger
      if (currentData.heartRate > 88) {
        console.log('\n🚨 Current HR would trigger anxiety detection!');
        console.log('   Creating anxiety alert...');
        
        const anxietyAlert = {
          deviceId: 'AnxieEase001',
          heartRate: currentData.heartRate,
          baseline: 73.2,
          severity: currentData.heartRate > 108 ? 'severe' : currentData.heartRate > 98 ? 'moderate' : 'mild',
          timestamp: Date.now(),
          confirmed: false,
          type: 'anxiety_detection',
          message: `Your heart rate is elevated (${currentData.heartRate} BPM). Are you feeling anxious?`
        };
        
        await db.ref(`users/${userId}/anxietyAlerts`).push(anxietyAlert);
        await db.ref(`users/${userId}/notifications`).push({
          title: 'Anxiety Alert',
          message: anxietyAlert.message,
          type: 'anxiety',
          severity: anxietyAlert.severity,
          heartRate: currentData.heartRate,
          timestamp: Date.now(),
          read: false,
          requiresConfirmation: anxietyAlert.severity !== 'severe'
        });
        
        console.log('✅ Anxiety alert created and saved!');
      }
    }
    
  } catch (error) {
    console.error('❌ Error sending test notification:', error);
  }
  
  process.exit(0);
}

sendTestNotification();