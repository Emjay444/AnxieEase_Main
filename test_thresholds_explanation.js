// Test anxiety detection with proper thresholds
// Assuming typical baseline of 70 BPM:
// - 20% above baseline = 84+ BPM (triggers anxiety detection)
// - 30% above = 91+ BPM (moderate)
// - 50% above = 105+ BPM (severe) 
// - 80+ above = 126+ BPM (critical)

console.log('🧪 Testing anxiety detection with proper thresholds...\n');

// Test cases with different heart rates
const testCases = [
  { hr: 90, expected: 'mild', description: 'Should trigger mild anxiety (90 BPM > 84 threshold)' },
  { hr: 100, expected: 'moderate', description: 'Should trigger moderate anxiety (100 BPM > 91 threshold)' },
  { hr: 120, expected: 'severe', description: 'Should trigger severe anxiety (120 BPM > 105 threshold)' },
  { hr: 140, expected: 'critical', description: 'Should trigger critical anxiety (140 BPM > 126 threshold)' }
];

console.log('📊 Assuming baseline of 70 BPM:\n');

testCases.forEach((test, index) => {
  const baseline = 70;
  const percentage = Math.round(((test.hr - baseline) / baseline) * 100);
  console.log(`${index + 1}. ${test.description}`);
  console.log(`   HR: ${test.hr} BPM (${percentage}% above baseline)`);
  console.log(`   Expected: ${test.expected} anxiety level\n`);
});

console.log('🚀 Now testing with sustained heart rates...');