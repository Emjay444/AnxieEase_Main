const https = require('https');

// Test comprehensive data payload for anxiety notification
const testNotificationData = {
  "current": {
    "heartRate": 85,
    "sessionId": "test_session_enhanced",
    "timestamp": Date.now(),
    "duration": 45,
    "averageHeartRate": 85
  }
};

const postData = JSON.stringify(testNotificationData);

const options = {
  hostname: 'anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app',
  port: 443,
  path: '/devices/TEST_DEVICE_ID/current.json',
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(postData)
  }
};

console.log('🧪 Testing enhanced data payload notification...');
console.log('📊 Sending data:', testNotificationData);
console.log('🎯 This should trigger notification with comprehensive data payload');

const req = https.request(options, (res) => {
  console.log(`✅ Response status: ${res.statusCode}`);
  
  let responseData = '';
  res.on('data', (chunk) => {
    responseData += chunk;
  });
  
  res.on('end', () => {
    console.log('📥 Firebase response:', responseData);
    console.log('');
    console.log('🔍 Expected in notification payload:');
    console.log('   • notification.title: "Anxiety Alert"');
    console.log('   • notification.body: Alert message');
    console.log('   • data.type: "anxiety_alert"');
    console.log('   • data.title: Alert title for app sync');
    console.log('   • data.message: Alert body for app sync');
    console.log('   • data.timestamp: Current timestamp');
    console.log('   • data.severity: Determined by system');
    console.log('   • data.heartRate: "85"');
    console.log('   • data.duration: "45"');
    console.log('   • data.reason: Context about detection');
    console.log('');
    console.log('🎯 Check your device for notification!');
    console.log('📱 Then open app normally (don\'t tap notification)');
    console.log('✅ Notification should appear in app notification screen');
  });
});

req.on('error', (e) => {
  console.error(`❌ Request error: ${e.message}`);
});

req.write(postData);
req.end();