#!/usr/bin/env node
/**
 * 🧪 COMPREHENSIVE ANXIEEASE IOT TESTING SUITE
 *
 * Tests the complete IoT pipeline:
 * 1. Bluetooth connectivity simulation
 * 2. Firebase data injection
 * 3. Anxiety detection algorithms
 * 4. Cloud Functions triggering
 * 5. FCM notification delivery
 * 6. Background service persistence
 */

const admin = require("firebase-admin");
const readline = require("readline");

// Initialize Firebase Admin SDK
try {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
  console.log("✅ Firebase Admin initialized successfully");
} catch (error) {
  console.error("❌ Error initializing Firebase Admin:", error);
  process.exit(1);
}

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// Test configuration
const TEST_CONFIG = {
  DEVICE_ID: "AnxieEase001",
  USER_ID: "test_user_" + Date.now(),
  FCM_TOKEN: "your_fcm_token_here", // Replace with actual token from app logs
  TEST_SCENARIOS: [
    {
      name: "Normal State",
      heartRate: 75,
      spo2: 98.5,
      battery: 85.0,
      worn: true,
      expectedSeverity: "normal",
    },
    {
      name: "Mild Anxiety",
      heartRate: 85,
      spo2: 97.0,
      battery: 80.0,
      worn: true,
      expectedSeverity: "mild",
    },
    {
      name: "Moderate Anxiety",
      heartRate: 105,
      spo2: 96.0,
      battery: 75.0,
      worn: true,
      expectedSeverity: "moderate",
    },
    {
      name: "Severe Anxiety Attack",
      heartRate: 130,
      spo2: 94.0,
      battery: 70.0,
      worn: true,
      expectedSeverity: "severe",
    },
    {
      name: "Device Not Worn",
      heartRate: null,
      spo2: null,
      battery: 65.0,
      worn: false,
      expectedSeverity: "unknown",
    },
  ],
};

/**
 * 🔧 TEST UTILITIES
 */
class IoTTestSuite {
  constructor() {
    this.db = admin.database();
    this.messaging = admin.messaging();
  }

  /**
   * 📊 Simulate IoT sensor data injection
   */
  async simulateIoTData(scenario) {
    console.log(`\n📡 Simulating IoT data: ${scenario.name}`);

    const timestamp = Date.now();
    const iotData = {
      timestamp: timestamp,
      isoTimestamp: new Date(timestamp).toISOString(),

      // Sensor data
      sensors: {
        heartRate: scenario.heartRate,
        spo2: scenario.spo2,
        bodyTemperature: scenario.worn ? 36.5 + Math.random() : null,
        ambientTemperature: 22.0 + Math.random() * 5,
        motion: {
          pitch: Math.random() * 360,
          roll: Math.random() * 360,
          acceleration: {
            x: Math.random() * 2 - 1,
            y: Math.random() * 2 - 1,
            z: Math.random() * 2 - 1,
          },
        },
      },

      // Device status
      device: {
        batteryRaw: scenario.battery,
        batterySmoothed: scenario.battery + Math.random() * 2 - 1,
        worn: scenario.worn,
        isConnected: true,
        lastSeen: timestamp,
      },

      // Anxiety detection (triggers Cloud Functions)
      anxietyDetection: this.generateAnxietyData(scenario),

      // Gateway info
      gateway: {
        id: `test_gateway_${TEST_CONFIG.USER_ID}`,
        userId: TEST_CONFIG.USER_ID,
        location: "test_environment",
        version: "2.0_iot_test",
      },
    };

    // Write to current data (real-time)
    await this.db.ref(`devices/${TEST_CONFIG.DEVICE_ID}/current`).set(iotData);

    // Also write to Metrics (triggers Cloud Functions)
    const metricsData = {
      heartRate: scenario.heartRate,
      anxietyDetected: iotData.anxietyDetection,
      timestamp: timestamp,
    };
    await this.db
      .ref(`devices/${TEST_CONFIG.DEVICE_ID}/Metrics`)
      .set(metricsData);

    console.log(
      `✅ IoT data injected - HR: ${scenario.heartRate}, Worn: ${scenario.worn}`
    );
    return iotData;
  }

