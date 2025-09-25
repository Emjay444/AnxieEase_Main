// MOVEMENT DATA ANALYSIS - YOU HAVE IT!
// Analyzing the accelerometer and gyroscope data from your device

console.log("🎉 MOVEMENT DATA DETECTED IN YOUR DEVICE!");
console.log("=========================================\n");

console.log("📊 ACCELEROMETER DATA (from your screenshots):");
console.log("===============================================");
console.log("Historical data (2025_09_25_08_47_34):");
console.log("   accelX: 7.2");
console.log("   accelY: 1.91");
console.log("   accelZ: 6.07");

console.log("\nCurrent data:");
console.log("   accelX: 5.34");
console.log("   accelY: 2.06");
console.log("   accelZ: 7.86");

console.log("\n📊 GYROSCOPE DATA:");
console.log("==================");
console.log("Historical data:");
console.log("   gyroX: 0.19");
console.log("   gyroY: 0.07");
console.log("   gyroZ: -0.01");

console.log("\nCurrent data:");
console.log("   gyroX: -0.01");
console.log("   gyroY: 0.01");
console.log("   gyroZ: -0.01");

console.log("\n🎯 MOVEMENT ANALYSIS:");
console.log("=====================");

// Calculate movement intensity from accelerometer data
function calculateMovementIntensity(accelX, accelY, accelZ) {
  // Calculate magnitude of acceleration vector
  const magnitude = Math.sqrt(
    accelX * accelX + accelY * accelY + accelZ * accelZ
  );

  // Subtract gravity (approximately 9.8 m/s²) to get movement component
  const movementComponent = Math.abs(magnitude - 9.8);

  // Scale to 0-100 for easier interpretation
  return Math.min(100, movementComponent * 10);
}

const historicalMovement = calculateMovementIntensity(7.2, 1.91, 6.07);
const currentMovement = calculateMovementIntensity(5.34, 2.06, 7.86);

console.log(`Historical Movement Level: ${historicalMovement.toFixed(1)}/100`);
console.log(`Current Movement Level: ${currentMovement.toFixed(1)}/100`);

console.log("\n🧠 WHY ANXIETY DETECTION WAS MISSING MOVEMENT:");
console.log("===============================================");
console.log("❌ The system was looking for:");
console.log('   • "movementLevel" field');
console.log('   • "movement" field');
console.log('   • "accelerometer" field');

console.log("\n✅ But your device sends:");
console.log('   • "accelX", "accelY", "accelZ" fields');
console.log('   • "gyroX", "gyroY", "gyroZ" fields');
console.log('   • "pitch", "roll" orientation data');

console.log("\n🔧 SOLUTION NEEDED:");
console.log("===================");
console.log("The anxiety detection algorithm needs to be updated to:");
console.log('1. Read accelX/Y/Z instead of "movementLevel"');
console.log("2. Calculate movement intensity from accelerometer data");
console.log("3. Use gyroscope data to detect tremors/restlessness");
console.log("4. Enable exercise vs anxiety distinction");

console.log("\n🏃 EXERCISE DETECTION NOW POSSIBLE:");
console.log("===================================");
console.log("✅ Walking: Steady accelerometer patterns");
console.log("✅ Stairs: Rhythmic vertical movement");
console.log("✅ Exercise: Sustained high movement + high HR");
console.log("✅ Sitting still: Low accelerometer values");

console.log("\n😰 ANXIETY DETECTION IMPROVEMENTS:");
console.log("==================================");
console.log("✅ Tremors: Small rapid gyroscope changes");
console.log("✅ Restlessness: Irregular accelerometer spikes");
console.log("✅ Anxiety while resting: High HR + low movement");
console.log("✅ False alarm reduction: High HR + exercise movement = no alert");

console.log("\n🚀 NEXT STEPS:");
console.log("===============");
console.log("1. Update Firebase Cloud Functions to read accelX/Y/Z");
console.log("2. Add movement calculation logic");
console.log("3. Implement exercise detection algorithms");
console.log("4. Test with real activities (walking, sitting, anxiety)");
console.log("5. Fine-tune thresholds for accurate detection");

console.log("\n💡 YOUR CURRENT STATUS:");
console.log("========================");
if (currentMovement < 10) {
  console.log("✅ Currently SITTING/RESTING (low movement)");
  console.log("✅ Heart rate monitoring accurate for anxiety detection");
} else if (currentMovement < 30) {
  console.log("⚡ Light movement detected");
  console.log("⚡ Could be fidgeting or small movements");
} else {
  console.log("🏃 Active movement detected");
  console.log("🏃 This should prevent false anxiety alerts");
}

console.log(
  `\nHeart Rate: 86.8 BPM (elevated but movement context available now!)`
);
console.log(`Movement Level: ${currentMovement.toFixed(1)}/100`);
console.log("🎯 With movement data, the system can now be much smarter!");
