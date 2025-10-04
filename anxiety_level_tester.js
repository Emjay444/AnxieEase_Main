const https = require("https");

// Function to update Firebase Realtime Database via REST API
function updateFirebaseData(path, data) {
  return new Promise((resolve, reject) => {
    const dataStr = JSON.stringify(data);

    const options = {
      hostname:
        "anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
      port: 443,
      path: `${path}.json`,
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(dataStr),
      },
    };

    const req = https.request(options, (res) => {
      let responseData = "";
      res.on("data", (chunk) => {
        responseData += chunk;
      });
      res.on("end", () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(responseData));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${responseData}`));
        }
      });
    });

    req.on("error", (e) => {
      reject(e);
    });

    req.write(dataStr);
    req.end();
  });
}

// Generate sensor data for different anxiety levels
function generateSensorData(severity, timestamp) {
  let heartRate, stressLevel, movement, confidence;

  switch (severity) {
    case "mild":
      heartRate = 85 + Math.random() * 10; // 85-95 BPM
      stressLevel = 0.6 + Math.random() * 0.1; // 0.6-0.7
      movement = 0.3 + Math.random() * 0.2;
      confidence = 60;
      break;

    case "moderate":
      heartRate = 95 + Math.random() * 15; // 95-110 BPM
      stressLevel = 0.7 + Math.random() * 0.1; // 0.7-0.8
      movement = 0.5 + Math.random() * 0.3;
      confidence = 70;
      break;

    case "severe":
      heartRate = 110 + Math.random() * 20; // 110-130 BPM
      stressLevel = 0.8 + Math.random() * 0.15; // 0.8-0.95
      movement = 0.7 + Math.random() * 0.3;
      confidence = 85;
      break;

    case "critical":
      heartRate = 130 + Math.random() * 25; // 130-155 BPM
      stressLevel = 0.9 + Math.random() * 0.1; // 0.9-1.0
      movement = 0.8 + Math.random() * 0.2;
      confidence = 95;
      break;

    default:
      heartRate = 75 + Math.random() * 10;
      stressLevel = 0.3 + Math.random() * 0.2;
      movement = 0.1 + Math.random() * 0.2;
      confidence = 50;
  }

  return {
    heartRate: Math.round(heartRate),
    stressLevel: Math.round(stressLevel * 100) / 100,
    movementIntensity: Math.round(movement * 100) / 100,
    confidence: confidence,
    timestamp: timestamp,
    lastUpdated: timestamp,
    temperature: Math.round((36.5 + Math.random() * 1) * 10) / 10,
    bloodOxygen: Math.round(96 + Math.random() * 3),
    battPerc: 75 + Math.random() * 20,
  };
}

// Test sequence for all anxiety levels
async function testAllAnxietyLevels() {
  console.log("🧪 Testing ALL Anxiety Notification Levels");
  console.log("==========================================");
  console.log(
    "This will test mild → moderate → severe → critical notifications"
  );
  console.log(
    "Each level will be sustained for 15 seconds to trigger detection.\n"
  );

  const severityLevels = [
    {
      level: "mild",
      duration: 15,
      description: "🟢 Mild Anxiety (85-95 BPM, 60% confidence)",
    },
    {
      level: "moderate",
      duration: 15,
      description: "🟠 Moderate Anxiety (95-110 BPM, 70% confidence)",
    },
    {
      level: "severe",
      duration: 15,
      description: "🔴 Severe Anxiety (110-130 BPM, 85% confidence)",
    },
    {
      level: "critical",
      duration: 15,
      description: "🚨 CRITICAL Anxiety (130+ BPM, 95% confidence)",
    },
  ];

  try {
    for (let i = 0; i < severityLevels.length; i++) {
      const { level, duration, description } = severityLevels[i];

      console.log(`\n📊 Phase ${i + 1}: ${description}`);
      console.log(`⏱️ Duration: ${duration} seconds`);
      console.log("---");

      await simulateAnxietyLevel(level, duration);

      if (i < severityLevels.length - 1) {
        console.log(`✅ ${level.toUpperCase()} level completed!`);
        console.log("⏳ Waiting 8 seconds before next level...\n");
        await sleep(8000);
      }
    }

    console.log("\n🎉 ALL ANXIETY LEVELS TESTED!");
    console.log("📱 You should have received 4 different notifications:");
    console.log("   1️⃣ 🟢 Mild Alert - 60% Confidence");
    console.log("   2️⃣ 🟠 Moderate Alert - 70% Confidence");
    console.log("   3️⃣ 🔴 Severe Alert - 85% Confidence");
    console.log("   4️⃣ 🚨 CRITICAL Alert - 95% Confidence");
    console.log(
      "\n🔔 These are real notifications with different severity levels!"
    );
  } catch (error) {
    console.error("❌ Error during testing:", error);
  }
}

// Simulate a specific anxiety level for a duration
async function simulateAnxietyLevel(severity, durationSeconds) {
  const deviceId = "AnxieEase001";
  const startTime = Date.now();
  const endTime = startTime + durationSeconds * 1000;

  let updateCount = 0;

  return new Promise((resolve, reject) => {
    const updateInterval = setInterval(async () => {
      const currentTime = Date.now();

      if (currentTime >= endTime) {
        clearInterval(updateInterval);
        console.log(
          `✅ ${severity.toUpperCase()} simulation completed (${updateCount} updates)`
        );
        resolve(updateCount);
        return;
      }

      try {
        const sensorData = generateSensorData(severity, currentTime);
        await updateFirebaseData(`/devices/${deviceId}/current`, sensorData);

        updateCount++;

        // Log every 3rd update
        if (updateCount % 3 === 0) {
          console.log(
            `📈 ${severity} update ${updateCount}: HR=${sensorData.heartRate} BPM`
          );
        }
      } catch (error) {
        clearInterval(updateInterval);
        reject(error);
      }
    }, 2500); // Update every 2.5 seconds for sustained detection
  });
}

// Test a single anxiety level
async function testSingleLevel(severity, duration = 20) {
  console.log(`🚨 Testing ${severity.toUpperCase()} Anxiety Level`);
  console.log("=======================================");

  const severityInfo = {
    mild: "🟢 Mild (85-95 BPM, light anxiety)",
    moderate: "🟠 Moderate (95-110 BPM, noticeable symptoms)",
    severe: "🔴 Severe (110-130 BPM, high anxiety)",
    critical: "🚨 CRITICAL (130+ BPM, panic level)",
  };

  console.log(`📊 Level: ${severityInfo[severity]}`);
  console.log(`⏱️ Duration: ${duration} seconds`);
  console.log(`🔔 This will trigger real ${severity} anxiety notifications!\n`);

  try {
    await simulateAnxietyLevel(severity, duration);
    console.log(`\n🎉 ${severity.toUpperCase()} test completed!`);
    console.log("📱 Check your device for the notification!");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
}

// Utility function for delays
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Command line interface
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log("🧪 Complete Anxiety Notification Tester");
  console.log("=======================================");
  console.log("Usage options:");
  console.log("");
  console.log("1. Test all levels (recommended):");
  console.log("   node anxiety_level_tester.js all");
  console.log("   (Tests mild → moderate → severe → critical)");
  console.log("");
  console.log("2. Test single level:");
  console.log("   node anxiety_level_tester.js <level> [duration]");
  console.log("   Examples:");
  console.log("   - node anxiety_level_tester.js mild");
  console.log("   - node anxiety_level_tester.js moderate 25");
  console.log("   - node anxiety_level_tester.js severe 30");
  console.log("   - node anxiety_level_tester.js critical 20");
  console.log("");
  console.log("Levels: mild, moderate, severe, critical");
  console.log("Duration: Seconds to simulate (default: 20)");
  console.log("");
  console.log("🔥 Updates Firebase to trigger real-time anxiety detection");
  console.log("🔔 Generates actual notifications users would receive!");
  process.exit(0);
}

const command = args[0].toLowerCase();

if (command === "all") {
  testAllAnxietyLevels();
} else if (["mild", "moderate", "severe", "critical"].includes(command)) {
  const duration = args[1] ? parseInt(args[1]) : 20;

  if (duration < 10 || duration > 120) {
    console.error("❌ Duration must be between 10 and 120 seconds");
    process.exit(1);
  }

  testSingleLevel(command, duration);
} else {
  console.error(
    '❌ Invalid command. Use "all" or a level (mild/moderate/severe/critical)'
  );
  process.exit(1);
}