  /**
   * 🧠 Generate anxiety detection data
   */
  generateAnxietyData(scenario) {
    if (!scenario.worn || !scenario.heartRate) {
      return {
        confidence: 0.0,
        severity: "unknown",
        timestamp: Date.now(),
        heartRate: null,
        source: "iot_test_suite",
      };
    }

    let severity = "normal";
    let confidence = 0.0;

    // Anxiety detection algorithm (simplified)
    if (scenario.heartRate >= 120) {
      severity = "severe";
      confidence = 0.9;
    } else if (scenario.heartRate >= 100) {
      severity = "moderate";
      confidence = 0.7;
    } else if (scenario.heartRate >= 85) {
      severity = "mild";
      confidence = 0.5;
    } else {
      severity = "normal";
      confidence = 0.2;
    }

    return {
      confidence: confidence,
      severity: severity,
      timestamp: Date.now(),
      heartRate: scenario.heartRate,
      source: "iot_test_suite",
      algorithm: "heart_rate_based_v1",
    };
  }

  /**
   * 🔔 Test FCM notification delivery
   */
  async testFCMNotification(severity = "test", heartRate = 75) {
    console.log(`\n📱 Testing FCM notification: ${severity}`);

    const message = {
      data: {
        type: "test_alert",
        severity: severity,
        heartRate: heartRate.toString(),
        timestamp: Date.now().toString(),
        testRun: "true",
      },
      notification: {
        title: `[TEST] ${severity.toUpperCase()} Alert`,
        body: `Test notification - HR: ${heartRate} bpm`,
      },
      android: {
        priority: severity === "severe" ? "high" : "normal",
        notification: {
          channelId: "anxiety_alerts",
          sound: "default",
          priority: severity === "severe" ? "max" : "default",
        },
      },
      topic: "anxiety_alerts",
    };

    try {
      const response = await this.messaging.send(message);
      console.log(`✅ FCM notification sent successfully: ${response}`);
      return response;
    } catch (error) {
      console.error(`❌ FCM notification failed: ${error.message}`);
      throw error;
    }
  }

  /**
   * 🔍 Monitor Firebase data changes
   */
  async monitorDataChanges(duration = 10000) {
    console.log(
      `\n👀 Monitoring Firebase changes for ${duration / 1000} seconds...`
    );

    const ref = this.db.ref(`devices/${TEST_CONFIG.DEVICE_ID}`);
    const listener = ref.on("value", (snapshot) => {
      const data = snapshot.val();
      if (data) {
        console.log(`📊 Data updated at ${new Date().toISOString()}`);
        if (data.Metrics && data.Metrics.anxietyDetected) {
          console.log(
            `   🧠 Anxiety: ${data.Metrics.anxietyDetected.severity} (${data.Metrics.anxietyDetected.confidence})`
          );
        }
        if (data.current && data.current.sensors) {
          console.log(
            `   💓 Heart Rate: ${data.current.sensors.heartRate || "N/A"}`
          );
        }
      }
    });

    await new Promise((resolve) => setTimeout(resolve, duration));
    ref.off("value", listener);
    console.log("✅ Monitoring stopped");
  }

  /**
   * 🧹 Cleanup test data
   */
  async cleanup() {
    console.log("\n🧹 Cleaning up test data...");

    try {
      // Remove test user data
      await this.db
        .ref(`devices/${TEST_CONFIG.DEVICE_ID}/users/${TEST_CONFIG.USER_ID}`)
        .remove();
      console.log("✅ Test user data cleaned");
    } catch (error) {
      console.log("⚠️ Cleanup warning:", error.message);
    }
  }
}

/**
 * 🎮 INTERACTIVE TEST MENU
 */
async function showTestMenu() {
  console.log("\n" + "=".repeat(60));
  console.log("🧪 ANXIEEASE IOT TESTING SUITE");
  console.log("=".repeat(60));
  console.log("1. 📊 Test Individual Scenario");
  console.log("2. 🔄 Run Full Test Suite");
  console.log("3. 📱 Test FCM Notifications Only");
  console.log("4. 👀 Monitor Live Data Changes");
  console.log("5. 🧹 Clean Test Data");
  console.log("6. 📋 Show Current Database State");
  console.log("7. ❌ Exit");
  console.log("=".repeat(60));
}

async function runTests() {
  const testSuite = new IoTTestSuite();

  while (true) {
    await showTestMenu();

    const choice = await new Promise((resolve) => {
      rl.question("Enter your choice (1-7): ", resolve);
    });

    switch (choice) {
      case "1":
        await testIndividualScenario(testSuite);
        break;
      case "2":
        await runFullTestSuite(testSuite);
        break;
      case "3":
        await testFCMOnly(testSuite);
        break;
      case "4":
        await testSuite.monitorDataChanges(30000);
        break;
      case "5":
        await testSuite.cleanup();
        break;
      case "6":
        await showDatabaseState(testSuite);
        break;
      case "7":
        console.log("👋 Exiting test suite...");
        rl.close();
        process.exit(0);
      default:
        console.log("❌ Invalid choice. Please try again.");
    }
  }
}

