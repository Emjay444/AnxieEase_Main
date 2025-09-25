const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/'
});

const db = admin.database();

async function sendDirectPushNotification() {
  console.log('🚀 Sending direct push notification to your device...\n');
  
  try {
    const userId = '5afad7d4-3dcd-4353-badb-4f155303419a';
    const fcmToken = 'cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0';
    
    console.log('📱 Sending push notification...');
    
    // Send FCM push notification
    const message = {
      notification: {
        title: '🚨 AnxieEase Alert',
        body: 'Your heart rate is elevated (95 BPM). Are you feeling anxious?'
      },
      data: {
        type: 'anxiety',
        severity: 'mild',
        heartRate: '95',
        timestamp: Date.now().toString(),
        requiresConfirmation: 'true'
      },
      token: fcmToken
    };
    
    const response = await admin.messaging().send(message);
    console.log('✅ Push notification sent successfully!');
    console.log('📱 Response:', response);
    
    // Also save to multiple possible Firebase paths to ensure app picks it up
    const notificationData = {
      title: '🚨 AnxieEase Alert',
      message: 'Your heart rate is elevated (95 BPM). Are you feeling anxious?',
      type: 'anxiety',
      severity: 'mild',
      heartRate: 95,
      timestamp: Date.now(),
      read: false,
      requiresConfirmation: true,
      source: 'direct_push_test'
    };
    
    // Try multiple paths
    console.log('💾 Saving to multiple Firebase paths...');
    
    // Path 1: Standard notifications
    await db.ref(`users/${userId}/notifications`).push(notificationData);
    console.log('✅ Saved to users/{userId}/notifications');
    
    // Path 2: Try anxietyAlerts
    await db.ref(`users/${userId}/anxietyAlerts`).push(notificationData);
    console.log('✅ Saved to users/{userId}/anxietyAlerts');
    
    // Path 3: Try device-based path
    await db.ref(`devices/AnxieEase001/notifications`).push(notificationData);
    console.log('✅ Saved to devices/AnxieEase001/notifications');
    
    console.log('\n🎉 NOTIFICATION TEST COMPLETE!');
    console.log('You should now see:');
    console.log('1. 📱 Push notification in Android notification tray');
    console.log('2. 📱 Notification in your Flutter app homepage');
    console.log('3. 📱 Notification in your notification screen');
    
    console.log('\n📊 Current Status:');
    console.log('✅ FCM push notification sent');
    console.log('✅ Data saved to Firebase database');
    console.log('✅ App should receive notification immediately');
    
  } catch (error) {
    console.error('❌ Error sending notification:', error);
  }
  
  process.exit(0);
}

sendDirectPushNotification();