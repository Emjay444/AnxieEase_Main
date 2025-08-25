// Direct FCM token test for background notifications
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://anxie-ease-default-rtdb.firebaseio.com'
});

async function testDirectFCM() {
  console.log('🎯 Direct FCM Token Test for Background Notifications\n');
  
  // Use the FCM token from your app logs
  const fcmToken = 'f2Knath_QL-BQ-7z_AjLzV:APA91bHGGMh5dAaLHMLOD6mVI7Z09xEl5io__7X3Wqm-s9P6wpfgrQOqgRCdU4ESAMAHnqIUkrp0gagONsOa2V2oNfjJrL4y_kwb9bkHmIq-tNrv3cnZ1hM';
  
  console.log('📱 Instructions:');
  console.log('   1. ✅ CLOSE AnxieEase app completely (swipe away)');
  console.log('   2. ✅ Keep screen on for 30 seconds');
  console.log('   3. ✅ Watch notification panel\n');

  try {
    // Test 1: Direct wellness reminder to specific token
    console.log('🧪 Test 1: Direct wellness reminder to FCM token');
    const wellnessMessage = {
      data: {
        type: 'wellness_reminder',
        category: 'afternoon',
        messageType: 'breathing',
        timestamp: Date.now().toString(),
      },
      notification: {
        title: '🧘 Direct Test: Wellness Reminder',
        body: 'This is a direct FCM test. If you see this, background notifications work!',
      },
      android: {
        priority: 'normal',
        notification: {
          channelId: 'wellness_reminders',
          priority: 'default',
          defaultSound: true,
        },
      },
      token: fcmToken, // Send directly to this token
    };

    const response1 = await admin.messaging().send(wellnessMessage);
    console.log('✅ Direct wellness notification sent:', response1);
    console.log('   📱 Check your phone now!\n');

    // Wait 5 seconds
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Test 2: Direct anxiety alert to specific token
    console.log('🧪 Test 2: Direct anxiety alert to FCM token');
    const anxietyMessage = {
      data: {
        type: 'anxiety_alert',
        severity: 'moderate',
        heartRate: '88',
        timestamp: Date.now().toString(),
      },
      notification: {
        title: '🚨 Direct Test: Anxiety Alert',
        body: 'This is a direct FCM anxiety test. Moderate anxiety detected.',
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'anxiety_alerts',
          priority: 'max',
          defaultSound: true,
        },
      },
      token: fcmToken, // Send directly to this token
    };

    const response2 = await admin.messaging().send(anxietyMessage);
    console.log('✅ Direct anxiety notification sent:', response2);
    console.log('   📱 Check your phone now!\n');

    // Wait 3 seconds
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Test 3: Simple notification with minimal config
    console.log('🧪 Test 3: Minimal notification config');
    const simpleMessage = {
      notification: {
        title: '📱 Simple Test',
        body: 'Basic FCM notification - should always work',
      },
      android: {
        priority: 'normal',
      },
      token: fcmToken,
    };

    const response3 = await admin.messaging().send(simpleMessage);
    console.log('✅ Simple notification sent:', response3);
    console.log('   📱 Check your phone now!\n');

    console.log('🎉 All direct FCM tests completed!');
    console.log('\n📋 Results Analysis:');
    console.log('   • If you received notifications → FCM works, issue is with topics/channels');
    console.log('   • If no notifications → Check phone settings (battery optimization, DND)');
    console.log('   • If only simple notification works → Issue is with channel configuration');

  } catch (error) {
    console.error('❌ Error sending direct FCM:', error);
  } finally {
    admin.app().delete();
  }
}

// Run the test
testDirectFCM().catch(console.error);
