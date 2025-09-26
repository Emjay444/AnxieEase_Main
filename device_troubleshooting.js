const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app"
  });
}

async function checkDeviceNotificationSettings() {
  console.log('📱 DEVICE NOTIFICATION TROUBLESHOOTING');
  console.log('═'.repeat(50));
  
  const fcmToken = "dJlsLVwwQlm7_qwAqlvxej:APA91bHst58wqLrOsqICaHX7rqTzNRSvXhOoV7oV3n1uxaU0LtUa7xwvr1L3NdlIM9IhfPY8aLrUU8WAX_uklVH8eIsnR_prV5gsN24znhYwIJcta-xyKKE";

  try {
    console.log('🔔 Testing notification with maximum compatibility...');
    
    // Test with the most compatible Android notification format
    const message = {
      token: fcmToken,
      notification: {
        title: '🚨 AnxieEase Alert',
        body: 'Sustained elevated heart rate detected - tap to open app'
      },
      data: {
        type: 'anxiety_alert',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        userId: '5afad7d4-3dcd-4353-badb-4f155303419a'
      },
      android: {
        priority: 'high',
        ttl: 3600000, // 1 hour TTL
        notification: {
          channelId: 'anxiety_alerts',
          priority: 'max',
          visibility: 'public',
          sound: 'default',
          icon: 'ic_notification',
          color: '#FF6B6B',
          tag: 'anxiety_alert',
          sticky: false
        }
      }
    };

    const response = await admin.messaging().send(message);
    console.log('✅ Maximum compatibility notification sent:', response);

    // Check common Android notification issues
    console.log('\n📋 TROUBLESHOOTING CHECKLIST:');
    console.log('');
    console.log('📱 DEVICE SETTINGS TO CHECK:');
    console.log('   1. ⚙️  Go to: Settings > Apps > AnxieEase (or your app name)');
    console.log('   2. 🔔 Check: Notifications are ENABLED');
    console.log('   3. 🔊 Check: Sound is ENABLED');
    console.log('   4. 📳 Check: Vibration is ENABLED');  
    console.log('   5. 🔋 Check: Battery optimization is DISABLED for the app');
    console.log('   6. 💤 Check: "Do Not Disturb" mode is OFF');
    console.log('');
    console.log('🔋 BATTERY OPTIMIZATION (Important!):');
    console.log('   • Settings > Battery > Battery Optimization');
    console.log('   • Find your app and select "Don\'t optimize"');
    console.log('   • This prevents Android from killing background processes');
    console.log('');
    console.log('🌐 NETWORK CONNECTIVITY:');
    console.log('   • Ensure device has internet connection');
    console.log('   • FCM requires active internet to deliver notifications');
    console.log('');
    console.log('📱 APP STATE:');
    console.log('   • For testing, fully CLOSE the app (swipe away from recent apps)');
    console.log('   • Background notifications work better when app is fully closed');

  } catch (error) {
    console.error('❌ Error:', error.message);
    if (error.code === 'messaging/registration-token-not-registered') {
      console.log('🔄 Token may be expired - restart the app to get a fresh token');
    } else if (error.code === 'messaging/invalid-registration-token') {
      console.log('❌ Token is invalid - app needs to re-register');
    }
  }
}

checkDeviceNotificationSettings();