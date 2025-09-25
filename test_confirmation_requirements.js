// TEST UPDATED CONFIRMATION REQUIREMENTS
// Testing that mild and moderate levels ALWAYS ask for confirmation

console.log("🔔 TESTING UPDATED CONFIRMATION REQUIREMENTS");
console.log("===========================================\n");

console.log(
  "📋 NEW REQUIREMENT: Mild and Moderate Anxiety Levels ALWAYS Request Confirmation"
);
console.log(
  "================================================================================\n"
);

const yourBaseline = 73.9; // Your baseline heart rate

console.log("🎯 UPDATED CONFIRMATION RULES:");
console.log("==============================");
console.log(`Baseline: ${yourBaseline} BPM`);
console.log(
  `Mild Level: ${yourBaseline + 15} - ${
    yourBaseline + 24
  } BPM (88.9-97.9) → ✅ ALWAYS asks confirmation`
);
console.log(
  `Moderate Level: ${yourBaseline + 25} - ${
    yourBaseline + 34
  } BPM (98.9-107.9) → ✅ ALWAYS asks confirmation`
);
console.log(
  `Severe Level: ${
    yourBaseline + 35
  }+ BPM (108.9+) → ❌ NO confirmation (immediate alert)`
);
console.log(`Critical SpO2/Medical: → ❌ NO confirmation (emergency)\n`);

console.log("📱 TEST SCENARIOS:");
console.log("==================\n");

function testConfirmationScenario(
  heartRate,
  movement,
  gyro,
  spo2,
  description
) {
  const hrElevation = heartRate - yourBaseline;
  const isMild = hrElevation >= 15 && hrElevation < 25;
  const isModerate = hrElevation >= 25 && hrElevation < 35;
  const isSevere = hrElevation >= 35;
  const isCriticalSpO2 = spo2 < 90;

  const exerciseDetected =
    movement > 30 &&
    hrElevation / yourBaseline > 0.2 &&
    hrElevation / yourBaseline < 0.8 &&
    gyro < 50;
  const tremorDetected = gyro > 40 && movement > 5 && movement < 30;
  const restingAnxiety = heartRate > yourBaseline * 1.2 && movement < 15;

  let wouldTrigger = false;
  let requiresConfirmation = false;
  let confidence = 0;
  let reason = "";

  if (exerciseDetected && !isCriticalSpO2) {
    wouldTrigger = false;
    reason = "Exercise detected - no alert";
  } else if (isCriticalSpO2) {
    wouldTrigger = true;
    requiresConfirmation = false; // Medical emergency
    confidence = 100;
    reason = "Critical SpO2 - immediate alert";
  } else if (tremorDetected) {
    wouldTrigger = true;
    requiresConfirmation = isMild || isModerate; // NEW: Mild/Moderate always confirm
    confidence = 80;
    reason = "Tremor detected";
  } else if (restingAnxiety) {
    wouldTrigger = true;
    requiresConfirmation = isMild || isModerate; // NEW: Mild/Moderate always confirm
    confidence = 85;
    reason = "Resting anxiety";
  } else if (hrElevation >= 15) {
    // Above mild threshold
    wouldTrigger = true;
    requiresConfirmation = isMild || isModerate; // NEW: Mild/Moderate always confirm
    confidence = isSevere ? 90 : 70;
    reason = "Elevated heart rate";
  }

  console.log(`${description}:`);
  console.log(
    `   HR: ${heartRate} BPM (+${hrElevation.toFixed(1)} above baseline)`
  );
  console.log(
    `   Movement: ${movement}/100, Gyro: ${gyro}/100, SpO2: ${spo2}%`
  );
  console.log(
    `   Level: ${
      isSevere ? "SEVERE" : isModerate ? "MODERATE" : isMild ? "MILD" : "NORMAL"
    }`
  );
  console.log(`   Triggers: ${wouldTrigger ? "🚨 YES" : "✅ NO"}`);

  if (wouldTrigger) {
    console.log(
      `   Confirmation: ${
        requiresConfirmation
          ? '❓ ASKS "Are you feeling anxious?"'
          : "🚨 IMMEDIATE ALERT"
      }`
    );
    console.log(`   Confidence: ${confidence}%`);
    console.log(`   Reason: ${reason}`);
  }
  console.log("");
}

// Test scenarios
console.log("1️⃣ MILD ANXIETY (Should Ask Confirmation):");
testConfirmationScenario(89.5, 5, 10, 98, "Mild anxiety while sitting");

console.log("2️⃣ MODERATE ANXIETY (Should Ask Confirmation):");
testConfirmationScenario(99.5, 8, 15, 97, "Moderate anxiety while resting");

console.log("3️⃣ SEVERE ANXIETY (Immediate Alert):");
testConfirmationScenario(110, 12, 20, 95, "Severe anxiety episode");

console.log("4️⃣ MILD WITH TREMORS (Should Ask Confirmation):");
testConfirmationScenario(91, 20, 45, 98, "Mild anxiety with tremors");

console.log("5️⃣ MODERATE WITH TREMORS (Should Ask Confirmation):");
testConfirmationScenario(100, 25, 50, 96, "Moderate anxiety with tremors");

console.log("6️⃣ EXERCISE (No Alert):");
testConfirmationScenario(95, 60, 30, 97, "Exercise/walking");

console.log("7️⃣ CRITICAL SpO2 (Immediate Alert):");
testConfirmationScenario(92, 10, 15, 88, "Low oxygen - medical emergency");

console.log("8️⃣ YOUR CURRENT STATUS:");
testConfirmationScenario(86.8, 0.8, 1.7, 98, "Your current real-time data");

console.log("🎯 SUMMARY OF CHANGES:");
console.log("======================");
console.log(
  '✅ Mild anxiety (88.9-97.9 BPM): NOW asks "Are you feeling anxious?"'
);
console.log(
  '✅ Moderate anxiety (98.9-107.9 BPM): NOW asks "Are you feeling anxious?"'
);
console.log(
  "❌ Severe anxiety (108.9+ BPM): Still immediate alert (no confirmation)"
);
console.log(
  "❌ Critical medical (SpO2 <90%): Still immediate alert (emergency)"
);
console.log("✅ Exercise detection: Still prevents false alarms");

console.log("\n💡 USER EXPERIENCE:");
console.log("===================");
console.log("📱 Mild/Moderate Alert Message:");
console.log('   "Your heart rate is elevated (XX BPM)."');
console.log('   "Are you feeling anxious or stressed?"');
console.log("   [YES] [NO] [NOT NOW]");

console.log("\n🚨 Severe Alert Message:");
console.log('   "Anxiety detected: High heart rate (XX BPM)"');
console.log('   "Consider breathing exercises or contact support"');
console.log("   [OK] [HELP] [CALL SUPPORT]");

console.log("\n🎊 This ensures users aren't overwhelmed with false alerts");
console.log("   while still catching real anxiety episodes accurately!");
