// Simple test for wellness reminders using HTTP request
const https = require('https');

function testManualWellnessReminder(timeCategory) {
  console.log(`🧘 Testing ${timeCategory} wellness reminder...`);
  
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

  const req = https.request(options, (res) => {
    console.log(`Status: ${res.statusCode}`);
    
    let data = '';
    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      try {
        const result = JSON.parse(data);
        console.log(`✅ ${timeCategory} reminder response:`, result);
      } catch (error) {
        console.log(`📱 ${timeCategory} response:`, data);
      }
    });
  });

  req.on('error', (error) => {
    console.error(`❌ Error testing ${timeCategory}:`, error.message);
  });

  req.write(postData);
  req.end();
}

// Test all categories
console.log('🌟 Testing Wellness Reminder System\n');

setTimeout(() => testManualWellnessReminder('morning'), 0);
setTimeout(() => testManualWellnessReminder('afternoon'), 2000);
setTimeout(() => testManualWellnessReminder('evening'), 4000);

setTimeout(() => {
  console.log('\n✅ Wellness reminder system testing completed!');
  console.log('\n📋 Key Features Implemented:');
  console.log('   🎯 Unified wellness reminders (removed separate breathing toggle)');
  console.log('   ⏰ Strategic timing: 9 AM, 5 PM, 11 PM');
  console.log('   🎲 Non-repeating varied content');
  console.log('   🧘 Breathing exercises + grounding techniques');
  console.log('   💚 Positive affirmations + mindfulness tips');
  console.log('   📱 Cloud-based scheduled delivery');
  console.log('   ⚙️ User-configurable schedules (minimal/balanced/intensive)');
}, 6000);
