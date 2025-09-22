// Test Script for Multi-User Device System
// Run this script to test the device assignment and data copying functionality

const admin = require('firebase-admin');

// Initialize Firebase Admin (you'll need to add your service account key)
// For testing, you can use the Firebase CLI's authentication
const serviceAccount = require('./anxieease-sensors-firebase-adminsdk.json'); // You'll need to download this
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.firebaseio.com"
});

const db = admin.database();

async function testMultiUserSystem() {
  console.log('🧪 Testing Multi-User Device System...\n');

  try {
    // Test 1: Assign device to a test user
    console.log('1️⃣ Testing device assignment...');
    const testUserId = 'test_user_123';
    const sessionId = `session_${Date.now()}`;
    
    // Manually assign device (simulating admin action)
    await db.ref('devices/AnxieEase001/assignment').set({
      userId: testUserId,
      sessionId: sessionId,
      assignedAt: admin.database.ServerValue.TIMESTAMP,
      assignedBy: 'test_admin',
      description: 'Testing multi-user system'
    });

    // Create user session metadata
    await db.ref(`users/${testUserId}/sessions/${sessionId}/metadata`).set({
      deviceId: 'AnxieEase001',
      startTime: admin.database.ServerValue.TIMESTAMP,
      status: 'active',
      description: 'Testing multi-user system',
      totalDataPoints: 0
    });

    console.log('✅ Device assigned to user successfully');

    // Test 2: Simulate device data to trigger copying
    console.log('\n2️⃣ Testing data copying...');
    
    const testData = {
      heartRate: 85,
      spo2: 98,
      temperature: 98.6,
      movementLevel: 25,
      timestamp: Date.now(),
      batteryLevel: 85
    };

    // Write to device current (should trigger copyDeviceCurrentToUserSession)
    await db.ref('devices/AnxieEase001/current').set(testData);
    console.log('📤 Sent current data to device');

    // Write to device history (should trigger copyDeviceDataToUserSession)
    await db.ref(`devices/AnxieEase001/history/${testData.timestamp}`).set(testData);
    console.log('📤 Sent history data to device');

    // Wait a moment for Cloud Functions to process
    console.log('\n⏳ Waiting for Cloud Functions to process...');
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Test 3: Verify data was copied
    console.log('\n3️⃣ Verifying data was copied...');
    
    // Check if current data was copied
    const userCurrentSnapshot = await db.ref(`users/${testUserId}/sessions/${sessionId}/current`).once('value');
    const userCurrentData = userCurrentSnapshot.val();
    
    if (userCurrentData && userCurrentData.heartRate === testData.heartRate) {
      console.log('✅ Current data copied successfully');
      console.log(`   Heart Rate: ${userCurrentData.heartRate} BPM`);
    } else {
      console.log('❌ Current data not found in user session');
    }

    // Check if history data was copied
    const userHistorySnapshot = await db.ref(`users/${testUserId}/sessions/${sessionId}/history/${testData.timestamp}`).once('value');
    const userHistoryData = userHistorySnapshot.val();
    
    if (userHistoryData && userHistoryData.heartRate === testData.heartRate) {
      console.log('✅ History data copied successfully');
      console.log(`   Data point timestamp: ${testData.timestamp}`);
    } else {
      console.log('❌ History data not found in user session');
    }

    // Test 4: Check session metadata was updated
    const metadataSnapshot = await db.ref(`users/${testUserId}/sessions/${sessionId}/metadata`).once('value');
    const metadata = metadataSnapshot.val();
    
    if (metadata && metadata.totalDataPoints > 0) {
      console.log('✅ Session metadata updated successfully');
      console.log(`   Total data points: ${metadata.totalDataPoints}`);
    } else {
      console.log('❌ Session metadata not updated');
    }

    // Test 5: Test device assignment retrieval
    console.log('\n4️⃣ Testing assignment retrieval...');
    const assignmentSnapshot = await db.ref('devices/AnxieEase001/assignment').once('value');
    const assignment = assignmentSnapshot.val();
    
    if (assignment && assignment.userId === testUserId) {
      console.log('✅ Assignment retrieval successful');
      console.log(`   Assigned to: ${assignment.userId}`);
      console.log(`   Session ID: ${assignment.sessionId}`);
    } else {
      console.log('❌ Assignment not found');
    }

    console.log('\n🎉 Multi-User System Test Complete!');
    console.log('\nNext Steps:');
    console.log('1. Use the admin_device_assignment_helpers.js functions in your admin interface');
    console.log('2. Connect your physical device to write to /devices/AnxieEase001/current');
    console.log('3. Users can access their data at /users/{userId}/sessions/{sessionId}');

  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    // Cleanup - unassign device
    console.log('\n🧹 Cleaning up test data...');
    await db.ref('devices/AnxieEase001/assignment').remove();
    await db.ref(`users/${testUserId}`).remove();
    console.log('✅ Cleanup complete');
    
    process.exit(0);
  }
}

// Run the test
testMultiUserSystem();