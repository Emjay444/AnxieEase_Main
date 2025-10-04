const admin = require("firebase-admin");
const path = require("path");

// Initialize Firebase Admin SDK
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-default-rtdb.firebaseio.com",
});

const db = admin.database();

// Simulate continuous sensor data for anxiety detection
async function simulateAnxietyCondition(severity, durationSeconds = 30) {
  const deviceId = "AnxieEase001";
  const startTime = Date.now();
  const endTime = startTime + durationSeconds * 1000;

  console.log(
    `🚨 Simulating ${severity.toUpperCase()} anxiety condition for ${durationSeconds} seconds...`
  );
  console.log(
    `📊 This will continuously feed sensor data to trigger real-time detection.`
  );
  console.log(`⏰ Started at: ${new Date(startTime).toLocaleTimeString()}`);
  console.log("---");

  let dataPointCount = 0;

  const interval = setInterval(async () => {
    const currentTime = Date.now();

    if (currentTime >= endTime) {
      clearInterval(interval);
      console.log(
        `✅ Simulation completed! Sent ${dataPointCount} data points.`
      );
      console.log(`🔔 Check your device for anxiety alert notifications.`);
      process.exit(0);
      return;
    }

    try {
      // Generate realistic sensor data based on severity
      const sensorData = generateSensorData(severity, currentTime);

      // Write current sensor readings to Firebase
      await db.ref(`/devices/${deviceId}/current`).update(sensorData);

      dataPointCount++;

      // Log every 5th data point to avoid spam
      if (dataPointCount % 5 === 0) {
        console.log(
          `📈 Data point ${dataPointCount}: HR=${sensorData.heartRate}, HRV=${sensorData.hrv}, Stress=${sensorData.stressLevel}`
        );
      }
    } catch (error) {
      console.error("❌ Error sending sensor data:", error);
    }
  }, 1000); // Send data every 1 second

  // Handle Ctrl+C gracefully
  process.on("SIGINT", () => {
    clearInterval(interval);
    console.log("\n⏹️ Simulation stopped by user.");
    console.log(`📊 Sent ${dataPointCount} data points before stopping.`);
    process.exit(0);
  });
}

function generateSensorData(severity, timestamp) {
  let baseHeartRate, hrvRange, stressLevel, movementLevel;

  switch (severity) {
    case "mild":
      baseHeartRate = 85 + Math.random() * 15; // 85-100 BPM
      hrvRange = [25, 35]; // Lower HRV indicates stress
      stressLevel = 0.6 + Math.random() * 0.1; // 0.6-0.7
      movementLevel = 0.3 + Math.random() * 0.2; // Some movement
      break;

    case "moderate":
      baseHeartRate = 100 + Math.random() * 20; // 100-120 BPM
      hrvRange = [15, 25]; // Lower HRV
      stressLevel = 0.7 + Math.random() * 0.1; // 0.7-0.8
      movementLevel = 0.5 + Math.random() * 0.3; // More movement/restlessness
      break;

    case "severe":
      baseHeartRate = 120 + Math.random() * 25; // 120-145 BPM
      hrvRange = [10, 20]; // Very low HRV
      stressLevel = 0.85 + Math.random() * 0.1; // 0.85-0.95
      movementLevel = 0.7 + Math.random() * 0.3; // High movement/agitation
      break;

    default:
      // Normal baseline
      baseHeartRate = 70 + Math.random() * 10; // 70-80 BPM
      hrvRange = [40, 60]; // Normal HRV
      stressLevel = 0.2 + Math.random() * 0.2; // 0.2-0.4
      movementLevel = 0.1 + Math.random() * 0.2; // Minimal movement
  }

  // Add some natural variation to make it realistic
  const heartRate = Math.round(baseHeartRate + (Math.random() - 0.5) * 10);
  const hrv = Math.round(
    hrvRange[0] + Math.random() * (hrvRange[1] - hrvRange[0])
  );
  const stress =
    Math.round((stressLevel + (Math.random() - 0.5) * 0.1) * 100) / 100;
  const movement =
    Math.round((movementLevel + (Math.random() - 0.5) * 0.1) * 100) / 100;

  return {
    heartRate: heartRate,
    hrv: hrv,
    stressLevel: stress,
    movementIntensity: movement,
    timestamp: timestamp,
    temperature: 36.5 + Math.random() * 1, // Body temperature variation
    bloodOxygen: 96 + Math.random() * 3, // SpO2 levels
    respiratoryRate:
      severity === "severe"
        ? 20 + Math.random() * 8
        : severity === "moderate"
        ? 16 + Math.random() * 6
        : 12 + Math.random() * 4,
    lastUpdated: timestamp,
  };
}

// Command line interface
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log("🚨 Anxiety Condition Simulator");
  console.log("==============================");
  console.log("Usage: node test_anxiety_alerts.js <severity> [duration]");
  console.log("");
  console.log("Severity options:");
  console.log(
    "  mild     - Simulate mild anxiety (HR: 85-100, stress: 0.6-0.7)"
  );
  console.log(
    "  moderate - Simulate moderate anxiety (HR: 100-120, stress: 0.7-0.8)"
  );
  console.log(
    "  severe   - Simulate severe anxiety (HR: 120-145, stress: 0.85-0.95)"
  );
  console.log("");
  console.log("Duration: Optional duration in seconds (default: 30)");
  console.log("");
  console.log("Examples:");
  console.log("  node test_anxiety_alerts.js mild");
  console.log("  node test_anxiety_alerts.js moderate 45");
  console.log("  node test_anxiety_alerts.js severe 60");
  console.log("");
  console.log("This will continuously feed sensor data to Firebase to trigger");
  console.log("real-time anxiety detection and generate actual notifications.");
  process.exit(0);
}

const severity = args[0].toLowerCase();
const duration = args[1] ? parseInt(args[1]) : 30;

if (!["mild", "moderate", "severe"].includes(severity)) {
  console.error("❌ Invalid severity. Use: mild, moderate, or severe");
  process.exit(1);
}

if (duration < 10 || duration > 300) {
  console.error("❌ Duration must be between 10 and 300 seconds");
  process.exit(1);
}

// Start the simulation
simulateAnxietyCondition(severity, duration);
