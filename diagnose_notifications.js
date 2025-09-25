// COMPREHENSIVE NOTIFICATION DIAGNOSTIC TOOL
// This will help us identify why notifications aren't reaching your app

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

async function diagnoseNotificationIssues() {
  console.log('🔍 NOTIFICATION SYSTEM DIAGNOSTIC');
  console.log('==================================\n');

  try {
    // Step 1: Check if FCM token exists for your device
    console.log('1️⃣ CHECKING FCM TOKEN REGISTRATION:');
    console.log('===================================');
    
    const deviceRef = db.ref('/devices/AnxieEase001');
    const deviceSnapshot = await deviceRef.once('value');
    
    if (deviceSnapshot.exists()) {
      const deviceData = deviceSnapshot.val();
      
      console.log('Device data found:');
      Object.keys(deviceData).forEach(key => {
        if (key.includes('token') || key.includes('fcm') || key.includes('registration')) {
          console.log(`   ${key}: ${deviceData[key]}`);
        }
      });
      
      // Check user assignment
      if (deviceData.userId) {
        console.log(`✅ Device assigned to user: ${deviceData.userId}`);
        
        // Check for FCM token in user data
        const userRef = db.ref(`/users/${deviceData.userId}`);
        const userSnapshot = await userRef.once('value');
        
        if (userSnapshot.exists()) {
          const userData = userSnapshot.val();
          if (userData.fcmToken) {
            console.log(`✅ FCM Token found: ${userData.fcmToken.substring(0, 20)}...`);
          } else {
            console.log('❌ No FCM token found in user data');
          }
        }
        
      } else {
        console.log('❌ Device not assigned to any user');
      }
    } else {
      console.log('❌ Device data not found in Firebase');
    }

    // Step 2: Check Firebase Functions logs
    console.log('\n2️⃣ CHECKING RECENT FIREBASE FUNCTION ACTIVITY:');
    console.log('===============================================');
    
    const logsRef = db.ref('/logs/functions');
    const logsSnapshot = await logsRef.limitToLast(5).once('value');
    
    if (logsSnapshot.exists()) {
      console.log('Recent Firebase Function activity:');
      logsSnapshot.forEach(childSnapshot => {
        const log = childSnapshot.val();
        console.log(`   ${new Date(log.timestamp).toLocaleString()}: ${log.message}`);
      });
    } else {
      console.log('❌ No Firebase Function logs found');
    }

    // Step 3: Check anxiety detection triggers
    console.log('\n3️⃣ CHECKING ANXIETY DETECTION HISTORY:');
    console.log('======================================');
    
    const alertsRef = db.ref('/alerts/AnxieEase001');
    const alertsSnapshot = await alertsRef.limitToLast(3).once('value');
    
    if (alertsSnapshot.exists()) {
      console.log('Recent anxiety detection attempts:');
      alertsSnapshot.forEach(childSnapshot => {
        const alert = childSnapshot.val();
        console.log(`   ${new Date(alert.timestamp).toLocaleString()}:`);
        console.log(`     Reason: ${alert.reason}`);
        console.log(`     Confidence: ${alert.confidenceLevel}`);
        console.log(`     Triggered: ${alert.triggered ? 'YES' : 'NO'}`);
        console.log(`     Notification Sent: ${alert.notificationSent ? 'YES' : 'NO'}`);
      });
    } else {
      console.log('❌ No anxiety detection history found');
    }

    // Step 4: Test notification sending capability
    console.log('\n4️⃣ TESTING NOTIFICATION SENDING:');
    console.log('=================================');
    
    // Simulate a test notification
    const testDeviceRef = db.ref('/devices/AnxieEase001/testNotification');
    await testDeviceRef.set({
      severity: 'mild',
      heartRate: 92,
      timestamp: Date.now(),
      testMode: true
    });
    
    console.log('✅ Test notification trigger sent to Firebase');
    console.log('   This should trigger the Firebase Function if working correctly');

    // Step 5: Check Supabase notifications
    console.log('\n5️⃣ CHECKING SUPABASE NOTIFICATION STORAGE:');
    console.log('==========================================');
    console.log('Note: This requires Supabase connection from Flutter app');
    console.log('Check your Flutter app\'s notification screen for stored notifications');

    // Step 6: FCM Token diagnostic
    console.log('\n6️⃣ FCM TOKEN DIAGNOSTIC STEPS:');
    console.log('==============================');
    console.log('Please check in your Flutter app:');
    console.log('1. Open Flutter app and check console logs for FCM token');
    console.log('2. Look for messages like: "FCM Token: ey..."');
    console.log('3. Verify Firebase project configuration');
    console.log('4. Check if notifications permission is granted');

    console.log('\n7️⃣ TROUBLESHOOTING CHECKLIST:');
    console.log('=============================');
    console.log('✓ Firebase project ID matches in flutter app');
    console.log('✓ google-services.json is up to date');
    console.log('✓ FCM token is being registered in Firebase');
    console.log('✓ Device is assigned to a user');
    console.log('✓ User has granted notification permissions');
    console.log('✓ Firebase Functions are deployed');
    console.log('✓ Anxiety detection is triggering');

    console.log('\n📱 IMMEDIATE ACTION ITEMS:');
    console.log('==========================');
    console.log('1. Run Flutter app and check console for FCM token');
    console.log('2. Try manual notification test from Firebase console');
    console.log('3. Check if anxiety detection reaches trigger thresholds');
    console.log('4. Verify notification permissions in device settings');
    console.log('5. Test with higher heart rate to trigger alerts');

    // Step 7: Generate test anxiety condition
    console.log('\n8️⃣ GENERATING TEST ANXIETY CONDITION:');
    console.log('====================================');
    
    const testDataRef = db.ref('/devices/AnxieEase001/current');
    await testDataRef.update({
      heartRate: 95, // Above your 88.9 threshold  
      spo2: 97,
      timestamp: Date.now(),
      sessionId: `test_${Date.now()}`,
      bodyTemp: 36.8,
      worn: 1,
      // Real accelerometer values for sitting (low movement)
      accelX: 5.1,
      accelY: 2.0, 
      accelZ: 7.9,
      gyroX: 0.01,
      gyroY: -0.01,
      gyroZ: 0.00
    });
    
    console.log('🚨 Test anxiety condition created:');
    console.log(`   Heart Rate: 95 BPM (above your 88.9 threshold)`);
    console.log(`   Movement: Low (sitting position)`);
    console.log(`   This should trigger a mild anxiety alert with confirmation!`);
    
    console.log('\n💡 EXPECTED BEHAVIOR:');
    console.log('=====================');
    console.log('If working correctly, you should receive:');
    console.log('📱 Notification: "Mild Anxiety Detected"');
    console.log('❓ Message: "Are you feeling anxious or stressed?"');
    console.log('🔘 Buttons: [YES] [NO] [NOT NOW]');

  } catch (error) {
    console.error('❌ Diagnostic error:', error.message);
  }
}

diagnoseNotificationIssues();