// Quick debug script to check notification system status
const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./functions/anxieease-sensors-firebase-adminsdk-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app'
});

async function checkSystemStatus() {
  console.log('🔍 Checking AnxieEase notification system status...\n');
  
  try {
    const db = admin.database();
    
    // 1. Check if there are any users with FCM tokens
    console.log('1️⃣ Checking FCM tokens...');
    const usersSnapshot = await db.ref('users').once('value');
    const users = usersSnapshot.val();
    
    if (!users) {
      console.log('❌ No users found in Firebase');
      return;
    }
    
    const userIds = Object.keys(users);
    console.log(`✅ Found ${userIds.length} users`);
    
    let usersWithTokens = 0;
    let usersWithDevices = 0;
    
    for (const userId of userIds) {
      const user = users[userId];
      if (user.fcmToken) {
        usersWithTokens++;
        console.log(`📱 User ${userId}: Has FCM token`);
      }
      if (user.assignedDevice) {
        usersWithDevices++;
        console.log(`📡 User ${userId}: Assigned to device ${user.assignedDevice}`);
      }
    }
    
    console.log(`\n📊 Summary:`);
    console.log(`- Users with FCM tokens: ${usersWithTokens}/${userIds.length}`);
    console.log(`- Users with assigned devices: ${usersWithDevices}/${userIds.length}`);
    
    // 2. Check device data
    console.log('\n2️⃣ Checking device data...');
    const devicesSnapshot = await db.ref('devices').once('value');
    const devices = devicesSnapshot.val();
    
    if (!devices) {
      console.log('❌ No devices found');
      return;
    }
    
    const deviceIds = Object.keys(devices);
    console.log(`✅ Found ${deviceIds.length} devices`);
    
    for (const deviceId of deviceIds) {
      const device = devices[deviceId];
      if (device.current && device.current.heartRate) {
        console.log(`💓 Device ${deviceId}: Current HR = ${device.current.heartRate} BPM`);
      }
    }
    
    // 3. Test if a user can receive notifications
    console.log('\n3️⃣ Testing notification capability...');
    const testUserId = userIds.find(id => users[id].fcmToken);
    
    if (testUserId) {
      const fcmToken = users[testUserId].fcmToken;
      console.log(`🧪 Testing notification to user ${testUserId}`);
      
      try {
        const message = {
          data: {
            type: 'test_debug',
            title: 'Debug Test Notification',
            body: 'Testing notification system',
            severity: 'mild'
          },
          token: fcmToken
        };
        
        const response = await admin.messaging().send(message);
        console.log('✅ Test notification sent successfully:', response);
      } catch (error) {
        console.log('❌ Failed to send test notification:', error.message);
      }
    } else {
      console.log('❌ No users with FCM tokens found for testing');
    }
    
  } catch (error) {
    console.error('❌ Error checking system status:', error);
  }
  
  process.exit(0);
}

checkSystemStatus();