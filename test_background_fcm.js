const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin SDK
try {
  // Check if service account key exists
  if (!fs.existsSync('./service-account-key.json')) {
    console.error('❌ service-account-key.json not found!');
    console.log('📋 Please download it from Firebase Console > Project Settings > Service Accounts > Generate new private key');
    process.exit(1);
  }

  // Initialize Firebase Admin
  const serviceAccount = require('./service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://anxiease-5ac83-default-rtdb.asia-southeast1.firebasedatabase.app'
  });

  console.log('✅ Firebase Admin initialized successfully');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error);
  process.exit(1);
}

async function testBackgroundNotification() {
  try {
    console.log('\n🧪 Testing background FCM notification...');
    
    // Test notification to topic (this should work when app is closed)
    const message = {
      data: {
        type: "test_background_alert",
        severity: "moderate",
        heartRate: "85",
        timestamp: Date.now().toString(),
      },
      notification: {
        title: "🧪 [BACKGROUND TEST] Moderate Alert",
        body: "Testing background notifications. HR: 85 bpm",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "anxiety_alerts",
          priority: "max",
          sound: "default",
        },
      },
      // Send to topic so all app instances receive it
      topic: "anxiety_alerts",
    };

    console.log('📤 Sending background test notification...');
    const response = await admin.messaging().send(message);
    console.log('✅ Background notification sent successfully!');
    console.log('📨 Message ID:', response);
    
    console.log('\n📱 Instructions:');
    console.log('1. Close your AnxieEase app completely (remove from recent apps)');
    console.log('2. Wait 10 seconds');
    console.log('3. You should receive a notification even with app closed');
    console.log('4. If you don\'t see it, check:');
    console.log('   - Android notification permissions');
    console.log('   - Battery optimization settings (disable for AnxieEase)');
    console.log('   - Background app restrictions');
    
  } catch (error) {
    console.error('❌ Error sending background notification:', error);
    
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log('💡 This usually means the app hasn\'t subscribed to the topic yet');
      console.log('   Make sure to run the app at least once after the latest update');
    }
  }
}

// Run the test
testBackgroundNotification().then(() => {
  console.log('\n✨ Test completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
