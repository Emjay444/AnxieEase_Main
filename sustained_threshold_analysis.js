/**
 * SUSTAINED ANXIETY DETECTION ANALYSIS (30-SECOND RULE)
 * Your correct anxiety detection system
 */

// Your current baseline from the logs
const YOUR_BASELINE = 73.2; // BPM from device assignment

/**
 * Calculate sustained anxiety threshold (20% above baseline)
 */
function calculateSustainedThreshold(baselineHR) {
  return baselineHR * 1.2; // 20% above baseline for sustained detection
}

/**
 * Calculate severity based on percentage above baseline for sustained detection
 */
function getSustainedSeverityLevel(heartRate, baseline) {
  const percentageAbove = ((heartRate - baseline) / baseline) * 100;

  // Critical: 80%+ above baseline (emergency level)
  if (percentageAbove >= 80) return "critical";
  // Severe: 50-79% above baseline
  if (percentageAbove >= 50) return "severe";
  // Moderate: 30-49% above baseline
  if (percentageAbove >= 30) return "moderate";
  // Mild: 20-29% above baseline
  return "mild";
}

console.log("🚨 SUSTAINED ANXIETY DETECTION ANALYSIS (30-SECOND RULE)");
console.log("=".repeat(65));

console.log("\n📋 SUSTAINED DETECTION SYSTEM:");
console.log("• Detection Function: realTimeSustainedAnxietyDetection");
console.log("• Trigger: /devices/{deviceId}/current data updates");
console.log("• Duration Required: 30+ seconds continuous elevation");
console.log("• Your Baseline: 73.2 BPM");

// Calculate your sustained threshold
const sustainedThreshold = calculateSustainedThreshold(YOUR_BASELINE);

console.log("\n🎯 YOUR SUSTAINED THRESHOLDS:");
console.log(
  `📊 Anxiety Trigger: ${sustainedThreshold.toFixed(
    1
  )} BPM (20% above baseline)`
);
console.log(`   - Must stay at/above this level for 30+ seconds`);
console.log(
  `   - Calculates: ${YOUR_BASELINE} × 1.2 = ${sustainedThreshold.toFixed(
    1
  )} BPM`
);

console.log("\n📈 SEVERITY LEVELS (based on % above baseline):");
const testHRs = [88, 95, 105, 115, 125, 135];
testHRs.forEach((hr) => {
  const percentage = (((hr - YOUR_BASELINE) / YOUR_BASELINE) * 100).toFixed(1);
  const severity = getSustainedSeverityLevel(hr, YOUR_BASELINE);
  const icon = { mild: "🟡", moderate: "🟠", severe: "🔴", critical: "🚨" }[
    severity
  ];
  console.log(
    `${icon} ${hr} BPM → ${severity.toUpperCase()} (${percentage}% above baseline)`
  );
});

console.log("\n⏱️ DETECTION PROCESS:");
console.log("1. Heart rate must reach 87.8+ BPM");
console.log("2. Must stay elevated for 30+ continuous seconds");
console.log("3. System analyzes user session history (not device history)");
console.log("4. Calculates average HR during sustained period");
console.log("5. Determines severity based on percentage above baseline");
console.log("6. Sends notification if not rate-limited");

console.log("\n✅ TRIGGER CONDITIONS:");
console.log(
  `• Heart rate ≥ ${sustainedThreshold.toFixed(1)} BPM for 30+ seconds`
);
console.log("• Device worn (worn=1, not worn=0)");
console.log("• User assigned to device in Supabase");
console.log("• Fresh data points in user session");
console.log("• Not rate-limited (2-minute window)");

console.log("\n❌ CURRENT BLOCKING ISSUES:");
console.log("• Device data is 22+ minutes old (stale)");
console.log("• Heart rate showing 0 BPM (device not worn)");
console.log("• No active user session data");

console.log("\n🧪 TEST SCENARIOS:");
console.log("To trigger sustained anxiety detection:");

const scenarios = [
  {
    hr: 90,
    duration: 35,
    severity: "mild",
    description: "Basic anxiety detection",
  },
  {
    hr: 100,
    duration: 45,
    severity: "moderate",
    description: "Moderate anxiety alert",
  },
  {
    hr: 115,
    duration: 60,
    severity: "severe",
    description: "Severe anxiety warning",
  },
  {
    hr: 130,
    duration: 30,
    severity: "critical",
    description: "Emergency level alert",
  },
];

scenarios.forEach((scenario) => {
  const percentage = (
    ((scenario.hr - YOUR_BASELINE) / YOUR_BASELINE) *
    100
  ).toFixed(1);
  const icon = { mild: "🟡", moderate: "🟠", severe: "🔴", critical: "🚨" }[
    scenario.severity
  ];
  console.log(
    `${icon} ${scenario.hr} BPM for ${scenario.duration}s → ${scenario.description} (${percentage}% above)`
  );
});

console.log("\n🎮 TO TEST SUSTAINED DETECTION:");
console.log("Use the test script with sustained duration:");
console.log("```");
console.log("node test_real_notifications.js");
console.log('// Select "Simulate sustained anxiety (35s)"');
console.log("// Choose severity level (mild/moderate/severe)");
console.log("```");

console.log("\n🔧 KEY DIFFERENCES FROM IMMEDIATE DETECTION:");
console.log("• Immediate: Triggers on any HR change (personalized detection)");
console.log("• Sustained: Requires 30+ seconds continuous elevation");
console.log("• Sustained: Uses 20% threshold (not fixed +15 BPM)");
console.log("• Sustained: Analyzes user session history");
console.log("• Sustained: More robust against false positives");

console.log("\n📊 SUMMARY:");
console.log(
  `Your sustained anxiety detection triggers at ${sustainedThreshold.toFixed(
    1
  )} BPM`
);
console.log("held continuously for 30+ seconds.");
console.log("This is much more reliable than immediate detection.");

console.log("\n" + "=".repeat(65));
console.log("✅ This is your MAIN anxiety detection system!");
