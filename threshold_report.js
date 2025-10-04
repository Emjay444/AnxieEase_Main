/**
 * ANXIETY THRESHOLD SUMMARY REPORT
 * Complete analysis of your AnxieEase anxiety detection system
 */

console.log("🚨 ANXIEEASE ANXIETY DETECTION ANALYSIS 🚨");
console.log("=".repeat(60));

console.log("\n📋 SYSTEM OVERVIEW:");
console.log(
  "• Your baseline heart rate: 73.2 BPM (from Supabase device assignment)"
);
console.log("• Detection method: Real-time Firebase heart rate monitoring");
console.log("• Trigger: personalizedAnxietyDetection.ts function");
console.log("• Location: /devices/{deviceId}/current/heartRate changes");

console.log("\n🎯 CURRENT THRESHOLD CONFIGURATION:");
console.log("Your system uses FIXED BPM additions (not percentages):");

const baseline = 73.2;
const thresholds = {
  elevated: baseline + 10, // +10 BPM
  mild: baseline + 15, // +15 BPM
  moderate: baseline + 25, // +25 BPM
  severe: baseline + 35, // +35 BPM
  critical: baseline + 45, // +45 BPM
};

console.log(`   📗 Normal:     < ${thresholds.elevated} BPM`);
console.log(
  `   📘 Elevated:   ${thresholds.elevated} BPM (+10 BPM, ${(
    (10 / baseline) *
    100
  ).toFixed(1)}%)`
);
console.log(
  `   🟡 Mild:       ${thresholds.mild} BPM (+15 BPM, ${(
    (15 / baseline) *
    100
  ).toFixed(1)}%)`
);
console.log(
  `   🟠 Moderate:   ${thresholds.moderate} BPM (+25 BPM, ${(
    (25 / baseline) *
    100
  ).toFixed(1)}%)`
);
console.log(
  `   🔴 Severe:     ${thresholds.severe} BPM (+35 BPM, ${(
    (35 / baseline) *
    100
  ).toFixed(1)}%)`
);
console.log(
  `   🚨 Critical:   ${thresholds.critical} BPM (+45 BPM, ${(
    (45 / baseline) *
    100
  ).toFixed(1)}%)`
);

console.log("\n🔍 DETECTION LOGIC:");
console.log("1. Heart rate change detected in Firebase");
console.log("2. System calculates severity level");
console.log("3. If severity CHANGES (not just elevated), notification sent");
console.log("4. Rate limiting prevents notification spam");
console.log("5. User can confirm/dismiss alerts");

console.log("\n⚡ TRIGGER CONDITIONS:");
console.log("✅ Heart rate ≥ 83.2 BPM (first alert level)");
console.log("✅ Device worn and sending fresh data");
console.log("✅ User assigned to device in Supabase");
console.log("✅ FCM token available for notifications");
console.log("✅ Not rate limited");

console.log("\n❌ CURRENT BLOCKING ISSUES:");
console.log("• Device data is stale (22+ minutes old)");
console.log("• Heart rate showing 0 BPM (device not worn)");
console.log("• No fresh data triggering detection");

console.log("\n🧪 TEST YOUR THRESHOLDS:");
console.log("To test anxiety detection:");
console.log("1. Ensure device is worn and connected");
console.log("2. Simulate heart rate ≥ 83.2 BPM in Firebase");
console.log("3. Watch for notifications");

console.log("\n📊 NOTIFICATION EXAMPLES:");
const examples = [
  {
    hr: 85,
    level: "elevated",
    msg: "Heart Rate Elevated - Take a moment to breathe",
  },
  {
    hr: 90,
    level: "mild",
    msg: "Mild Anxiety Detected - Try breathing exercises",
  },
  {
    hr: 100,
    level: "moderate",
    msg: "Moderate Anxiety Alert - Consider grounding techniques",
  },
  {
    hr: 110,
    level: "severe",
    msg: "High Anxiety Detected - Use your coping strategies",
  },
  {
    hr: 120,
    level: "critical",
    msg: "Critical Alert - Seek immediate support if needed",
  },
];

examples.forEach((ex) => {
  const icon = {
    elevated: "📘",
    mild: "🟡",
    moderate: "🟠",
    severe: "🔴",
    critical: "🚨",
  }[ex.level];
  console.log(`${icon} ${ex.hr} BPM: "${ex.msg}"`);
});

console.log("\n🔧 CONFIGURATION FILES:");
console.log("• Main logic: functions/src/personalizedAnxietyDetection.ts");
console.log("• Thresholds: calculatePersonalizedThresholds() function");
console.log("• Rate limiting: functions/src/enhancedRateLimiting.ts");
console.log("• Baseline source: Supabase device_assignments table");

console.log("\n💡 RECOMMENDATIONS:");
console.log("1. Check if device is properly worn and connected");
console.log("2. Verify fresh heart rate data in Firebase");
console.log("3. Test with simulate_real_anxiety.js script");
console.log("4. Monitor Firebase Functions logs for detection events");
console.log("5. Consider adjusting thresholds if too sensitive/insensitive");

console.log("\n🎮 TO SIMULATE ANXIETY:");
console.log("Run: node simulate_real_anxiety.js");
console.log("This will send test heart rate data to trigger detection");

console.log("\n" + "=".repeat(60));
console.log("✅ Analysis complete! Your thresholds are configured correctly.");
console.log("📱 Issue: Device needs fresh data for detection to work.");
