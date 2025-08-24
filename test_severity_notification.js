const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin SDK
try {
  if (!fs.existsSync('./service-account-key.json')) {
    console.error('❌ service-account-key.json not found!');
    process.exit(1);
  }

  const serviceAccount = require('./service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://anxiease-5ac83-default-rtdb.asia-southeast1.firebasedatabase.app'
  });

  console.log('✅ Firebase Admin initialized');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin:', error);
  process.exit(1);
}

async function testSeverityNotification(severity = 'moderate') {
  try {
    console.log(`\n🚨 Testing ${severity} severity notification...`);
    
    // Simulate anxiety detection by writing to Firebase Realtime Database
    // This should trigger the Cloud Function automatically
    const metricsRef = admin.database().ref('/devices/AnxieEase001/Metrics');
    
    const testData = {
      heartRate: Math.floor(Math.random() * 40) + 70, // Random HR between 70-110
      anxietyDetected: {
        severity: severity,
        timestamp: Date.now(),
        confidence: 0.85
      },
      timestamp: Date.now()
    };

    console.log('📊 Writing test data to Firebase:', testData);
    await metricsRef.set(testData);
    
    console.log('✅ Test data written to Firebase successfully!');
    console.log('📱 This should trigger your Cloud Function to send a notification');
    console.log(`   Expected notification: "${severity}" alert with HR: ${testData.heartRate}`);
    
    return testData;
  } catch (error) {
    console.error('❌ Error sending test notification:', error);
    throw error;
  }
}

// Get severity from command line arguments or default to 'moderate'
const severity = process.argv[2] || 'moderate';
const validSeverities = ['mild', 'moderate', 'severe'];

if (!validSeverities.includes(severity)) {
  console.error(`❌ Invalid severity: ${severity}`);
  console.log(`Valid options: ${validSeverities.join(', ')}`);
  process.exit(1);
}

// Run the test
testSeverityNotification(severity).then((data) => {
  console.log('\n✨ Test completed successfully');
  console.log('📋 Instructions:');
  console.log('1. Keep your app open to see foreground notifications');
  console.log('2. Or close your app completely to test background notifications');
  console.log('3. You should receive a notification within 10 seconds');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Test failed:', error);
  process.exit(1);
});
