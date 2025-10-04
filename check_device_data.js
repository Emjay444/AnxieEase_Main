const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app'
});

const db = admin.database();

async function checkDeviceData() {
  try {
    console.log('🔍 Checking device data in Firebase...');
    
    // Check current device data
    const currentRef = db.ref('devices/AnxieEase001/current');
    const currentSnapshot = await currentRef.once('value');
    const currentData = currentSnapshot.val();
    
    console.log('📱 Current device data:', JSON.stringify(currentData, null, 2));
    
    if (currentData) {
      console.log('\n📊 Parsed values:');
      console.log('- Heart Rate:', currentData.heartRate);
      console.log('- Body Temp:', currentData.bodyTemp);
      console.log('- Ambient Temp:', currentData.ambientTemp);
      console.log('- Battery %:', currentData.battPerc);
      console.log('- Device Worn:', currentData.worn);
      console.log('- Timestamp:', currentData.timestamp);
      
      if (currentData.timestamp) {
        const dataTime = new Date(currentData.timestamp);
        const now = new Date();
        const ageSeconds = Math.floor((now - dataTime) / 1000);
        console.log('- Data age:', ageSeconds, 'seconds');
        console.log('- Data time:', dataTime.toISOString());
        console.log('- Current time:', now.toISOString());
      }
    }
    
    // Check historical data
    const historyRef = db.ref('devices/AnxieEase001/history');
    const historySnapshot = await historyRef.limitToLast(5).once('value');
    const historyData = historySnapshot.val();
    
    console.log('\n🕒 Recent history (last 5):');
    if (historyData) {
      Object.keys(historyData).forEach(key => {
        const entry = historyData[key];
        console.log(`  ${key}: battPerc=${entry.battPerc}, HR=${entry.heartRate}, timestamp=${entry.timestamp}`);
      });
    } else {
      console.log('  No history data found');
    }
    
  } catch (error) {
    console.error('❌ Error checking device data:', error);
  }
}

checkDeviceData().then(() => {
  console.log('\n✅ Device data check complete');
  process.exit(0);
}).catch(error => {
  console.error('❌ Failed to check device data:', error);
  process.exit(1);
});