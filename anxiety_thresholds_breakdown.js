// ANXIETY DETECTION THRESHOLDS & TRIGGERING CONDITIONS
// Complete breakdown of when alerts trigger based on your enhanced system

console.log("🎯 ANXIETY DETECTION THRESHOLDS & TRIGGERING CONDITIONS");
console.log("========================================================\n");

// Your personal baseline and calculated thresholds
const yourBaseline = 73.9; // BPM (from baseline_heart_rates table)

console.log("👤 YOUR PERSONAL THRESHOLDS:");
console.log("============================");
console.log(`Baseline Heart Rate: ${yourBaseline} BPM`);
console.log(
  `Elevated (+10 BPM): ${(yourBaseline + 10).toFixed(1)} BPM (83.9+)`
);
console.log(
  `Mild Anxiety (+15 BPM): ${(yourBaseline + 15).toFixed(1)} BPM (88.9+)`
);
console.log(
  `Moderate (+25 BPM): ${(yourBaseline + 25).toFixed(1)} BPM (98.9+)`
);
console.log(`Severe (+35 BPM): ${(yourBaseline + 35).toFixed(1)} BPM (108.9+)`);
console.log(
  `Critical (+45 BPM): ${(yourBaseline + 45).toFixed(1)} BPM (118.9+)`
);

console.log("\n🚨 TRIGGERING CONDITIONS & CONFIDENCE LEVELS:");
console.log("==============================================\n");

console.log("1️⃣ CRITICAL SpO2 (IMMEDIATE ALERT):");
console.log("-----------------------------------");
console.log("Condition: SpO2 < 90%");
console.log("Confidence: 100% (1.0)");
console.log("User Confirmation: Not required");
console.log("Trigger: YES - Always triggers (medical emergency)");
console.log("Example: SpO2 = 88% → Immediate critical alert\n");

console.log("2️⃣ RESTING ANXIETY (HIGH CONFIDENCE):");
console.log("-------------------------------------");
console.log(
  `Condition: HR ≥ ${(yourBaseline * 1.2).toFixed(
    1
  )} BPM (20% above baseline) + Movement < 15/100`
);
console.log("Confidence: 85% (0.85)");
console.log("User Confirmation: Not required");
console.log("Trigger: YES - High confidence anxiety while sitting");
console.log(`Example: HR = 89+ BPM while sitting still → Anxiety alert\n`);

console.log("3️⃣ TREMOR DETECTION (HIGH CONFIDENCE):");
console.log("--------------------------------------");
console.log("Condition: Gyroscope Activity > 40/100 + Movement 5-30/100");
console.log("Confidence: 80% (0.8)");
console.log("User Confirmation: Not required");
console.log("Trigger: YES - Tremor patterns indicate anxiety");
console.log("Example: Rapid hand shaking while anxious → Tremor alert\n");

console.log("4️⃣ MULTIPLE ABNORMAL METRICS (HIGH CONFIDENCE):");
console.log("-----------------------------------------------");
console.log("Condition: 2+ abnormal metrics (HR + SpO2, HR + Movement, etc.)");
console.log("Confidence: 85-100% (0.85-1.0)");
console.log("User Confirmation: Not required");
console.log("Trigger: YES - Multiple indicators increase confidence");
console.log(`Example: HR = 95+ BPM + SpO2 = 93% → Multiple metrics alert\n`);

console.log("5️⃣ VERY HIGH HEART RATE (SUSTAINED):");
console.log("------------------------------------");
console.log(
  `Condition: HR ≥ ${(yourBaseline * 1.3).toFixed(
    1
  )} BPM (30% above baseline) for 30+ seconds`
);
console.log("Confidence: 75% (0.75)");
console.log("User Confirmation: Required (unless other factors)");
console.log("Trigger: YES - Very high HR needs attention");
console.log(`Example: HR = 96+ BPM sustained → High HR alert\n`);

console.log("6️⃣ MODERATE HIGH HEART RATE (CONFIRMATION):");
console.log("-------------------------------------------");
console.log(
  `Condition: HR ≥ ${(yourBaseline * 1.2).toFixed(
    1
  )} BPM (20% above baseline) for 30+ seconds`
);
console.log("Confidence: 60% (0.6)");
console.log("User Confirmation: Required");
console.log('Trigger: YES - But asks "Are you feeling anxious?"');
console.log(`Example: HR = 89-95 BPM → Confirmation alert\n`);

console.log("7️⃣ LOW SpO2 (CONFIRMATION REQUIRED):");
console.log("-----------------------------------");
console.log("Condition: SpO2 < 94% but ≥ 90%");
console.log("Confidence: 60% (0.6)");
console.log("User Confirmation: Required");
console.log("Trigger: YES - But asks for confirmation");
console.log('Example: SpO2 = 92% → "Is your breathing okay?"\n');

console.log("8️⃣ MOVEMENT SPIKES ONLY:");
console.log("------------------------");
console.log("Condition: Movement > 40/100 (sudden spikes)");
console.log("Confidence: 60% (0.6)");
console.log("User Confirmation: Required");
console.log("Trigger: YES - But asks for confirmation");
console.log('Example: Sudden restless movement → "Feeling anxious?"\n');

