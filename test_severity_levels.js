const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

// Force different severity levels by using different heart rates
async function testSeverityLevels() {
  console.log("🧪 TESTING SPECIFIC SEVERITY LEVELS");
  console.log("════════════════════════════════════════");
  console.log("📊 Using baseline of 73.2 BPM");
  console.log("🔬 Testing each severity threshold:");
  console.log("   • Mild: 20-29% above (88-94 BPM)");
  console.log("   • Moderate: 30-49% above (95-109 BPM)");
  console.log("   • Severe: 50-79% above (110-131 BPM)");
  console.log("   • Critical: 80%+ above (131+ BPM)");
  console.log("");

  const deviceRef = db.ref("/devices/AnxieEase001/current");
  const baselineHR = 73.2;

  // Test cases with specific heart rates for each severity
  const testCases = [
    { name: "MODERATE", hr: 100, expectedSeverity: "moderate", color: "🟠" },
    { name: "SEVERE", hr: 115, expectedSeverity: "severe", color: "🔴" },
    { name: "CRITICAL", hr: 140, expectedSeverity: "critical", color: "🚨" },
  ];

  for (const testCase of testCases) {
    console.log(
      `${testCase.color} Testing ${testCase.name} severity (${testCase.hr} BPM)`
    );
    const percentAbove = (
      ((testCase.hr - baselineHR) / baselineHR) *
      100
    ).toFixed(1);
    console.log(
      `   📈 ${percentAbove}% above baseline (should be ${testCase.expectedSeverity})`
    );

    // Send sustained data for 40 seconds to trigger detection
    for (let i = 0; i < 4; i++) {
      const data = {
        accelX: "0.0",
        accelY: "0.0",
        accelZ: "9.8",
        ambientTemp: "30.0",
        battPerc: 95,
        bodyTemp: 37.2,
        gyroX: "0.0",
        gyroY: "0.0",
        gyroZ: "0.0",
        heartRate: testCase.hr,
        pitch: "0.0",
        roll: 0,
        spo2: 97,
        timestamp: new Date().toISOString().replace("T", " ").slice(0, 19),
        worn: 1,
        fcmToken: "CZZfrUKQ2WMEATCG6qfLX-AP49blcAa8YrxS_9YKK4jA6d0zs",
      };

      await deviceRef.set(data);
      console.log(
        `   ${testCase.color} ${(i + 1) * 10}s: HR=${testCase.hr} BPM sent`
      );
      await new Promise((resolve) => setTimeout(resolve, 10000)); // Wait 10 seconds
    }

    console.log(
      `   ✅ ${testCase.name} test complete - check for ${testCase.expectedSeverity} notification`
    );
    console.log("");

    // Wait before next test
    if (testCase !== testCases[testCases.length - 1]) {
      console.log("⏳ Waiting 30 seconds before next test...");
      await new Promise((resolve) => setTimeout(resolve, 30000));
    }
  }

  console.log("🎯 All severity tests complete!");
  console.log("📱 Check your device for notifications of different severities");
  process.exit(0);
}

testSeverityLevels().catch(console.error);
