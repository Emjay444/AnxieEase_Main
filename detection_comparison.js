/**
 * COMPARISON: PERSONALIZED vs SUSTAINED ANXIETY DETECTION
 * Your AnxieEase system has TWO different detection methods
 */

console.log('🔍 PERSONALIZED vs SUSTAINED ANXIETY DETECTION COMPARISON');
console.log('='.repeat(70));

const YOUR_BASELINE = 73.2; // BPM

console.log('\n📊 SYSTEM OVERVIEW:');
console.log('Your AnxieEase app runs TWO detection systems simultaneously:');
console.log('1. Personalized Detection (Immediate)');
console.log('2. Sustained Detection (30-second rule)');

console.log('\n' + '='.repeat(35) + ' SYSTEM 1 ' + '='.repeat(35));
console.log('🚀 PERSONALIZED DETECTION (Immediate)');
console.log('='.repeat(70));

console.log('\n📍 TRIGGER:');
console.log('• Function: detectPersonalizedAnxiety');
console.log('• Firebase Path: /devices/{deviceId}/current/heartRate');
console.log('• Trigger: ANY heart rate change/update');

console.log('\n🎯 THRESHOLDS (Fixed BPM additions):');
const personalizedThresholds = {
  elevated: YOUR_BASELINE + 10,  // +10 BPM
  mild: YOUR_BASELINE + 15,      // +15 BPM
  moderate: YOUR_BASELINE + 25,  // +25 BPM
  severe: YOUR_BASELINE + 35,    // +35 BPM
  critical: YOUR_BASELINE + 45   // +45 BPM
};

console.log(`📘 Elevated:   ${personalizedThresholds.elevated} BPM (+10 BPM)`);
console.log(`🟡 Mild:       ${personalizedThresholds.mild} BPM (+15 BPM)`);
console.log(`🟠 Moderate:   ${personalizedThresholds.moderate} BPM (+25 BPM)`);
console.log(`🔴 Severe:     ${personalizedThresholds.severe} BPM (+35 BPM)`);
console.log(`🚨 Critical:   ${personalizedThresholds.critical} BPM (+45 BPM)`);

console.log('\n⏱️ TIMING:');
console.log('• Duration: INSTANT (no time requirement)');
console.log('• Triggers: As soon as HR changes to new severity level');
console.log('• Example: 73 BPM → 89 BPM = immediate mild alert');

console.log('\n📋 LOGIC:');
console.log('• Compares: OLD heart rate vs NEW heart rate');
console.log('• Sends alert: Only when severity CHANGES');
console.log('• Rate limiting: Yes (enhanced with user confirmations)');

console.log('\n' + '='.repeat(35) + ' SYSTEM 2 ' + '='.repeat(35));
console.log('⏰ SUSTAINED DETECTION (30-second rule)');
console.log('='.repeat(70));

console.log('\n📍 TRIGGER:');
console.log('• Function: realTimeSustainedAnxietyDetection');
console.log('• Firebase Path: /devices/{deviceId}/current (entire object)');
console.log('• Trigger: ANY device data update');

console.log('\n🎯 THRESHOLDS (Percentage-based):');
const sustainedThreshold = YOUR_BASELINE * 1.2; // 20% above baseline
console.log(`🚨 Anxiety Threshold: ${sustainedThreshold.toFixed(1)} BPM (20% above baseline)`);

console.log('\n📈 SEVERITY (% above baseline):');
console.log('🟡 Mild:     20-29% above baseline');
console.log('🟠 Moderate: 30-49% above baseline');
console.log('🔴 Severe:   50-79% above baseline');
console.log('🚨 Critical: 80%+ above baseline');

console.log('\n⏱️ TIMING:');
console.log('• Duration: Must stay elevated for 30+ CONTINUOUS seconds');
console.log('• Analysis: Reviews user session history (last 40 data points)');
console.log('• Example: 90 BPM for 35 seconds = sustained anxiety alert');

console.log('\n📋 LOGIC:');
console.log('• Analyzes: Historical data pattern over time');
console.log('• Requires: Continuous elevation, not just spikes');
console.log('• Rate limiting: Yes (2-minute window)');

console.log('\n' + '='.repeat(25) + ' KEY DIFFERENCES ' + '='.repeat(25));

console.log('\n🚀 PERSONALIZED vs ⏰ SUSTAINED:');
console.log('');
console.log('TRIGGER SPEED:');
console.log('🚀 Personalized: INSTANT (any HR change)');
console.log('⏰ Sustained:    30+ seconds required');
console.log('');
console.log('THRESHOLD TYPE:');
console.log('🚀 Personalized: Fixed BPM additions (+10, +15, +25, etc.)');
console.log('⏰ Sustained:    Percentage-based (20% above baseline)');
console.log('');
console.log('YOUR TRIGGER POINTS:');
console.log('🚀 Personalized: 83.2 BPM (immediate)');
console.log('⏰ Sustained:    87.8 BPM (for 30+ seconds)');
console.log('');
console.log('FALSE POSITIVE PROTECTION:');
console.log('🚀 Personalized: Lower (can trigger on brief spikes)');
console.log('⏰ Sustained:    Higher (filters out temporary increases)');
console.log('');
console.log('USE CASE:');
console.log('🚀 Personalized: Quick check-ins, early warnings');
console.log('⏰ Sustained:    True anxiety episodes, clinical accuracy');

console.log('\n🎯 EXAMPLE SCENARIOS:');
console.log('');
console.log('Scenario 1: Brief stress spike');
console.log('• HR: 73 → 95 BPM for 10 seconds → back to 75 BPM');
console.log('🚀 Personalized: TRIGGERS (mild alert at 95 BPM)');
console.log('⏰ Sustained:    NO TRIGGER (only 10 seconds, need 30+)');
console.log('');
console.log('Scenario 2: Sustained anxiety episode');
console.log('• HR: 73 → 95 BPM for 45 seconds straight');
console.log('🚀 Personalized: TRIGGERS (mild alert immediately)');
console.log('⏰ Sustained:    TRIGGERS (mild sustained anxiety at 30s mark)');
console.log('');
console.log('Scenario 3: Climbing stairs');
console.log('• HR: 73 → 110 BPM for 20 seconds → back to 80 BPM');
console.log('🚀 Personalized: TRIGGERS (severe alert at 110 BPM)');
console.log('⏰ Sustained:    NO TRIGGER (only 20 seconds, likely physical activity)');

console.log('\n💡 WHICH SYSTEM IS BETTER?');
console.log('');
console.log('🏥 FOR CLINICAL/MEDICAL USE:');
console.log('⏰ Sustained Detection - More accurate, fewer false positives');
console.log('');
console.log('🔔 FOR USER ENGAGEMENT:');
console.log('🚀 Personalized Detection - Immediate feedback, proactive care');
console.log('');
console.log('🎯 YOUR CURRENT SETUP:');
console.log('BOTH systems are active simultaneously, giving you:');
console.log('• Immediate feedback for any HR changes');
console.log('• Robust anxiety detection for true episodes');
console.log('• Comprehensive monitoring coverage');

console.log('\n' + '='.repeat(70));
console.log('✅ Both systems work together for complete anxiety monitoring!');