// Debug helper to understand severity calculation
const baseline = 73.2;

function getSeverityLevel(heartRate, baseline) {
  const percentageAbove = ((heartRate - baseline) / baseline) * 100;

  console.log(`Heart Rate: ${heartRate} BPM`);
  console.log(`Baseline: ${baseline} BPM`);
  console.log(`Percentage Above: ${percentageAbove.toFixed(1)}%`);

  if (percentageAbove >= 80) {
    console.log(`→ CRITICAL (≥80% above baseline)`);
    return "critical";
  }
  if (percentageAbove >= 50) {
    console.log(`→ SEVERE (50-79% above baseline)`);
    return "severe";
  }
  if (percentageAbove >= 30) {
    console.log(`→ MODERATE (30-49% above baseline)`);
    return "moderate";
  }
  if (percentageAbove >= 20) {
    console.log(`→ MILD (20-29% above baseline)`);
    return "mild";
  }
  console.log(`→ NORMAL (<20% above baseline)`);
  return "normal";
}

console.log("🔍 SEVERITY LEVEL DEBUG");
console.log("═══════════════════════");
console.log(`Baseline: ${baseline} BPM\n`);

// Test the heart rates from your test scripts
console.log("📊 Test Script Heart Rate Analysis:");
console.log("─".repeat(40));

console.log("\n🟡 MILD TEST (84-91 BPM):");
getSeverityLevel(84, baseline);
console.log("");
getSeverityLevel(91, baseline);

console.log("\n🟠 MODERATE TEST (95-105 BPM):");
getSeverityLevel(95, baseline);
console.log("");
getSeverityLevel(105, baseline);

console.log("\n🔴 SEVERE TEST (should be 110+ BPM):");
getSeverityLevel(110, baseline);
console.log("");
getSeverityLevel(120, baseline);

console.log("\n🚨 CRITICAL TEST (should be 131+ BPM):");
getSeverityLevel(131, baseline);
console.log("");
getSeverityLevel(140, baseline);

console.log("\n🎯 THRESHOLD SUMMARY:");
console.log("─".repeat(40));
console.log(
  `Mild: ${(baseline * 1.2).toFixed(1)} - ${(baseline * 1.29).toFixed(1)} BPM`
);
console.log(
  `Moderate: ${(baseline * 1.3).toFixed(1)} - ${(baseline * 1.49).toFixed(
    1
  )} BPM`
);
console.log(
  `Severe: ${(baseline * 1.5).toFixed(1)} - ${(baseline * 1.79).toFixed(1)} BPM`
);
console.log(`Critical: ${(baseline * 1.8).toFixed(1)}+ BPM`);

console.log("\n🤔 POSSIBLE ISSUES:");
console.log("─".repeat(40));
console.log("1. Test scripts might not generate heart rates high enough");
console.log("2. Rate limiting might be blocking subsequent notifications");
console.log("3. Notification channels might have different permissions");
console.log(
  "4. Firebase function might not be triggered for higher severities"
);
