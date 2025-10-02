#!/usr/bin/env node

/**
 * 🔥 REAL ANXIETY DETECTION SIMULATOR
 * 
 * This script simulates real device data to trigger actual anxiety detection
 * It writes data to Firebase Realtime Database that will trigger the real detection functions
 * 
 * Usage:
 *   node simulate_real_anxiety.js
 *   node simulate_real_anxiety.js mild
 *   node simulate_real_anxiety.js severe
 */

const admin = require('firebase-admin');
const path = require('path');

// Color codes for console output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m'
};

// Initialize Firebase Admin with service account
const serviceAccountPath = path.join(__dirname, 'functions', 'anxieease-sensors-firebase-adminsdk-key.json');

let firebaseApp;
try {
  const serviceAccount = require(serviceAccountPath);
  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app"
  });
  console.log(`${colors.green}✅ Firebase Admin initialized successfully${colors.reset}`);
} catch (error) {
  console.log(`${colors.red}❌ Error initializing Firebase Admin:${colors.reset}`);
  console.log(`${colors.red}   Make sure the service account key exists at: ${serviceAccountPath}${colors.reset}`);
  console.log(`${colors.yellow}   You can download it from Firebase Console > Project Settings > Service Accounts${colors.reset}`);
  process.exit(1);
}

const db = admin.database();

// Real anxiety simulation scenarios
const anxietyScenarios = {
  mild: {
    name: 'Mild Anxiety Episode',
    description: 'Slight elevation in heart rate, normal SpO2',
    baselineHR: 73.2, // Your actual baseline
    targetHR: 91, // 25% above your baseline (73.2 * 1.25)
    spo2: 98,
    movementLevel: 15,
    duration: 30, // seconds
    severity: 'mild'
  },
  moderate: {
    name: 'Moderate Anxiety Episode', 
    description: 'Elevated heart rate with slight movement increase',
    baselineHR: 73.2, // Your actual baseline
    targetHR: 102, // 39% above baseline (73.2 * 1.39)
    spo2: 97,
    movementLevel: 35,
    duration: 45,
    severity: 'moderate'
  },
  severe: {
    name: 'Severe Anxiety Episode',
    description: 'High heart rate, low SpO2, increased movement',
    baselineHR: 73.2, // Your actual baseline
    targetHR: 122, // 67% above baseline (73.2 * 1.67)
    spo2: 93,
    movementLevel: 65,
    duration: 60,
    severity: 'severe'
  },
  critical: {
    name: 'Critical Anxiety Episode',
    description: 'Very high heart rate, concerning SpO2 levels',
    baselineHR: 73.2, // Your actual baseline
    targetHR: 146, // 100% above baseline (73.2 * 2.0)
    spo2: 89,
    movementLevel: 85,
    duration: 90,
    severity: 'critical'
  }
};

// Your actual user ID (update this with your real user ID from Supabase)
const USER_ID = '5afad7d4-3dcd-4353-badb-4f155303419a'; // Your actual user ID
const DEVICE_ID = 'AnxieEase001';

/**
 * Set up user baseline in Firebase (required for detection)
 */
async function setupUserBaseline(baselineHR) {
  try {
    await db.ref(`/users/${USER_ID}/baseline`).set({
      heartRate: baselineHR,
      timestamp: Date.now(),
      source: 'simulation_setup',
      deviceId: DEVICE_ID,
    });

    // Also set device metadata
    await db.ref(`/devices/${DEVICE_ID}/metadata`).set({
      userId: USER_ID,
      assignedUser: USER_ID,
      deviceId: DEVICE_ID,
      lastSync: admin.database.ServerValue.TIMESTAMP,
      source: 'simulation_setup',
    });

    console.log(`${colors.green}✅ User baseline set to ${baselineHR} BPM${colors.reset}`);
    return true;
  } catch (error) {
    console.log(`${colors.red}❌ Error setting up baseline: ${error.message}${colors.reset}`);
    return false;
  }
}

/**
 * Simulate device data that will trigger real anxiety detection
 */
