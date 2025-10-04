/**
 * Real-time Anxiety Testing Scripts
 * Feed continuous data to Firebase to trigger sustained anxiety detection
 *
 * Replace YOUR_DEVICE_ID with your actual device ID
 * Adjust BASELINE_HR to your actual baseline heart rate
 */

// Configuration
const DEVICE_ID = "AnxieEase001"; // Replace with your device ID
const BASELINE_HR = 70; // Replace with your actual baseline HR

// Calculated thresholds based on your baseline
const THRESHOLDS = {
  trigger: Math.round(BASELINE_HR * 1.2), // 20% above baseline (starts detection)
  mild: Math.round(BASELINE_HR * 1.25), // 25% above baseline
  moderate: Math.round(BASELINE_HR * 1.35), // 35% above baseline
  severe: Math.round(BASELINE_HR * 1.6), // 60% above baseline
  critical: Math.round(BASELINE_HR * 1.9), // 90% above baseline
};

console.log(`📊 Testing thresholds for ${BASELINE_HR} BPM baseline:`);
console.log(`🟢 Mild: ${THRESHOLDS.mild} BPM`);
console.log(`🟠 Moderate: ${THRESHOLDS.moderate} BPM`);
console.log(`🔴 Severe: ${THRESHOLDS.severe} BPM`);
console.log(`🚨 Critical: ${THRESHOLDS.critical} BPM`);

// Firebase Admin Setup (run this in Firebase Console > Functions)
async function sendContinuousData(severity, durationSeconds = 35) {
  const heartRates = {
    mild: THRESHOLDS.mild,
    moderate: THRESHOLDS.moderate,
    severe: THRESHOLDS.severe,
    critical: THRESHOLDS.critical,
  };

  const targetHR = heartRates[severity];
  console.log(
    `🔥 Starting ${severity} test: ${targetHR} BPM for ${durationSeconds}s`
  );

  for (let i = 0; i < durationSeconds; i++) {
    const data = {
      heartRate: targetHR + Math.floor(Math.random() * 3), // Add slight variation
      timestamp: Date.now(),
      spo2: 98,
      bodyTemp: 36.5,
      worn: 1,
      battPerc: 85,
    };

    // Write to Firebase Realtime Database
    await admin.database().ref(`/devices/${DEVICE_ID}/current`).set(data);

    console.log(`📊 ${i + 1}/${durationSeconds}s: HR ${data.heartRate} BPM`);

    // Wait 1 second between readings
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  console.log(`✅ ${severity} test completed!`);
}

// Test Functions - Call these in Firebase Console
// sendContinuousData('mild', 35);
// sendContinuousData('moderate', 35);
// sendContinuousData('severe', 35);
// sendContinuousData('critical', 35);
