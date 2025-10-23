/**
 * Baseline Requirement Verification Script
 *
 * This script helps verify that anxiety detection is properly disabled
 * for users without a baseline heart rate set up.
 *
 * Run this in Firebase Console or via Node.js with Firebase Admin SDK
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin (if not already initialized)
// admin.initializeApp();

const db = admin.database();

/**
 * Check if a user has a baseline set up
 * @param {string} userId - The user ID to check
 * @param {string} deviceId - The device ID to check
 */
async function checkUserBaseline(userId, deviceId) {
  console.log(`\n🔍 Checking baseline for user: ${userId}`);
  console.log(`📱 Device: ${deviceId}\n`);

  // Check location 1: Device assignment
  const deviceBaselineRef = db.ref(
    `/devices/${deviceId}/assignment/supabaseSync/baselineHR`
  );
  const deviceSnapshot = await deviceBaselineRef.once("value");

  if (deviceSnapshot.exists()) {
    const baseline = deviceSnapshot.val();
    console.log(`✅ FOUND in device assignment: ${baseline} BPM`);
    console.log(
      `   Path: /devices/${deviceId}/assignment/supabaseSync/baselineHR`
    );
    return { found: true, baseline, location: "device_assignment" };
  }

  // Check location 2: User profile
  const userBaselineRef = db.ref(`/users/${userId}/baseline/heartRate`);
  const userSnapshot = await userBaselineRef.once("value");

  if (userSnapshot.exists()) {
    const baseline = userSnapshot.val();
    console.log(`✅ FOUND in user profile: ${baseline} BPM`);
    console.log(`   Path: /users/${userId}/baseline/heartRate`);
    return { found: true, baseline, location: "user_profile" };
  }

  // No baseline found
  console.log(`❌ NO BASELINE FOUND`);
  console.log(`   Anxiety detection is DISABLED for this user`);
  console.log(`   User must complete baseline setup to enable detection`);
  return { found: false, baseline: null, location: null };
}

/**
 * Test anxiety detection behavior for users with/without baseline
 */
async function testAnxietyDetectionBehavior() {
  console.log("═══════════════════════════════════════════════════════");
  console.log("  ANXIETY DETECTION BASELINE REQUIREMENT TEST");
  console.log("═══════════════════════════════════════════════════════\n");

  // Example test cases - replace with your actual user/device IDs
  const testCases = [
    {
      name: "New User (No Baseline)",
      userId: "test-user-new",
      deviceId: "AnxieEase001",
    },
    {
      name: "Existing User (With Baseline)",
      userId: "test-user-existing",
      deviceId: "AnxieEase002",
    },
  ];

  for (const testCase of testCases) {
    console.log(`\n📋 Test Case: ${testCase.name}`);
    console.log("─────────────────────────────────────────────────────");

    const result = await checkUserBaseline(testCase.userId, testCase.deviceId);

    if (result.found) {
      console.log(`\n🟢 DETECTION STATUS: ENABLED`);
      console.log(`   Baseline: ${result.baseline} BPM`);
      console.log(`   Thresholds will be calculated as:`);
      console.log(`   - Elevated: ${result.baseline + 10} BPM`);
      console.log(`   - Mild:     ${result.baseline + 15} BPM`);
      console.log(`   - Moderate: ${result.baseline + 25} BPM`);
      console.log(`   - Severe:   ${result.baseline + 35} BPM`);
      console.log(`   - Critical: ${result.baseline + 45} BPM`);
    } else {
      console.log(`\n🔴 DETECTION STATUS: DISABLED`);
      console.log(`   User will NOT receive anxiety notifications`);
      console.log(`   Action required: Complete baseline setup`);
    }
  }

  console.log("\n═══════════════════════════════════════════════════════");
  console.log("  TEST COMPLETE");
  console.log("═══════════════════════════════════════════════════════\n");
}

/**
 * Simulate heart rate update and check if detection would trigger
 */
async function simulateHeartRateUpdate(userId, deviceId, heartRate) {
  console.log(`\n🧪 SIMULATING: Heart rate update to ${heartRate} BPM`);
  console.log(`   User: ${userId}`);
  console.log(`   Device: ${deviceId}\n`);

  const baselineCheck = await checkUserBaseline(userId, deviceId);

  if (!baselineCheck.found) {
    console.log(`\n⚠️  RESULT: No anxiety detection triggered`);
    console.log(`   Reason: No baseline found`);
    console.log(
      `   Expected log: "anxiety detection disabled until baseline is set up"`
    );
    return;
  }

  const baseline = baselineCheck.baseline;
  const difference = heartRate - baseline;
  const percentageAbove = ((difference / baseline) * 100).toFixed(1);

  console.log(`\n📊 ANALYSIS:`);
  console.log(`   Current HR:  ${heartRate} BPM`);
  console.log(`   Baseline HR: ${baseline} BPM`);
  console.log(`   Difference:  +${difference} BPM (${percentageAbove}%)`);

  let severity = "normal";
  if (heartRate >= baseline + 45) severity = "critical";
  else if (heartRate >= baseline + 35) severity = "severe";
  else if (heartRate >= baseline + 25) severity = "moderate";
  else if (heartRate >= baseline + 15) severity = "mild";
  else if (heartRate >= baseline + 10) severity = "elevated";

  console.log(`   Severity:    ${severity.toUpperCase()}`);

  if (severity !== "normal") {
    console.log(`\n✅ RESULT: Anxiety detection WOULD trigger`);
    console.log(`   Notification: ${severity} anxiety alert`);
  } else {
    console.log(`\n✅ RESULT: No detection (heart rate within normal range)`);
  }
}

// Export functions for use in Firebase Functions or scripts
module.exports = {
  checkUserBaseline,
  testAnxietyDetectionBehavior,
  simulateHeartRateUpdate,
};

// Example usage:
// Run these examples to test the baseline requirement

// Check if anxiety detection works
// testAnxietyDetectionBehavior().catch(console.error);

// Test specific user
// checkUserBaseline('your-user-id', 'your-device-id').catch(console.error);

// Simulate heart rate update
// simulateHeartRateUpdate('your-user-id', 'your-device-id', 95).catch(console.error);