async function simulateAnxietyEpisode(scenario) {
  console.log(`${colors.bright}🚨 Simulating: ${scenario.name}${colors.reset}`);
  console.log(`${colors.cyan}📝 ${scenario.description}${colors.reset}`);
  console.log(`${colors.cyan}⏱️  Duration: ${scenario.duration} seconds${colors.reset}`);
  console.log(`${colors.cyan}💓 Baseline HR: ${scenario.baselineHR} BPM → Target: ${scenario.targetHR} BPM${colors.reset}`);
  console.log(`${colors.cyan}🫁 SpO2: ${scenario.spo2}% | Movement: ${scenario.movementLevel}%${colors.reset}\n`);

  // Step 1: Set up baseline
  console.log(`${colors.blue}📊 Setting up user baseline...${colors.reset}`);
  const baselineSetup = await setupUserBaseline(scenario.baselineHR);
  if (!baselineSetup) {
    console.log(`${colors.red}❌ Failed to set up baseline. Aborting simulation.${colors.reset}`);
    return;
  }

  // Wait a moment for baseline to be processed
  await new Promise(resolve => setTimeout(resolve, 2000));

  // Step 2: Gradually increase values to target
  console.log(`${colors.blue}📈 Starting gradual progression to anxiety levels...${colors.reset}`);
  
  const rampUpSteps = 5; // Fewer steps to reach target faster
  const sustainedDuration = Math.max(scenario.duration - 15, 20); // Most of the time at target
  const rampUpDuration = 15; // 15 seconds to reach target
  
  // Phase 1: Ramp up to target values (15 seconds)
  console.log(`${colors.cyan}📈 Phase 1: Ramping up to target values (15 seconds)...${colors.reset}`);
  for (let i = 0; i <= rampUpSteps; i++) {
    const progress = i / rampUpSteps;
    
    const currentHR = Math.round(
      scenario.baselineHR + (scenario.targetHR - scenario.baselineHR) * progress
    );
    const currentSpO2 = Math.round(scenario.spo2 - (progress * 2));
    const currentMovement = Math.round(scenario.movementLevel * progress);
    
    const hrVariation = Math.random() * 2 - 1; // ±1 BPM variation
    const finalHR = Math.max(scenario.baselineHR, currentHR + hrVariation);
    
    const deviceData = {
      heartRate: Math.round(finalHR),
      spo2: Math.max(85, currentSpO2),
      movementLevel: currentMovement,
      battPerc: 85,
      timestamp: Date.now(),
      source: 'anxiety_simulation_rampup'
    };

    try {
      await db.ref(`/devices/${DEVICE_ID}/current`).set(deviceData);
      console.log(`${colors.yellow}⚡ Ramp ${i + 1}/${rampUpSteps + 1}: HR=${deviceData.heartRate} BPM, SpO2=${deviceData.spo2}%, Movement=${deviceData.movementLevel}%${colors.reset}`);
      
      if (i < rampUpSteps) {
        await new Promise(resolve => setTimeout(resolve, 3000)); // 3 seconds between ramp steps
      }
    } catch (error) {
      console.log(`${colors.red}❌ Error writing device data: ${error.message}${colors.reset}`);
    }
  }

  // Phase 2: Maintain target values for sustained period
  console.log(`${colors.red}🔥 Phase 2: Maintaining target anxiety levels for ${sustainedDuration} seconds...${colors.reset}`);
  const sustainedSteps = Math.floor(sustainedDuration / 5); // Update every 5 seconds
  
  for (let i = 0; i < sustainedSteps; i++) {
    // Keep values at target with small realistic variations
    const hrVariation = Math.random() * 6 - 3; // ±3 BPM variation around target
    const finalHR = Math.round(scenario.targetHR + hrVariation);
    const spo2Variation = Math.random() * 2 - 1; // ±1% SpO2 variation
    const finalSpO2 = Math.round(scenario.spo2 + spo2Variation);
    const movementVariation = Math.random() * 10 - 5; // ±5% movement variation
    const finalMovement = Math.max(0, Math.round(scenario.movementLevel + movementVariation));
    
    const deviceData = {
      heartRate: Math.max(scenario.baselineHR + 5, finalHR), // Ensure it stays elevated
      spo2: Math.max(85, Math.min(100, finalSpO2)),
      movementLevel: Math.min(100, finalMovement),
      battPerc: 85,
      timestamp: Date.now(),
      source: 'anxiety_simulation_sustained'
    };

    try {
      await db.ref(`/devices/${DEVICE_ID}/current`).set(deviceData);
      console.log(`${colors.red}🚨 Sustained ${i + 1}/${sustainedSteps}: HR=${deviceData.heartRate} BPM (Target: ${scenario.targetHR}), SpO2=${deviceData.spo2}%, Movement=${deviceData.movementLevel}%${colors.reset}`);
      
      // Wait 5 seconds before next update
      if (i < sustainedSteps - 1) {
        await new Promise(resolve => setTimeout(resolve, 5000));
      }
    } catch (error) {
      console.log(`${colors.red}❌ Error writing sustained data: ${error.message}${colors.reset}`);
    }
  }

  console.log(`${colors.green}\n🎉 Simulation completed!${colors.reset}`);
  console.log(`${colors.cyan}📱 Check your device for real anxiety detection notifications${colors.reset}`);
  console.log(`${colors.cyan}📋 The real anxiety detection functions should have triggered${colors.reset}`);
  console.log(`${colors.cyan}🔔 You should receive actual notifications (not test ones)${colors.reset}`);
}

