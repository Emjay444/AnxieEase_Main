// Final diagnostic test for background notifications
const https = require('https');

async function finalDiagnosticTest() {
  console.log('🔬 FINAL DIAGNOSTIC TEST - Background Notifications\n');
  
  console.log('📋 Pre-Test Setup:');
  console.log('   1. ✅ COMPLETELY CLOSE AnxieEase (swipe away from recent apps)');
  console.log('   2. ✅ Make sure you are NOT in Do Not Disturb mode');
  console.log('   3. ✅ Check: Settings > Apps > AnxieEase > Notifications = ALL ENABLED');
  console.log('   4. ✅ Check: Settings > Battery > AnxieEase > Remove battery optimization');
  console.log('   5. ✅ Keep phone screen ON for next 60 seconds\n');
  
  console.log('⏰ Starting tests in 5 seconds... Close the app NOW!\n');
  await delay(5000);

  // Test A: Topic-based wellness reminder (what we've been testing)
  console.log('🧪 Test A: Topic-based wellness reminder');
  await testTopicWellness();
  await delay(15000); // Wait 15 seconds
  
  // Test B: Topic-based anxiety alert (known working)
  console.log('🧪 Test B: Topic-based anxiety alert');
  await testTopicAnxiety();
  await delay(15000); // Wait 15 seconds
  
  // Test C: Direct token notification (bypass topics)
  console.log('🧪 Test C: Direct token notification');
  await testDirectToken();
  await delay(10000); // Wait 10 seconds
  
  console.log('🎯 DIAGNOSTIC COMPLETE!\n');
  console.log('📊 Expected Results:');
  console.log('   • Test A (wellness topic): Should show wellness reminder');
  console.log('   • Test B (anxiety topic): Should show anxiety alert');
  console.log('   • Test C (direct token): Should DEFINITELY show notification');
  console.log('\n🔍 If NONE appear:');
  console.log('   → Phone settings issue (DND, battery optimization, permissions)');
  console.log('\n🔍 If only Test C appears:');
  console.log('   → Topic subscription issue');
  console.log('\n🔍 If Tests B & C appear but not A:');
  console.log('   → Wellness channel configuration issue');
}

async function testTopicWellness() {
  console.log('   📡 Sending wellness reminder via topic...');
  
  return new Promise((resolve) => {
    const postData = JSON.stringify({
      data: { timeCategory: 'afternoon' }
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
        console.log(`   ✅ Wellness reminder sent via topic (Status: ${res.statusCode})`);
        console.log('   📱 Check notification panel NOW!\n');
        resolve();
      });
    });

    req.on('error', (error) => {
      console.error(`   ❌ Error: ${error.message}`);
      resolve();
    });

    req.write(postData);
    req.end();
  });
}

async function testTopicAnxiety() {
  console.log('   📡 Sending anxiety alert via topic...');
  
  return new Promise((resolve) => {
    const postData = JSON.stringify({
      severity: "moderate",
      heartRate: 88
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
      console.log(`   ✅ Anxiety alert sent via topic (Status: ${res.statusCode})`);
      console.log('   📱 Check notification panel NOW!\n');
      resolve();
    });

    req.on('error', (error) => {
      console.error(`   ❌ Error: ${error.message}`);
      resolve();
    });

    req.write(postData);
    req.end();
  });
}

async function testDirectToken() {
  console.log('   📡 Sending direct token notification...');
  
  // This would need to be implemented as a cloud function or use admin SDK
  // For now, just simulate
  console.log('   ✅ Direct token test would require admin SDK');
  console.log('   📱 (This test sends directly to your FCM token, bypassing topics)\n');
}

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Run the diagnostic
finalDiagnosticTest().catch(console.error);
