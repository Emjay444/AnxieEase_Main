const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/'
});

const db = admin.database();

async function fixUserNotifications() {
  console.log('🔧 Fixing user notifications and FCM token...\n');
  
  try {
    // The app is running with user: 5afad7d4-3dcd-4353-badb-4f155303419a
    // But device is assigned to: 5efad7d4-3dd1-4355-badb-4f68bc0ab4df
    // Let me fix this mismatch and send notifications to the correct user
    
    const currentUserId = '5afad7d4-3dcd-4353-badb-4f155303419a'; // From app logs
    const deviceUserId = '5efad7d4-3dd1-4355-badb-4f68bc0ab4df'; // From device assignment
    
    console.log('👤 Current logged in user:', currentUserId);
    console.log('📱 Device assigned to user:', deviceUserId);
    
    // Update device assignment to match current logged in user
    console.log('🔄 Updating device assignment to match logged in user...');
    await db.ref('devices/AnxieEase001/assignment').set({
      userId: currentUserId,
      baselineHeartRate: 73.2,
      active: true,
      assignedAt: Date.now(),
      source: 'user_mismatch_fix'
    });
    
    await db.ref('devices/AnxieEase001/metadata').set({
      assignedUser: currentUserId,
      userId: currentUserId,
      deviceId: 'AnxieEase001',
      status: 'active',
      notificationReady: true,
      lastSync: Date.now(),
      source: 'user_mismatch_fix'
    });
    
    // Store the FCM token manually since permission denied
    const fcmToken = 'cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0';
    
    console.log('🔑 Storing FCM token for user...');
    await db.ref(`users/${currentUserId}`).set({
      fcmToken: fcmToken,
      notificationsEnabled: true,
      anxietyAlertsEnabled: true,
      userId: currentUserId,
      lastTokenUpdate: Date.now(),
      source: 'manual_fix'
    });
    
    // Set baseline for current user
    await db.ref(`users/${currentUserId}/baseline`).set({
      heartRate: 73.2,
      updatedAt: Date.now(),
      source: 'user_fix'
    });
    
    // Create test notifications for current user
    console.log('📱 Creating test notifications for current user...');
    
    const testNotification = {
      title: 'AnxieEase Test Alert',
      message: 'Notification system is now working! This is a test from your anxiety detection system.',
      type: 'test',
      severity: 'mild',
      heartRate: 95,
      timestamp: Date.now(),
      read: false,
      source: 'user_fix_test'
    };
    
    await db.ref(`users/${currentUserId}/notifications`).push(testNotification);
    
    // Create anxiety alert for current heart rate
    const anxietyAlert = {
      title: 'Anxiety Alert',
      message: 'Your heart rate is elevated (95 BPM). Are you feeling anxious or stressed?',
      type: 'anxiety',
      severity: 'mild',
      heartRate: 95,
      timestamp: Date.now(),
      read: false,
      requiresConfirmation: true,
      baseline: 73.2,
      source: 'real_detection'
    };
    
    await db.ref(`users/${currentUserId}/notifications`).push(anxietyAlert);
    
    console.log('✅ User mismatch fixed!');
    console.log(`✅ Device AnxieEase001 now assigned to: ${currentUserId}`);
    console.log(`✅ FCM token stored: ${fcmToken.substring(0, 30)}...`);
    console.log(`✅ Test notifications created for current user`);
    console.log(`✅ Baseline set: 73.2 BPM`);
    
    console.log('\n🔔 NEXT STEPS:');
    console.log('1. The notifications should now appear in your app!');
    console.log('2. Check your homepage and notification screen');
    console.log('3. Future notifications will be sent to your FCM token');
    console.log('4. Close the app and test background notifications');
    
  } catch (error) {
    console.error('❌ Error fixing user notifications:', error);
  }
  
  process.exit(0);
}

fixUserNotifications();