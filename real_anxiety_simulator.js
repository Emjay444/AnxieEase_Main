const https = require("https");
const http = require("http");

// Function to send HTTP request to trigger notification
function sendNotificationRequest(severity, heartRate) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      severity: severity,
      heartRate: heartRate,
    });

    const options = {
      hostname: "us-central1-anxieease.cloudfunctions.net",
      port: 443,
      path: "/testNotificationHTTP",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        try {
          const response = JSON.parse(data);
          resolve(response);
        } catch (e) {
          resolve({ success: true, rawResponse: data });
        }
      });
    });

    req.on("error", (e) => {
      reject(e);
    });

    req.write(postData);
    req.end();
  });
}

// Simulate anxiety episode progression
async function simulateAnxietyEpisode() {
  console.log("🚨 Simulating Real Anxiety Episode Progression");
  console.log("==============================================");
  console.log(
    "This will simulate a realistic anxiety episode that escalates over time."
  );
  console.log(
    "You will receive REAL notifications as the condition progresses.\n"
  );

  try {
    // Phase 1: Initial mild anxiety (like feeling nervous)
    console.log("📊 Phase 1: MILD anxiety onset...");
    console.log("💗 Heart rate: 85 BPM (feeling anxious)");
    await sendNotificationRequest("mild", 85);
    console.log("✅ Mild anxiety alert sent!\n");

    // Wait 10 seconds
    console.log("⏳ Waiting 10 seconds... (anxiety building)");
    await new Promise((resolve) => setTimeout(resolve, 10000));

    // Phase 2: Escalating to moderate anxiety
    console.log("📊 Phase 2: MODERATE anxiety escalation...");
    console.log("💗 Heart rate: 105 BPM (anxiety increasing)");
    await sendNotificationRequest("moderate", 105);
    console.log("✅ Moderate anxiety alert sent!\n");

    // Wait 10 seconds
    console.log("⏳ Waiting 10 seconds... (condition worsening)");
    await new Promise((resolve) => setTimeout(resolve, 10000));

    // Phase 3: Peak severe anxiety (panic-like state)
    console.log("📊 Phase 3: SEVERE anxiety peak...");
    console.log("💗 Heart rate: 130 BPM (high anxiety/panic)");
    await sendNotificationRequest("severe", 130);
    console.log("✅ Severe anxiety alert sent!\n");

    // Wait 8 seconds
    console.log("⏳ Waiting 8 seconds... (peak anxiety)");
    await new Promise((resolve) => setTimeout(resolve, 8000));

    // Phase 4: Another severe spike
    console.log("📊 Phase 4: SEVERE anxiety continuation...");
    console.log("💗 Heart rate: 125 BPM (sustained high anxiety)");
    await sendNotificationRequest("severe", 125);
    console.log("✅ Second severe anxiety alert sent!\n");

    console.log("🎉 Anxiety episode simulation completed!");
    console.log(
      "📱 Check your device - you should have received 4 notifications:"
    );
    console.log("   1️⃣ Mild Alert - 85 BPM");
    console.log("   2️⃣ Moderate Alert - 105 BPM");
    console.log("   3️⃣ Severe Alert - 130 BPM");
    console.log("   4️⃣ Severe Alert - 125 BPM");
    console.log(
      "\n🔔 These are REAL notifications that users would receive during actual anxiety episodes."
    );
  } catch (error) {
    console.error("❌ Error during simulation:", error);
  }
}

// Single notification test
async function sendSingleAlert(severity, heartRate) {
  console.log(`🚨 Sending REAL ${severity.toUpperCase()} anxiety alert...`);
  console.log(`💗 Heart rate: ${heartRate} BPM`);

  try {
    const response = await sendNotificationRequest(severity, heartRate);
    console.log("✅ Alert sent successfully!");
    console.log("📱 Check your device for the notification.");
    console.log("Response:", response);
  } catch (error) {
    console.error("❌ Error sending alert:", error);
  }
}

// Command line interface
const args = process.argv.slice(2);

if (args.length === 0) {
  console.log("🚨 Real Anxiety Alert Simulator");
  console.log("================================");
  console.log("Usage options:");
  console.log("");
  console.log("1. Simulate full anxiety episode:");
  console.log("   node real_anxiety_simulator.js episode");
  console.log("   (Sends mild → moderate → severe → severe over 40 seconds)");
  console.log("");
  console.log("2. Send single alert:");
  console.log("   node real_anxiety_simulator.js <severity> [heartRate]");
  console.log("   Example: node real_anxiety_simulator.js severe 125");
  console.log("");
  console.log("Severity options: mild, moderate, severe");
  console.log("Heart rate: Optional (default varies by severity)");
  console.log("");
  console.log(
    "🔔 All notifications sent are REAL - exactly what users receive!"
  );
  process.exit(0);
}

const command = args[0].toLowerCase();

if (command === "episode") {
  simulateAnxietyEpisode();
} else if (["mild", "moderate", "severe"].includes(command)) {
  const severity = command;
  const heartRate = args[1]
    ? parseInt(args[1])
    : severity === "mild"
    ? 85
    : severity === "moderate"
    ? 105
    : 125;

  sendSingleAlert(severity, heartRate);
} else {
  console.error(
    '❌ Invalid command. Use "episode" or a severity level (mild/moderate/severe)'
  );
  process.exit(1);
}
