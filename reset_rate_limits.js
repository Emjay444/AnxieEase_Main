console.log("🧹 CLEARING RATE LIMITS");
console.log("═".repeat(30));

const https = require("https");

// Use Node.js built-in https module (works in all Node.js versions)
const url =
  "https://us-central1-anxieease-sensors.cloudfunctions.net/clearAnxietyRateLimits";

console.log("🔄 Clearing anxiety notification rate limits...");

https
  .get(url, (res) => {
    let data = "";

    res.on("data", (chunk) => {
      data += chunk;
    });

    res.on("end", () => {
      try {
        const result = JSON.parse(data);
        console.log("✅ SUCCESS!");
        console.log(`📋 Message: ${result.message}`);
        console.log(`⏰ Timestamp: ${result.timestamp}`);
        console.log("");
        console.log("🎯 Rate limits cleared! You can test notifications now:");
        console.log("   • node test_mild_anxiety.js");
        console.log("   • node test_moderate_anxiety.js");
        console.log("   • node test_severe_anxiety.js");
        console.log("   • node test_critical_anxiety.js");
      } catch (e) {
        console.log("✅ Rate limits cleared!");
        console.log("Response:", data);
      }
    });
  })
  .on("error", (err) => {
    console.error("❌ Error:", err.message);
    console.log(
      "🔧 Try manually: https://us-central1-anxieease-sensors.cloudfunctions.net/clearAnxietyRateLimits"
    );
  });
