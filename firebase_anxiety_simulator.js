const https = require("https");

// Firebase REST API configuration
const FIREBASE_PROJECT_ID = "anxieease-sensors";
const FIREBASE_DATABASE_URL = `https://${FIREBASE_PROJECT_ID}-default-rtdb.firebaseio.com`;

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

// Generate realistic sensor data based on anxiety severity
function generateSensorData(severity, timestamp) {
  let heartRate, stressLevel, movement;

  switch (severity) {
    case "mild":
      heartRate = 85 + Math.random() * 10; // 85-95 BPM
      stressLevel = 0.6 + Math.random() * 0.1; // 0.6-0.7
      movement = 0.3 + Math.random() * 0.2;
      break;

    case "moderate":
      heartRate = 95 + Math.random() * 15; // 95-110 BPM
      stressLevel = 0.7 + Math.random() * 0.1; // 0.7-0.8
      movement = 0.5 + Math.random() * 0.3;
      break;

    case "severe":
      heartRate = 110 + Math.random() * 20; // 110-130 BPM
      stressLevel = 0.8 + Math.random() * 0.15; // 0.8-0.95
      movement = 0.7 + Math.random() * 0.3;
      break;

    default:
      heartRate = 75 + Math.random() * 10;
      stressLevel = 0.3 + Math.random() * 0.2;
      movement = 0.1 + Math.random() * 0.2;
  }

  return {
    heartRate: Math.round(heartRate),
    stressLevel: Math.round(stressLevel * 100) / 100,
    movementIntensity: Math.round(movement * 100) / 100,
    timestamp: timestamp,
    lastUpdated: timestamp,
    temperature: Math.round((36.5 + Math.random() * 1) * 10) / 10,
    bloodOxygen: Math.round(96 + Math.random() * 3),
    battPerc: 75 + Math.random() * 20,
  };
}

// Simulate continuous sensor updates to trigger real-time detection
async function simulateAnxietyCondition(severity, durationSeconds = 30) {
  const deviceId = "AnxieEase001";
  const startTime = Date.now();
  const endTime = startTime + durationSeconds * 1000;

  console.log(
    `🚨 Simulating ${severity.toUpperCase()} anxiety condition for ${durationSeconds} seconds...`
  );
  console.log(
    `📊 This will continuously update Firebase /devices/${deviceId}/current`
  );
  console.log(`🔔 Real-time anxiety detection should trigger notifications!`);
  console.log(`⏰ Started at: ${new Date(startTime).toLocaleTimeString()}`);
  console.log("---");

  let updateCount = 0;

  const updateInterval = setInterval(async () => {
    const currentTime = Date.now();

    if (currentTime >= endTime) {
      clearInterval(updateInterval);
      console.log(
        `✅ Simulation completed! Made ${updateCount} Firebase updates.`
      );
      console.log(`🔔 Check your device for real-time anxiety notifications!`);
      process.exit(0);
      return;
    }

    try {
      // Generate realistic sensor data
      const sensorData = generateSensorData(severity, currentTime);

      // Update Firebase current data - this triggers realTimeSustainedAnxietyDetection
      await updateFirebaseData(`/devices/${deviceId}/current`, sensorData);

      updateCount++;

      // Log every 3rd update to avoid spam
      if (updateCount % 3 === 0) {
        console.log(
          `📈 Update ${updateCount}: HR=${sensorData.heartRate} BPM, Stress=${sensorData.stressLevel}`
        );
      }
    } catch (error) {
      console.error("❌ Error updating Firebase:", error.message);
    }
  }, 2000); // Update every 2 seconds for sustained detection

  // Handle Ctrl+C gracefully
  process.on("SIGINT", () => {
    clearInterval(updateInterval);
    console.log(
      `\n⏹️ Simulation stopped. Made ${updateCount} Firebase updates.`
    );
    process.exit(0);
  });
}

// Send a single sensor update
async function sendSingleUpdate(severity) {
  const deviceId = "AnxieEase001";
  const timestamp = Date.now();

  console.log(
    `🚨 Sending single ${severity.toUpperCase()} sensor update to Firebase...`
  );

  try {
    const sensorData = generateSensorData(severity, timestamp);
    await updateFirebaseData(`/devices/${deviceId}/current`, sensorData);

    console.log(`✅ Firebase updated successfully!`);
    console.log(
      `📊 Data: HR=${sensorData.heartRate} BPM, Stress=${sensorData.stressLevel}`
    );
    console.log(
      `🔔 This should trigger real-time anxiety detection if sustained.`
    );
  } catch (error) {
    console.error("❌ Error updating Firebase:", error.message);
  }
}

// Command line interface
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log("🚨 Firebase Anxiety Data Simulator");
  console.log("==================================");
  console.log(
    "This script directly updates Firebase to trigger real-time anxiety detection."
  );
  console.log("");
  console.log("Usage options:");
  console.log("");
  console.log("1. Continuous simulation (recommended):");
  console.log("   node firebase_anxiety_simulator.js <severity> [duration]");
  console.log("   Example: node firebase_anxiety_simulator.js severe 45");
  console.log("");
  console.log("2. Single update:");
  console.log("   node firebase_anxiety_simulator.js <severity> single");
  console.log("   Example: node firebase_anxiety_simulator.js moderate single");
  console.log("");
  console.log("Severity options: mild, moderate, severe");
  console.log("Duration: Seconds to simulate (default: 30)");
  console.log("");
  console.log("🔥 This updates Firebase /devices/AnxieEase001/current");
  console.log("🔔 Real-time anxiety detection will trigger notifications!");
  process.exit(0);
}

const severity = args[0].toLowerCase();

if (!["mild", "moderate", "severe"].includes(severity)) {
  console.error("❌ Invalid severity. Use: mild, moderate, or severe");
  process.exit(1);
}

if (args[1] === "single") {
  sendSingleUpdate(severity);
} else {
  const duration = args[1] ? parseInt(args[1]) : 30;

  if (duration < 10 || duration > 300) {
    console.error("❌ Duration must be between 10 and 300 seconds");
    process.exit(1);
  }

  simulateAnxietyCondition(severity, duration);
}
