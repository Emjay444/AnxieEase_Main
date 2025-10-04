/**
 * Real-time Testing Script for Baseline 73.2 BPM
 * Copy-paste this into Firebase Console > Functions for testing
 */

const DEVICE_ID = "AnxieEase001"; // Your device ID
const BASELINE_HR = 73.2;

// Exact testing values for your baseline
const TEST_VALUES = {
  mild: 92, // 25% above baseline
  moderate: 99, // 35% above baseline
  severe: 117, // 60% above baseline
  critical: 138, // 90% above baseline
};

console.log(`📊 Testing with baseline: ${BASELINE_HR} BPM`);
console.log(`🟢 Mild: ${TEST_VALUES.mild} BPM (needs 30+ seconds)`);
console.log(`🟠 Moderate: ${TEST_VALUES.moderate} BPM (needs 30+ seconds)`);
console.log(`🔴 Severe: ${TEST_VALUES.severe} BPM (needs 30+ seconds)`);
console.log(`🚨 Critical: ${TEST_VALUES.critical} BPM (needs 30+ seconds)`);

// Run in Firebase Console Functions
async function testMild() {
  console.log("🟢 Starting MILD test...");
  for (let i = 0; i < 35; i++) {
    await admin
      .database()
      .ref(`/devices/${DEVICE_ID}/current`)
      .set({
        heartRate: TEST_VALUES.mild + Math.floor(Math.random() * 2),
        timestamp: Date.now(),
        spo2: 98,
        worn: 1,
        battPerc: 85,
      });
    console.log(`📊 ${i + 1}/35s: ${TEST_VALUES.mild} BPM`);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  console.log("✅ MILD test completed!");
}

async function testModerate() {
  console.log("🟠 Starting MODERATE test...");
  for (let i = 0; i < 35; i++) {
    await admin
      .database()
      .ref(`/devices/${DEVICE_ID}/current`)
      .set({
        heartRate: TEST_VALUES.moderate + Math.floor(Math.random() * 2),
        timestamp: Date.now(),
        spo2: 98,
        worn: 1,
        battPerc: 85,
      });
    console.log(`📊 ${i + 1}/35s: ${TEST_VALUES.moderate} BPM`);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  console.log("✅ MODERATE test completed!");
}

async function testSevere() {
  console.log("🔴 Starting SEVERE test...");
  for (let i = 0; i < 35; i++) {
    await admin
      .database()
      .ref(`/devices/${DEVICE_ID}/current`)
      .set({
        heartRate: TEST_VALUES.severe + Math.floor(Math.random() * 2),
        timestamp: Date.now(),
        spo2: 98,
        worn: 1,
        battPerc: 85,
      });
    console.log(`📊 ${i + 1}/35s: ${TEST_VALUES.severe} BPM`);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  console.log("✅ SEVERE test completed!");
}

async function testCritical() {
  console.log("🚨 Starting CRITICAL test...");
  for (let i = 0; i < 35; i++) {
    await admin
      .database()
      .ref(`/devices/${DEVICE_ID}/current`)
      .set({
        heartRate: TEST_VALUES.critical + Math.floor(Math.random() * 2),
        timestamp: Date.now(),
        spo2: 98,
        worn: 1,
        battPerc: 85,
      });
    console.log(`📊 ${i + 1}/35s: ${TEST_VALUES.critical} BPM`);
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  console.log("✅ CRITICAL test completed!");
}

// Uncomment one line to test:
// testMild();
// testModerate();
// testSevere();
// testCritical();
