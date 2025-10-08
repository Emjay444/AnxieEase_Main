const admin = require('firebase-admin');
const readline = require('readline');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app"
});

const db = admin.database();

// Configuration - Using your existing real user setup
const DEVICE_ID = 'AnxieEase001';
const REAL_USER_ID = 'e0997cb7-68df-41e6-923f-48107872d434'; // Your existing user (corrected ID)
const REAL_SESSION_ID = 'session_1759943526082'; // Your existing session
const BASELINE_HR = 88.2; // Your actual baseline from Firebase
const SEND_INTERVAL_MS = 10000; // 10 seconds

// Test patterns for different anxiety levels based on your baseline (88.2 BPM)
const ANXIETY_PATTERNS = {
  mild: {
    name: 'Mild Anxiety',
    description: '20-29% above baseline (88.2)',
    hrRange: [Math.round(BASELINE_HR * 1.20), Math.round(BASELINE_HR * 1.29)], // ~106-114 BPM
    color: '🟡'
  },
  moderate: {
    name: 'Moderate Anxiety', 
    description: '30-49% above baseline (88.2)',
    hrRange: [Math.round(BASELINE_HR * 1.30), Math.round(BASELINE_HR * 1.49)], // ~115-131 BPM
    color: '🟠'
  },
  severe: {
    name: 'Severe Anxiety',
    description: '50-79% above baseline (88.2)', 
    hrRange: [Math.round(BASELINE_HR * 1.50), Math.round(BASELINE_HR * 1.79)], // ~132-158 BPM
    color: '🔴'
  },
  critical: {
    name: 'Critical Anxiety',
    description: '80%+ above baseline (88.2)',
    hrRange: [Math.round(BASELINE_HR * 1.80), Math.round(BASELINE_HR * 1.95)], // ~159-172 BPM
    color: '🚨'
  },
  normal: {
    name: 'Normal Range',
    description: 'Below anxiety threshold',
    hrRange: [Math.round(BASELINE_HR - 5), Math.round(BASELINE_HR * 1.15)], // ~83-101 BPM
    color: '🟢'
  }
};

let currentInterval = null;
let isRunning = false;

// Helper function to generate realistic sensor data
function generateSensorData(heartRate, anxietyLevel = 'normal') {
  const now = Date.now();
  
  // Simulate realistic values with some variation
  const spo2 = 95 + Math.random() * 4; // 95-99%
  const bodyTemp = 36.1 + Math.random() * 0.8; // 36.1-36.9°C
  
  // Lower movement for anxiety (vs exercise) to avoid false positive detection
  const accelVariation = anxietyLevel === 'normal' ? 0.5 : 0.2;
  const accelX = (Math.random() - 0.5) * accelVariation;
  const accelY = (Math.random() - 0.5) * accelVariation; 
  const accelZ = 9.8 + (Math.random() - 0.5) * accelVariation; // Gravity + small variation
  
  return {
    timestamp: now,
    heartRate: Math.round(heartRate),
    spo2: Math.round(spo2 * 10) / 10,
    bodyTemp: Math.round(bodyTemp * 10) / 10,
    accelX: Math.round(accelX * 100) / 100,
    accelY: Math.round(accelY * 100) / 100,
    accelZ: Math.round(accelZ * 100) / 100,
    worn: 1, // Device is worn
    batteryLevel: 85 + Math.random() * 10 // 85-95%
  };
}

// Verify existing setup (using your real data)
async function verifyExistingEnvironment() {
  console.log('� Verifying existing Firebase setup...');
  
  try {
    // Check device assignment
    const assignmentSnapshot = await db.ref(`/devices/${DEVICE_ID}/assignment`).once('value');
    const assignment = assignmentSnapshot.val();
    
    if (assignment && assignment.assignedUser) {
      console.log(`✅ Device ${DEVICE_ID} is assigned to user: ${assignment.assignedUser}`);
      console.log(`✅ Active session: ${assignment.activeSessionId}`);
      
      // Check FCM token for notifications
      if (assignment.fcmToken) {
        console.log(`✅ FCM token found: ${assignment.fcmToken.substring(0, 20)}...`);
        console.log(`✅ Token last refreshed: ${assignment.lastTokenRefresh || 'Unknown'}`);
      } else {
        console.log('⚠️ NO FCM TOKEN FOUND!');
        console.log('📱 To enable notifications when app is closed:');
        console.log('   1. Open your AnxieEase app on the assigned device');
        console.log('   2. Log in with the assigned user account');
        console.log('   3. The app will automatically generate and store FCM token');
        console.log('   4. Check Firebase Console to see the token appear');
        console.log('   5. Then close the app and run this test again');
        console.log('');
        console.log('💡 Without FCM token, anxiety alerts won\'t be sent when app is closed');
        console.log('');
      }
    } else {
      console.log('❌ No device assignment found');
      return false;
    }
    
    // Check user baseline (corrected path)
    const baselineSnapshot = await db.ref(`/users/${REAL_USER_ID}/baseline`).once('value');
    const baseline = baselineSnapshot.val();
    
    if (baseline && baseline.heartRate) {
      console.log(`✅ User baseline found: ${baseline.heartRate} BPM`);
    } else {
      console.log('❌ No baseline found for user');
      return false;
    }
    
    console.log('🎯 Using your existing real setup!\n');
    return true;
    
  } catch (error) {
    console.error('❌ Error verifying environment:', error);
    return false;
  }
}

