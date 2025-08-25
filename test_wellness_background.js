// Test wellness reminders when app is closed
const https = require('https');

function getCurrentTimeCategory() {
  const currentHour = new Date().getHours();
  
  if (currentHour >= 6 && currentHour < 12) {
    return "morning";
  } else if (currentHour >= 12 && currentHour < 18) {
    return "afternoon";
  } else {
    return "evening";
  }
}

function testWellnessReminderBackground(timeCategory) {
  console.log(`🧘 Testing ${timeCategory} wellness reminder (background mode)...`);
  
  const postData = JSON.stringify({
    data: { timeCategory: timeCategory }
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

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const result = JSON.parse(data);
          if (result.result && result.result.success) {
            console.log(`✅ ${timeCategory} reminder sent successfully!`);
            console.log(`   📱 Title: ${result.result.message.title}`);
            console.log(`   💬 Body: ${result.result.message.body}`);
            console.log(`   🎯 Type: ${result.result.message.type}`);
            console.log(`   📋 Message ID: ${result.result.messageId}`);
            console.log(`   📱 This notification should appear even if the app is closed!\n`);
            resolve(result);
          } else {
            console.log(`⚠️ ${timeCategory} reminder failed:`, result);
            resolve(result);
          }
        } catch (error) {
          console.error(`❌ Error parsing ${timeCategory} response:`, error.message);
          reject(error);
        }
      });
    });

    req.on('error', (error) => {
      console.error(`❌ Network error for ${timeCategory}:`, error.message);
      reject(error);
    });

    req.write(postData);
    req.end();
  });
}

async function runBackgroundTest() {
  console.log('🌟 Testing Wellness Reminders - Background Mode\n');
  console.log('📱 Instructions for testing:');
  console.log('   1. Close the AnxieEase app completely');
  console.log('   2. Keep your phone screen on (or check notification panel)');
  console.log('   3. Run this test');
  console.log('   4. You should receive notifications even with app closed\n');

  const currentCategory = getCurrentTimeCategory();
  console.log(`⏰ Current time category: ${currentCategory}\n`);

  try {
    // Test current time category
    await testWellnessReminderBackground(currentCategory);
    
    // Wait a bit and test another category
    console.log('⏳ Waiting 3 seconds before next test...\n');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Test a different category
    const otherCategories = ['morning', 'afternoon', 'evening'].filter(cat => cat !== currentCategory);
    await testWellnessReminderBackground(otherCategories[0]);

    console.log('✅ Background wellness reminder testing completed!');
    console.log('\n📋 What to verify:');
    console.log('   ✓ Notifications appear in system notification panel');
    console.log('   ✓ Notifications show even when app is completely closed');
    console.log('   ✓ Different message content for variety');
    console.log('   ✓ Appropriate timing for current hour');
    
    console.log('\n🔔 Scheduled times:');
    console.log('   • 9:00 AM - Morning wellness boost');
    console.log('   • 5:00 PM - Afternoon reset');
    console.log('   • 11:00 PM - Evening reflection');
    
  } catch (error) {
    console.error('❌ Error during background testing:', error);
  }
}

// Run the test
runBackgroundTest().catch(console.error);
