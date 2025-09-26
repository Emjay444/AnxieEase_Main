// ANXIEEASE THRESHOLD ANALYSIS
// Based on your Firebase Cloud Functions code
// User baseline: 73.2 BPM (from assignment data)

console.log("🎯 ANXIEEASE ANXIETY DETECTION THRESHOLDS");
console.log("═".repeat(60));

const baselineHR = 73.2; // Your current user's baseline
const testHR = 120; // Minimum test heart rate

console.log(`👤 Current User Baseline: ${baselineHR} BPM`);
console.log(`🧪 Test Simulation Range: ${testHR}-140 BPM`);
console.log("");

// Calculate thresholds based on your code
console.log("📊 THRESHOLD BREAKDOWN:");
console.log("─".repeat(40));

// Basic detection threshold (20% above baseline)
const basicThreshold = baselineHR * 1.2; // 0.2 = 20%
console.log(
  `🟡 Basic Detection: ${basicThreshold.toFixed(1)} BPM (20% above baseline)`
);
console.log(
  `   Status: ${
    testHR >= basicThreshold ? "✅ WILL TRIGGER" : "❌ Will not trigger"
  }`
);

// Very high threshold (30% above baseline)
const veryHighThreshold = baselineHR * 1.3; // 0.3 = 30%
console.log(
  `🟠 Very High Detection: ${veryHighThreshold.toFixed(
    1
  )} BPM (30% above baseline)`
);
console.log(
  `   Status: ${
    testHR >= veryHighThreshold ? "✅ WILL TRIGGER" : "❌ Will not trigger"
  }`
);

console.log("");
console.log("🏷️  SEVERITY LEVELS (Absolute BPM increases):");
console.log("─".repeat(40));

// Severity levels (absolute BPM increases)
const mildStart = baselineHR + 15;
const mildEnd = baselineHR + 24;
const moderateStart = baselineHR + 25;
const moderateEnd = baselineHR + 34;
const severeStart = baselineHR + 35;

console.log(
  `🟢 MILD:     ${mildStart.toFixed(1)} - ${mildEnd.toFixed(
    1
  )} BPM (+15 to +24 BPM)`
);
console.log(
  `   Test Range: ${
    testHR >= mildStart && testHR <= mildEnd
      ? "✅ IN RANGE"
      : testHR < mildStart
      ? "❌ Below range"
      : "⚠️  Above range"
  }`
);

console.log(
  `🟡 MODERATE: ${moderateStart.toFixed(1)} - ${moderateEnd.toFixed(
    1
  )} BPM (+25 to +34 BPM)`
);
console.log(
  `   Test Range: ${
    testHR >= moderateStart && testHR <= moderateEnd
      ? "✅ IN RANGE"
      : testHR < moderateStart
      ? "❌ Below range"
      : "⚠️  Above range"
  }`
);

console.log(`🔴 SEVERE:   ${severeStart.toFixed(1)}+ BPM (+35+ BPM)`);
console.log(
  `   Test Range: ${
    testHR >= severeStart
      ? "✅ WILL TRIGGER SEVERE"
      : "❌ Will not reach severe"
  }`
);

console.log("");
console.log("🔥 CRITICAL CONDITIONS:");
console.log("─".repeat(40));
console.log("💨 SpO2 < 90%: Critical alert (bypasses HR thresholds)");
console.log("🤚 Tremor Detection: High confidence anxiety alert");
console.log("📳 Multiple Metrics: 2+ abnormal = high confidence");
console.log("🏃 Exercise Detection: Suppresses false alarms");

console.log("");
console.log("📱 NOTIFICATION BEHAVIOR:");
console.log("─".repeat(40));

// Test what will happen with 120+ BPM
const testElevation = testHR - baselineHR;
const testPercentage = (testElevation / baselineHR) * 100;

console.log(`📊 Your test (${testHR} BPM):`);
console.log(`   Elevation: +${testElevation.toFixed(1)} BPM`);
console.log(`   Percentage: +${testPercentage.toFixed(1)}% above baseline`);
console.log("");

if (testElevation >= 35) {
  console.log("🚨 EXPECTED RESULT: SEVERE/CRITICAL ANXIETY ALERT");
  console.log("   ✅ Will trigger immediately (no confirmation needed)");
  console.log("   🔴 Red notification with high priority");
  console.log("   📱 Emergency-level alert");
} else if (testElevation >= 25) {
  console.log("🟠 EXPECTED RESULT: MODERATE ANXIETY ALERT");
  console.log("   ❓ Will require user confirmation");
  console.log("   🟠 Orange notification");
} else if (testElevation >= 15) {
  console.log("🟡 EXPECTED RESULT: MILD ANXIETY ALERT");
  console.log("   ❓ Will require user confirmation");
  console.log("   🟡 Yellow notification");
} else {
  console.log("❌ EXPECTED RESULT: No alert triggered");
}

console.log("");
console.log("⚡ ADDITIONAL FACTORS THAT BOOST CONFIDENCE:");
console.log("─".repeat(40));
console.log("• Low movement + high HR = Resting anxiety (85% confidence)");
console.log("• Multiple abnormal metrics = Higher confidence");
console.log("• Tremor patterns detected = 80% confidence");
console.log("• Exercise detected = Suppresses alerts");

console.log("");
console.log("🎯 CONCLUSION:");
console.log("═".repeat(60));
console.log(
  `Your 120+ BPM test (+${testElevation.toFixed(
    1
  )} BPM) WILL DEFINITELY TRIGGER:`
);
console.log("✅ Basic anxiety detection (20% threshold)");
console.log("✅ Very high anxiety detection (30% threshold)");
console.log("✅ SEVERE level anxiety alert (+35 BPM = immediate notification)");
console.log("🔔 Expected: Red emergency notification sent to your app");
console.log("📊 Confidence Level: 85%+ (no confirmation required)");