console.log("❌ CONDITIONS that PREVENT ALERTS:");
console.log("===================================\n");

console.log("🏃 EXERCISE DETECTED (NO ALERT):");
console.log("-------------------------------");
console.log(
  "Condition: Movement > 30/100 + HR increase 20-80% + Gyro < 50/100"
);
console.log("Result: NO ALERT - Exercise suppresses anxiety detection");
console.log('Confidence: 10% (0.1) - Very low, marked as "exerciseDetected"');
console.log("Example: Walking (HR=95, Movement=50) → No anxiety alert\n");

console.log("😴 LOW HEART RATE (RARE ALERT):");
console.log("------------------------------");
console.log("Condition: HR < 50 BPM (unusually low)");
console.log("Trigger: Only if medically concerning");
console.log("Example: HR = 45 BPM → Medical attention needed\n");

console.log("📊 CONFIDENCE BOOSTERS:");
console.log("========================");
console.log("• Anxiety movement patterns: +15% confidence");
console.log("• Very high HR (30%+ above baseline): +10% confidence");
console.log("• Multiple abnormal metrics: +10% per additional metric");
console.log("• Tremor patterns detected: +10% confidence");
console.log("• Resting state with high HR: +25% confidence\n");

console.log("🎯 YOUR CURRENT STATUS ANALYSIS:");
console.log("=================================");

// Analyze current real data
const currentHR = 86.8;
const currentMovement = 0.8; // From accelerometer calculation
const currentSpO2 = 98;
const currentGyro = 1.7;

console.log(`Current Heart Rate: ${currentHR} BPM`);
console.log(`Above baseline: +${(currentHR - yourBaseline).toFixed(1)} BPM`);
console.log(`Movement Level: ${currentMovement}/100`);
console.log(`SpO2: ${currentSpO2}%`);
console.log(`Gyro Activity: ${currentGyro}/100\n`);

// Check thresholds
const hrPercentageAbove = (currentHR - yourBaseline) / yourBaseline;
const isElevated = hrPercentageAbove >= 0.135; // ~10 BPM above
const isMildAnxiety = hrPercentageAbove >= 0.2; // 20% above (88.9+ BPM)
const isModerateAnxiety = hrPercentageAbove >= 0.3; // 30% above (96+ BPM)
const isResting = currentMovement < 15;
const exerciseDetected =
  currentMovement > 30 &&
  hrPercentageAbove > 0.2 &&
  hrPercentageAbove < 0.8 &&
  currentGyro < 50;
const tremorDetected =
  currentGyro > 40 && currentMovement > 5 && currentMovement < 30;

console.log("THRESHOLD ANALYSIS:");
console.log("-------------------");
console.log(`✅ Elevated (83.9+ BPM): ${isElevated ? "YES" : "NO"}`);
console.log(`🟡 Mild Anxiety (88.9+ BPM): ${isMildAnxiety ? "YES" : "NO"}`);
console.log(
  `🟠 Moderate Anxiety (96+ BPM): ${isModerateAnxiety ? "YES" : "NO"}`
);
console.log(`👤 Resting State: ${isResting ? "YES" : "NO"}`);
console.log(`🏃 Exercise Detected: ${exerciseDetected ? "YES" : "NO"}`);
console.log(`🤲 Tremor Detected: ${tremorDetected ? "YES" : "NO"}\n`);

console.log("FINAL RESULT:");
console.log("=============");

if (currentSpO2 < 90) {
  console.log("🚨 CRITICAL ALERT: Low oxygen - immediate attention needed");
} else if (tremorDetected) {
  console.log(
    "🚨 TREMOR ALERT: Anxiety-related shaking detected (80% confidence)"
  );
} else if (isMildAnxiety && isResting && !exerciseDetected) {
  console.log(
    "🚨 ANXIETY ALERT: High heart rate while resting (85% confidence)"
  );
} else if (isElevated && isResting) {
  console.log("⚡ ELEVATED: Close to anxiety threshold - monitoring");
} else if (exerciseDetected) {
  console.log("🏃 NO ALERT: Exercise pattern detected");
} else {
  console.log("✅ NORMAL: All metrics within healthy range");
}

console.log(`\n💡 TO TRIGGER ANXIETY ALERT, YOU NEED:`);
console.log(
  `   Heart Rate: ≥ ${(yourBaseline + 15).toFixed(
    1
  )} BPM (currently ${currentHR})`
);
console.log(`   Movement: < 15/100 (currently ${currentMovement})`);
console.log(`   OR Tremor: Gyro > 40/100 (currently ${currentGyro})`);
console.log(`   OR SpO2: < 94% (currently ${currentSpO2}%)`);
console.log(`   AND NOT Exercise Pattern`);

console.log(
  "\n🎯 SUMMARY: Your system is very close to triggering but not quite there yet."
);
console.log(
  `    Need ~${(88.9 - currentHR).toFixed(
    1
  )} more BPM while resting to trigger anxiety alert.`
);