/**
 * Reset device to normal values
 */
async function resetToNormal() {
  console.log(`${colors.blue}🔄 Resetting device to normal values...${colors.reset}`);
  
  const normalData = {
    heartRate: 72,
    spo2: 98,
    movementLevel: 5,
    battPerc: 85,
    timestamp: Date.now(),
    source: 'reset_to_normal'
  };

  try {
    await db.ref(`/devices/${DEVICE_ID}/current`).set(normalData);
    console.log(`${colors.green}✅ Device reset to normal values${colors.reset}`);
  } catch (error) {
    console.log(`${colors.red}❌ Error resetting device: ${error.message}${colors.reset}`);
  }
}

/**
 * Show usage instructions
 */
function showUsage() {
  console.log(`${colors.bright}🔥 REAL ANXIETY DETECTION SIMULATOR${colors.reset}\n`);
  console.log(`${colors.cyan}Usage:${colors.reset}`);
  console.log(`  node simulate_real_anxiety.js                # Simulate mild anxiety`);
  console.log(`  node simulate_real_anxiety.js <severity>     # Simulate specific severity\n`);
  console.log(`  node simulate_real_anxiety.js reset          # Reset to normal values\n`);
  
  console.log(`${colors.cyan}Available severity levels:${colors.reset}`);
  Object.entries(anxietyScenarios).forEach(([key, scenario]) => {
    const emoji = key === 'mild' ? '🟢' : key === 'moderate' ? '🟠' : key === 'severe' ? '🔴' : '🚨';
    console.log(`  ${emoji} ${key.padEnd(10)} - ${scenario.description}`);
  });
  
  console.log(`\n${colors.cyan}How it works:${colors.reset}`);
  console.log(`  1. Sets up your user baseline in Firebase`);
  console.log(`  2. Gradually increases heart rate and other metrics`);
  console.log(`  3. Real anxiety detection functions analyze the data`);
  console.log(`  4. Triggers actual anxiety notifications (not test ones)`);
  console.log(`  5. You receive real notifications in your app\n`);
  
  console.log(`${colors.yellow}📋 Prerequisites:${colors.reset}`);
  console.log(`  1. AnxieEase app installed and logged in`);
  console.log(`  2. Firebase Admin SDK key in functions/ folder`);
  console.log(`  3. Real anxiety detection Cloud Functions deployed`);
  console.log(`  4. Update USER_ID in this script with your actual user ID\n`);
  
  console.log(`${colors.yellow}🔧 Setup:${colors.reset}`);
  console.log(`  1. Get your user ID from Supabase auth table`);
  console.log(`  2. Update USER_ID variable in this script`);
  console.log(`  3. Download Firebase Admin SDK key to functions/ folder\n`);
}

/**
 * Main function
 */
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    // Default to mild anxiety simulation
    await simulateAnxietyEpisode(anxietyScenarios.mild);
  } else if (args.length === 1) {
    const command = args[0].toLowerCase();
    
    if (command === 'help' || command === '--help' || command === '-h') {
      showUsage();
      return;
    }
    
    if (command === 'reset') {
      await resetToNormal();
      return;
    }
    
    // Simulate specific severity
    if (anxietyScenarios[command]) {
      await simulateAnxietyEpisode(anxietyScenarios[command]);
    } else {
      console.log(`${colors.red}❌ Unknown severity level: ${command}${colors.reset}\n`);
      showUsage();
    }
  } else {
    console.log(`${colors.red}❌ Too many arguments${colors.reset}\n`);
    showUsage();
  }
}

// Handle unhandled errors
process.on('unhandledRejection', (error) => {
  console.log(`${colors.red}💥 Unhandled error: ${error.message}${colors.reset}`);
  process.exit(1);
});

// Run the script
if (require.main === module) {
  main().catch(error => {
    console.log(`${colors.red}💥 Script failed: ${error.message}${colors.reset}`);
    process.exit(1);
  }).finally(() => {
    // Clean shutdown
    if (firebaseApp) {
      setTimeout(() => {
        process.exit(0);
      }, 1000);
    }
  });
}