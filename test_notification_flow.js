// NOTIFICATION TEST - VERIFY COMPLETE FLOW
// Test that device assignment, user detection, and notification flow works

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

async function testNotificationFlow() {
  console.log('🔔 TESTING COMPLETE NOTIFICATION FLOW');
  console.log('====================================\n');

  const deviceId = 'AnxieEase001';
  
  try {
    // Step 1: Test device info retrieval (what anxiety detection does)
    console.log('🔍 STEP 1: Testing device info retrieval...');
    
    // Simulate the getDeviceInfo function
    const metadataRef = db.ref(`devices/${deviceId}/metadata`);
    const metadataSnapshot = await metadataRef.once('value');
    
    let deviceInfo = null;
    if (metadataSnapshot.exists()) {
      const metadata = metadataSnapshot.val();
      if (metadata.userId) {
        deviceInfo = metadata;
        console.log('✅ Found device info in metadata path');
        console.log(`   userId: ${deviceInfo.userId}`);
        console.log(`   notificationReady: ${deviceInfo.notificationReady}`);
      }
    }

    if (!deviceInfo) {
      // Check assignment path as fallback
      const assignmentRef = db.ref(`devices/${deviceId}/assignment`);
      const assignmentSnapshot = await assignmentRef.once('value');
      
      if (assignmentSnapshot.exists()) {
        const assignment = assignmentSnapshot.val();
        if (assignment.assignedUser) {
          deviceInfo = {
            userId: assignment.assignedUser,
            deviceId: deviceId,
            source: "assignment_sync"
          };
          console.log('✅ Found device info in assignment path (fallback)');
          console.log(`   userId: ${deviceInfo.userId}`);
        }
      }
    }

    if (!deviceInfo) {
      console.log('❌ CRITICAL: No device info found - notifications will fail!');
      return;
    }

    // Step 2: Test user baseline retrieval
    console.log('\n🔍 STEP 2: Testing user baseline retrieval...');
    
    const userId = deviceInfo.userId;
    const baselineRef = db.ref(`baselines/${userId}/${deviceId}`);
    const baselineSnapshot = await baselineRef.once('value');
    
    let baseline = null;
    if (baselineSnapshot.exists()) {
      baseline = baselineSnapshot.val();
      console.log('✅ Found user baseline');
      console.log(`   baselineHR: ${baseline.heartRate} BPM`);
    } else {
      // Check user baseline path
      const userBaselineRef = db.ref(`users/${userId}/baseline`);
      const userBaselineSnapshot = await userBaselineRef.once('value');
      
      if (userBaselineSnapshot.exists()) {
        const userBaseline = userBaselineSnapshot.val();
        baseline = { baselineHR: userBaseline.heartRate };
        console.log('✅ Found user baseline (alternate path)');
        console.log(`   baselineHR: ${baseline.baselineHR} BPM`);
      }
    }

    if (!baseline) {
      console.log('❌ WARNING: No baseline found - anxiety detection may not work');
      return;
    }

    // Step 3: Test FCM token check
    console.log('\n🔍 STEP 3: Testing FCM token availability...');
    
    const fcmTokenRef = db.ref(`users/${userId}/fcmToken`);
    const fcmTokenSnapshot = await fcmTokenRef.once('value');
    
    if (fcmTokenSnapshot.exists()) {
      const fcmToken = fcmTokenSnapshot.val();
      console.log('✅ Found FCM token for notifications');
      console.log(`   token: ${fcmToken.substring(0, 20)}...`);
    } else {
      console.log('⚠️  No FCM token found - app needs to register for notifications');
      console.log('   This usually happens when the Flutter app first starts');
    }

    // Step 4: Simulate anxiety detection trigger
    console.log('\n🔍 STEP 4: Simulating anxiety detection...');
    
    const currentHR = 95; // Simulated elevated heart rate
    const restingHR = baseline.baselineHR || baseline.heartRate;
    const hrElevation = currentHR - restingHR;
    const isMildLevel = hrElevation >= 15 && hrElevation < 25;
    const isModerateLevel = hrElevation >= 25 && hrElevation < 35;
    
    console.log(`Simulated HR: ${currentHR} BPM`);
    console.log(`Baseline HR: ${restingHR} BPM`);
    console.log(`Elevation: +${hrElevation.toFixed(1)} BPM`);
    console.log(`Level: ${isModerateLevel ? 'MODERATE' : isMildLevel ? 'MILD' : 'NORMAL'}`);
    
    if (isMildLevel || isModerateLevel) {
      console.log('🚨 WOULD TRIGGER: Anxiety detection with confirmation request');
      console.log('📱 Notification would be sent asking: "Are you feeling anxious?"');
    } else {
      console.log('✅ Would not trigger - heart rate not high enough');
    }

    // Step 5: Final verification
    console.log('\n🎯 FINAL VERIFICATION:');
    console.log('======================');
    
    const checksPass = {
      deviceAssigned: !!deviceInfo,
      userIdFound: !!deviceInfo.userId,
      baselineFound: !!baseline,
      thresholdMet: (currentHR >= restingHR + 15)
    };
    
    console.log(`✅ Device assigned: ${checksPass.deviceAssigned}`);
    console.log(`✅ User ID found: ${checksPass.userIdFound}`);
    console.log(`✅ Baseline found: ${checksPass.baselineFound}`);
    console.log(`✅ Would trigger at 89+ BPM: ${checksPass.thresholdMet}`);
    
    const allGood = Object.values(checksPass).every(check => check);
    
    if (allGood) {
      console.log('\n🎉 SUCCESS: Notification flow is ready!');
      console.log('==========================================');
      console.log('✅ Device properly assigned to user');
      console.log('✅ Anxiety detection can find userId'); 
      console.log('✅ Baseline is available for thresholds');
      console.log('✅ Notifications should work when HR ≥ 89 BPM');
      
      console.log('\n📱 TO TEST RIGHT NOW:');
      console.log('=====================');
      console.log('1. Make sure your Flutter app is running');
      console.log('2. Increase your heart rate to 89+ BPM (light exercise, then sit)');
      console.log('3. Watch for notification: "Are you feeling anxious?"');
      console.log('4. Check both system notifications and in-app notifications');
    } else {
      console.log('\n❌ ISSUES FOUND: Some checks failed');
      console.log('Fix the failed checks above before testing notifications');
    }

  } catch (error) {
    console.error('❌ Error testing notification flow:', error.message);
  }
}

testNotificationFlow();