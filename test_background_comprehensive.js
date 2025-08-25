// Comprehensive test for background notifications
const https = require('https');

async function testBackgroundNotifications() {
  console.log('🔍 Comprehensive Background Notification Test\n');
  
  console.log('📋 Testing Steps:');
  console.log('   1. ✅ Close AnxieEase app completely (swipe away from recent apps)');
  console.log('   2. ✅ Keep phone screen on or check notification panel frequently');
  console.log('   3. ✅ Make sure phone is not in Do Not Disturb mode');
  console.log('   4. ✅ Ensure AnxieEase has notification permissions enabled');
  console.log('   5. ✅ Run this test\n');

  // Test 1: Anxiety Alert (should work since it was working before)
  console.log('🧪 Test 1: Anxiety Alert (baseline test)');
  await testAnxietyAlert();
  
  await delay(3000);
  
  // Test 2: Wellness Reminder
  console.log('🧪 Test 2: Wellness Reminder (new feature)');
  await testWellnessReminder();
  
  await delay(3000);
  
  // Test 3: Different category wellness reminder
  console.log('🧪 Test 3: Different Wellness Category');
  await testWellnessReminder('evening');
  
  console.log('\n🔍 Troubleshooting Checklist:');
  console.log('   📱 App Status: Make sure AnxieEase app is completely closed');
  console.log('   🔔 Notifications: Check Settings > Apps > AnxieEase > Notifications');
  console.log('   🔋 Battery: Check Settings > Battery > AnxieEase (disable optimization)');
  console.log('   📊 Data: Check if mobile data/WiFi is working');
  console.log('   🎯 Topic: Verify app subscribed to "wellness_reminders" topic');
  console.log('   ⏰ Timing: Notifications may take 10-30 seconds to appear');
}

function testAnxietyAlert() {
  return new Promise((resolve) => {
    console.log('   📡 Sending anxiety alert...');
    
    // Simulate anxiety data change to trigger notification
    const postData = JSON.stringify({
      severity: "moderate",
      heartRate: 95,
      timestamp: Date.now()
    });

    const options = {
      hostname: 'us-central1-anxieease-sensors.cloudfunctions.net',
      port: 443,
      path: '/sendTestNotificationV2',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        console.log(`   ✅ Anxiety alert sent (Status: ${res.statusCode})`);
        console.log(`   📱 Check your phone for notification!\n`);
        resolve();
      });
    });

    req.on('error', (error) => {
      console.error(`   ❌ Error sending anxiety alert: ${error.message}`);
      resolve();
    });

    req.write(postData);
    req.end();
  });
}

function testWellnessReminder(category = 'afternoon') {
  return new Promise((resolve) => {
    console.log(`   📡 Sending ${category} wellness reminder...`);
    
    const postData = JSON.stringify({
      data: { timeCategory: category }
    });

    const options = {
      hostname: 'us-central1-anxieease-sensors.cloudfunctions.net',
      port: 443,
      path: '/sendManualWellnessReminder',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          const result = JSON.parse(data);
          if (result.result && result.result.success) {
            console.log(`   ✅ ${category} wellness reminder sent!`);
            console.log(`   📱 Title: "${result.result.message.title}"`);
            console.log(`   💬 Body: "${result.result.message.body}"`);
            console.log(`   📱 Check your phone for notification!\n`);
          } else {
            console.log(`   ⚠️ ${category} reminder failed:`, result);
          }
        } catch (error) {
          console.log(`   📱 Response: ${data}`);
        }
        resolve();
      });
    });

    req.on('error', (error) => {
      console.error(`   ❌ Error sending ${category} reminder: ${error.message}`);
      resolve();
    });

    req.write(postData);
    req.end();
  });
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Run the comprehensive test
testBackgroundNotifications().catch(console.error);