// Send sensor data to Firebase
async function sendSensorData(anxietyLevel) {
  const pattern = ANXIETY_PATTERNS[anxietyLevel];
  const [minHR, maxHR] = pattern.hrRange;
  const heartRate = minHR + Math.random() * (maxHR - minHR);
  
  const sensorData = generateSensorData(heartRate, anxietyLevel);
  
  try {
    // Write to device current data (this triggers the Firebase function)
    await db.ref(`/devices/${DEVICE_ID}/current`).set(sensorData);
    
    // Also write to user session current data (important for detection)
    await db.ref(`/users/${REAL_USER_ID}/sessions/${REAL_SESSION_ID}/current`).set(sensorData);
    
    // Add to user session history with timestamp key (matches your structure)
    const now = new Date();
    const historyKey = `${now.getFullYear()}_${String(now.getMonth() + 1).padStart(2, '0')}_${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}_${String(now.getMinutes()).padStart(2, '0')}_${String(now.getSeconds()).padStart(2, '0')}`;
    
    const historyData = {
      ...sensorData,
      copiedAt: Date.now(),
      source: "firebase_notification_tester"
    };
    
    await db.ref(`/users/${REAL_USER_ID}/sessions/${REAL_SESSION_ID}/history/${historyKey}`).set(historyData);
    
    // Update session metadata
    await db.ref(`/users/${REAL_USER_ID}/sessions/${REAL_SESSION_ID}/metadata`).update({
      lastActivity: Date.now(),
      lastDataTimestamp: sensorData.timestamp,
      totalDataPoints: admin.database.ServerValue.increment(1)
    });
    
    const percentageAbove = Math.round(((heartRate - BASELINE_HR) / BASELINE_HR) * 100);
    
    console.log(`${pattern.color} ${pattern.name} | HR: ${Math.round(heartRate)} BPM (+${percentageAbove}%) | ${new Date().toLocaleTimeString()}`);
    
  } catch (error) {
    console.error('❌ Error sending sensor data:', error);
  }
}

// Start continuous data sending
function startSending(anxietyLevel) {
  if (isRunning) {
    console.log('❌ Already running! Stop first.');
    return;
  }
  
  const pattern = ANXIETY_PATTERNS[anxietyLevel];
  console.log(`\n🎯 Starting ${pattern.color} ${pattern.name} simulation...`);
  console.log(`📊 HR Range: ${pattern.hrRange[0]}-${pattern.hrRange[1]} BPM (${pattern.description})`);
  console.log(`⏱️  Sending data every ${SEND_INTERVAL_MS/1000} seconds`);
  console.log(`📱 Watch for notifications on your mobile device!\n`);
  
  isRunning = true;
  
  // Send first data point immediately
  sendSensorData(anxietyLevel);
  
  // Then continue every 10 seconds
  currentInterval = setInterval(() => {
    sendSensorData(anxietyLevel);
  }, SEND_INTERVAL_MS);
}

// Stop sending data
function stopSending() {
  if (currentInterval) {
    clearInterval(currentInterval);
    currentInterval = null;
  }
  isRunning = false;
  console.log('\n⏹️  Stopped sending data.\n');
}

// Display menu
function showMenu() {
  console.log('\n=== AnxieEase Firebase Notification Tester ===');
  console.log(`Device: ${DEVICE_ID} | User: ${REAL_USER_ID} | Baseline: ${BASELINE_HR} BPM\n`);
  
  Object.entries(ANXIETY_PATTERNS).forEach(([key, pattern]) => {
    const [minHR, maxHR] = pattern.hrRange;
    console.log(`${key.padEnd(8)} - ${pattern.color} ${pattern.name} (${minHR}-${maxHR} BPM)`);
  });
  
  console.log('\nCommands:');
  console.log('start [level] - Start sending data (e.g., "start mild")');
  console.log('stop         - Stop sending data');
  console.log('menu         - Show this menu');
  console.log('quit         - Exit program');
  console.log('\nNote: Each level requires ~90 seconds of sustained data to trigger notifications');
  console.log('='.repeat(60));
}

// Main interactive loop
async function main() {
  console.log('🔥 AnxieEase Firebase Notification Tester');
  console.log('='.repeat(60));
  
  try {
    const isValid = await verifyExistingEnvironment();
    if (!isValid) {
      console.log('❌ Cannot proceed without proper Firebase setup');
      process.exit(1);
    }
    showMenu();
    
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    rl.setPrompt('\n> ');
    rl.prompt();
    
    rl.on('line', (input) => {
      const [command, ...args] = input.trim().toLowerCase().split(' ');
      
      switch (command) {
        case 'start':
          const level = args[0];
          if (!level || !ANXIETY_PATTERNS[level]) {
            console.log('❌ Invalid anxiety level. Use: mild, moderate, severe, critical, or normal');
          } else {
            startSending(level);
          }
          break;
          
        case 'stop':
          stopSending();
          break;
          
        case 'menu':
          showMenu();
          break;
          
        case 'quit':
        case 'exit':
          stopSending();
          console.log('👋 Goodbye!');
          rl.close();
          process.exit(0);
          break;
          
        default:
          console.log('❌ Unknown command. Type "menu" for help.');
      }
      
      rl.prompt();
    });
    
    rl.on('close', () => {
      stopSending();
      process.exit(0);
    });
    
  } catch (error) {
    console.error('💥 Failed to initialize:', error);
    process.exit(1);
  }
}

// Handle process termination
process.on('SIGINT', () => {
  console.log('\n👋 Shutting down...');
  stopSending();
  process.exit(0);
});

// Start the program
main().catch(console.error);