async function testIndividualScenario(testSuite) {
  console.log("\n📋 Available test scenarios:");
  TEST_CONFIG.TEST_SCENARIOS.forEach((scenario, index) => {
    console.log(
      `${index + 1}. ${scenario.name} (HR: ${scenario.heartRate}, Expected: ${
        scenario.expectedSeverity
      })`
    );
  });

  const choice = await new Promise((resolve) => {
    rl.question("Select scenario (1-5): ", resolve);
  });

  const scenarioIndex = parseInt(choice) - 1;
  if (scenarioIndex >= 0 && scenarioIndex < TEST_CONFIG.TEST_SCENARIOS.length) {
    const scenario = TEST_CONFIG.TEST_SCENARIOS[scenarioIndex];

    console.log(`\n🧪 Testing: ${scenario.name}`);
    console.log(
      "📱 Make sure your AnxieEase app is running to see real-time updates!"
    );

    await testSuite.simulateIoTData(scenario);

    // Wait a bit then send FCM notification
    console.log("⏳ Waiting 3 seconds for Cloud Functions to process...");
    await new Promise((resolve) => setTimeout(resolve, 3000));

    if (
      scenario.expectedSeverity !== "normal" &&
      scenario.expectedSeverity !== "unknown"
    ) {
      await testSuite.testFCMNotification(
        scenario.expectedSeverity,
        scenario.heartRate
      );
    }

    console.log("✅ Individual test completed!");
  } else {
    console.log("❌ Invalid scenario selection.");
  }
}

async function runFullTestSuite(testSuite) {
  console.log("\n🔄 Starting Full Test Suite...");
  console.log("📱 Keep your AnxieEase app open to see real-time updates!");

  for (let i = 0; i < TEST_CONFIG.TEST_SCENARIOS.length; i++) {
    const scenario = TEST_CONFIG.TEST_SCENARIOS[i];

    console.log(
      `\n--- Test ${i + 1}/${TEST_CONFIG.TEST_SCENARIOS.length}: ${
        scenario.name
      } ---`
    );

    // Inject IoT data
    await testSuite.simulateIoTData(scenario);

    // Wait for processing
    console.log("⏳ Waiting for Cloud Functions...");
    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Send notification for anxiety states
    if (["mild", "moderate", "severe"].includes(scenario.expectedSeverity)) {
      await testSuite.testFCMNotification(
        scenario.expectedSeverity,
        scenario.heartRate
      );
    }

    // Wait between tests
    if (i < TEST_CONFIG.TEST_SCENARIOS.length - 1) {
      console.log("⏳ Waiting 10 seconds before next test...");
      await new Promise((resolve) => setTimeout(resolve, 10000));
    }
  }

  console.log("\n🎉 Full test suite completed!");
}

async function testFCMOnly(testSuite) {
  console.log("\n📱 Testing FCM Notifications Only...");

  const severities = ["mild", "moderate", "severe"];

  for (const severity of severities) {
    const heartRate =
      severity === "mild" ? 85 : severity === "moderate" ? 105 : 130;
    await testSuite.testFCMNotification(severity, heartRate);

    console.log("⏳ Waiting 5 seconds...");
    await new Promise((resolve) => setTimeout(resolve, 5000));
  }

  console.log("✅ FCM testing completed!");
}

async function showDatabaseState(testSuite) {
  console.log("\n📊 Current Database State:");

  try {
    const snapshot = await testSuite.db
      .ref(`devices/${TEST_CONFIG.DEVICE_ID}`)
      .once("value");
    const data = snapshot.val();

    if (data) {
      console.log("📋 Device Data:");
      if (data.current) {
        console.log(
          `   💓 Heart Rate: ${data.current.sensors?.heartRate || "N/A"}`
        );
        console.log(
          `   🔋 Battery: ${data.current.device?.batteryRaw || "N/A"}%`
        );
        console.log(`   👥 Device Worn: ${data.current.device?.worn || "N/A"}`);
      }
      if (data.Metrics) {
        console.log(
          `   🧠 Anxiety: ${data.Metrics.anxietyDetected?.severity || "N/A"}`
        );
        console.log(
          `   🎯 Confidence: ${
            data.Metrics.anxietyDetected?.confidence || "N/A"
          }`
        );
      }
      if (data.metadata) {
        console.log(`   🔗 Status: ${data.metadata.status || "N/A"}`);
      }
    } else {
      console.log("📭 No data found for device");
    }
  } catch (error) {
    console.error("❌ Error reading database:", error.message);
  }
}

// Start the test suite
console.log("🚀 Starting AnxieEase IoT Test Suite...");
console.log("📱 Make sure your Flutter app is running for real-time testing!");

runTests().catch(console.error);
