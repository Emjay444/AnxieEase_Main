/**
 * Anxiety Threshold Analyzer
 * Shows exactly how your anxiety detection thresholds work
 */

// Your current baseline from the logs
const YOUR_BASELINE = 73.2; // BPM from device assignment

/**
 * Calculate current thresholds exactly as your system does
 */
function calculatePersonalizedThresholds(baselineHR) {
  return {
    baseline: baselineHR,
    elevated: baselineHR + 10, // +10 BPM (early warning)
    mild: baselineHR + 15, // +15 BPM above baseline
    moderate: baselineHR + 25, // +25 BPM above baseline
    severe: baselineHR + 35, // +35 BPM above baseline
    critical: baselineHR + 45, // +45 BPM (emergency)
  };
}

/**
 * Determine severity level
 */
function getSeverityLevel(heartRate, thresholds) {
  if (heartRate >= thresholds.critical) return "critical";
  if (heartRate >= thresholds.severe) return "severe";
  if (heartRate >= thresholds.moderate) return "moderate";
  if (heartRate >= thresholds.mild) return "mild";
  if (heartRate >= thresholds.elevated) return "elevated";
  return "normal";
}

/**
 * Calculate percentage above baseline
 */
function calculatePercentage(heartRate, baseline) {
  return (((heartRate - baseline) / baseline) * 100).toFixed(1);
}

console.log("🔍 YOUR ANXIETY THRESHOLD ANALYSIS");
console.log("=".repeat(50));

// Calculate your personalized thresholds
const thresholds = calculatePersonalizedThresholds(YOUR_BASELINE);

console.log(`\n📊 Your Baseline: ${YOUR_BASELINE} BPM`);
console.log("🎯 Your Personalized Thresholds:");
console.log(`   📗 Normal:     < ${thresholds.elevated} BPM`);
console.log(
  `   📘 Elevated:   ${thresholds.elevated} - ${
    thresholds.mild - 1
  } BPM (${calculatePercentage(
    thresholds.elevated,
    YOUR_BASELINE
  )}% above baseline)`
);
console.log(
  `   🟡 Mild:       ${thresholds.mild} - ${
    thresholds.moderate - 1
  } BPM (${calculatePercentage(
    thresholds.mild,
    YOUR_BASELINE
  )}% above baseline)`
);
console.log(
  `   🟠 Moderate:   ${thresholds.moderate} - ${
    thresholds.severe - 1
  } BPM (${calculatePercentage(
    thresholds.moderate,
    YOUR_BASELINE
  )}% above baseline)`
);
console.log(
  `   🔴 Severe:     ${thresholds.severe} - ${
    thresholds.critical - 1
  } BPM (${calculatePercentage(
    thresholds.severe,
    YOUR_BASELINE
  )}% above baseline)`
);
console.log(
  `   🚨 Critical:   ${thresholds.critical}+ BPM (${calculatePercentage(
    thresholds.critical,
    YOUR_BASELINE
  )}% above baseline)`
);

console.log("\n🧪 TEST SCENARIOS:");
console.log("-".repeat(30));

// Test various heart rates
const testHeartRates = [70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125];

testHeartRates.forEach((hr) => {
  const severity = getSeverityLevel(hr, thresholds);
  const percentage = calculatePercentage(hr, YOUR_BASELINE);
  const icon = {
    normal: "📗",
    elevated: "📘",
    mild: "🟡",
    moderate: "🟠",
    severe: "🔴",
    critical: "🚨",
  }[severity];

  console.log(
    `${icon} ${hr} BPM → ${severity.toUpperCase()} (${percentage}% above baseline)`
  );
});

console.log("\n⚠️ IMPORTANT NOTES:");
console.log("• Notifications only trigger when severity CHANGES");
console.log("• System uses rate limiting to prevent spam");
console.log("• Your baseline of 73.2 BPM is quite good!");

console.log("\n🔬 THRESHOLD BREAKDOWN:");
console.log(
  `• First alert at: ${thresholds.elevated} BPM (+${
    thresholds.elevated - YOUR_BASELINE
  } BPM)`
);
console.log(
  `• Anxiety detected at: ${thresholds.mild} BPM (+${
    thresholds.mild - YOUR_BASELINE
  } BPM)`
);
console.log(
  `• Emergency level at: ${thresholds.critical} BPM (+${
    thresholds.critical - YOUR_BASELINE
  } BPM)`
);

// Show what would trigger right now based on Firebase data
console.log("\n📱 CURRENT STATUS:");
console.log("Based on your Firebase data (62% battery, old data):");
console.log("• Device is considered offline due to stale data");
console.log("• No anxiety detection active until fresh data arrives");
console.log("• Battery level: 62% (good level)");

console.log("\n🎯 TO TRIGGER ANXIETY ALERT:");
console.log(
  `• Your heart rate needs to reach ${thresholds.elevated} BPM or higher`
);
console.log(`• Device must be worn and sending fresh data`);
console.log(`• Current heart rate in Firebase: 0 BPM (device not worn)`);
