/**
 * Simple Alert Test - Direct notification trigger
 * Uses correct user and baseline from device assignment
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
});

const db = admin.database();

// Configuration
const DEVICE_ID = "AnxieEase001";
const USER_ID = "e0997cb7-68df-41e6-923f-48107872d434";
const BASELINE = 76.4;

// Heart rate values for each severity
const HEART_RATES = {
  mild: 96,      // 25% above baseline
  moderate: 107, // 40% above baseline  
  severe: 122,   // 60% above baseline
  critical: 138, // 80% above baseline
};

async function triggerAlert(severity) {
  console.log(`\n🎯 Triggering ${severity.toUpperCase()} alert`);
  console.log(`📊 Heart Rate: ${HEART_RATES[severity]} BPM (Baseline: ${BASELINE} BPM)`);
  
  const alertData = {
    severity: severity,
    heartRate: HEART_RATES[severity],
    timestamp: Date.now(),
    confidence: 85,
    baseline: BASELINE,
    alertType: "direct_test",
    deviceId: DEVICE_ID,
    userId: USER_ID,
    source: "test", // CRITICAL: Required for Cloud Function to process alert
  };

  try {
    // Write alert to database
    const alertRef = db.ref(`/devices/${DEVICE_ID}/alerts`).push();
    await alertRef.set(alertData);
    
    console.log(`✅ Alert created successfully!`);
    console.log(`📍 Alert ID: ${alertRef.key}`);
    console.log(`📱 Check your device for notification\n`);
    
    // Wait a bit for the Cloud Function to process
    console.log(`⏳ Waiting 5 seconds for Cloud Function to process...`);
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    console.log(`✅ Done! Check your device.`);
    
  } catch (error) {
    console.error(`❌ Error creating alert:`, error);
  } finally {
    process.exit(0);
  }
}

// Get severity from command line
const severity = process.argv[2] || 'mild';

if (!HEART_RATES[severity]) {
  console.error(`❌ Invalid severity: ${severity}`);
  console.log(`✅ Valid options: mild, moderate, severe, critical`);
  process.exit(1);
}

triggerAlert(severity);
