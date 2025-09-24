/**
 * 🔍 FIREBASE DATA DEBUG SCRIPT
 * 
 * This script shows you exactly what data exists in your Firebase database.
 * Use this to troubleshoot why you can't see user history.
 * 
 * Run: node debug_firebase_data.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/'
  });
}

const db = admin.database();

/**
 * 🔍 Debug Firebase data to see what's actually stored
 */
async function debugFirebaseData() {
  console.log('\n🔍 FIREBASE DATABASE DEBUG');
  console.log('==========================');

  try {
    // Check root structure
    console.log('\n📁 Checking root database structure...');
    const rootRef = db.ref('/');
    const rootSnapshot = await rootRef.once('value');
    const rootData = rootSnapshot.val();
    
    if (rootData) {
      console.log('✅ Root keys found:', Object.keys(rootData));
    } else {
      console.log('❌ No data found in root');
      return;
    }

    // Check users data
    console.log('\n👥 Checking users data...');
    const usersRef = db.ref('/users');
    const usersSnapshot = await usersRef.once('value');
    const usersData = usersSnapshot.val();
    
    if (usersData) {
      console.log('✅ Users found:');
      Object.keys(usersData).forEach(userId => {
        console.log(`   📋 User ID: ${userId}`);
        const userData = usersData[userId];
        
        // Check user properties
        if (userData.fcmToken) {
          console.log(`      📱 FCM Token: ${userData.fcmToken.substring(0, 20)}...`);
        }
        if (userData.baseline) {
          console.log(`      💓 Baseline: ${userData.baseline.heartRate} BPM`);
        }
        if (userData.sessions) {
          console.log(`      📊 Sessions: ${Object.keys(userData.sessions).length}`);
        }
        if (userData.anxiety_alerts) {
          console.log(`      🚨 Anxiety alerts: ${Object.keys(userData.anxiety_alerts).length}`);
        }
      });
    } else {
      console.log('❌ No users data found');
    }

    // Check device assignments
    console.log('\n📱 Checking device assignments...');
    const assignmentsRef = db.ref('/device_assignments');
    const assignmentsSnapshot = await assignmentsRef.once('value');
    const assignmentsData = assignmentsSnapshot.val();
    
    if (assignmentsData) {
      console.log('✅ Device assignments found:');
      Object.keys(assignmentsData).forEach(deviceId => {
        const assignment = assignmentsData[deviceId];
        console.log(`   🔧 Device: ${deviceId}`);
        console.log(`      👤 Assigned to: ${assignment.userId}`);
        console.log(`      📅 Assigned at: ${new Date(assignment.assignedAt).toLocaleString()}`);
        console.log(`      ⚡ Status: ${assignment.status}`);
      });
    } else {
      console.log('❌ No device assignments found');
    }

    // Check device data (if any)
    console.log('\n🔧 Checking device data...');
    const deviceRef = db.ref('/devices');
    const deviceSnapshot = await deviceRef.once('value');
    const deviceData = deviceSnapshot.val();
    
    if (deviceData) {
      console.log('✅ Device data found:');
      Object.keys(deviceData).forEach(deviceId => {
        console.log(`   📟 Device: ${deviceId}`);
        const device = deviceData[deviceId];
        
        if (device.current) {
          console.log(`      💓 Current heart rate: ${device.current.heartRate} BPM`);
          console.log(`      🔋 Battery: ${device.current.batteryLevel}%`);
          console.log(`      📅 Last update: ${new Date(device.current.timestamp).toLocaleString()}`);
        }
      });
    } else {
      console.log('❌ No device data found');
    }

    // Summary
    console.log('\n📊 SUMMARY');
    console.log('==========');
    
    const hasUsers = usersData && Object.keys(usersData).length > 0;
    const hasAssignments = assignmentsData && Object.keys(assignmentsData).length > 0;
    const hasDeviceData = deviceData && Object.keys(deviceData).length > 0;
    
    console.log(`👥 Users: ${hasUsers ? '✅ Found' : '❌ Missing'}`);
    console.log(`📱 Assignments: ${hasAssignments ? '✅ Found' : '❌ Missing'}`);
    console.log(`🔧 Device data: ${hasDeviceData ? '✅ Found' : '❌ Missing'}`);
    
    if (!hasUsers && !hasAssignments && !hasDeviceData) {
      console.log('\n⚠️  NO DATA FOUND! This means:');
      console.log('   1. No tests have been run yet, OR');
      console.log('   2. Wrong database URL/region, OR');
      console.log('   3. Firebase credentials are incorrect');
      console.log('\n💡 Try running: node test_direct_notification.js first');
    } else {
      console.log('\n🎉 Data found! You can view this in Firebase Console:');
      console.log('   1. Go to Firebase Console → Realtime Database');
      console.log('   2. Navigate to the paths shown above');
      console.log('   3. If you don\'t see data there, check database region');
    }

  } catch (error) {
    console.error('\n❌ DEBUG FAILED');
    console.error('================');
    console.error('Error:', error.message);
    
    if (error.code === 'DATABASE_UNREACHABLE') {
      console.error('\n🔧 Possible solutions:');
      console.error('   1. Check database URL in service account config');
      console.error('   2. Verify Firebase project permissions');
      console.error('   3. Check internet connection');
    }
  }
}

// Show database URL for verification
console.log('🔗 Database URL:', 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/');

// Run the debug
debugFirebaseData()
  .then(() => {
    console.log('\n✨ Debug completed!');
    process.exit(0);
  })
  .catch(error => {
    console.error('💥 Debug script failed:', error);
    process.exit(1);
  });