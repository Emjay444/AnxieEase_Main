const https = require("https");

async function testFCMWellnessReminders() {
  console.log("🧘 TESTING NEW FCM-BASED WELLNESS REMINDERS");
  console.log("");
  console.log("🎯 This new system works EXACTLY like anxiety alerts:");
  console.log("✅ Server-side scheduling (Cloud Functions)");
  console.log("✅ FCM delivery (works when app closed)");
  console.log("✅ No dependency on local app scheduling");
  console.log("");
  console.log("📱 CLOSE YOUR APP COMPLETELY!");
  console.log("⏳ Waiting 10 seconds for you to close the app...");

  await new Promise((resolve) => setTimeout(resolve, 10000));

  try {
    // Test 1: Morning wellness reminder
    console.log("🌅 TEST 1: Morning Wellness Reminder");
    await testWellnessCategory("morning");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Test 2: Afternoon wellness reminder
    console.log("\n🌞 TEST 2: Afternoon Wellness Reminder");
    await testWellnessCategory("afternoon");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Test 3: Evening wellness reminder
    console.log("\n🌙 TEST 3: Evening Wellness Reminder");
    await testWellnessCategory("evening");

    console.log("\n🎯 === TEST RESULTS ===");
    console.log("📱 You should have received 3 wellness reminders:");
    console.log("   1. 🌅 Morning wellness message");
    console.log("   2. 🌞 Afternoon wellness message");
    console.log("   3. 🌙 Evening wellness message");
    console.log("");
    console.log(
      "✅ If you received all 3: FCM wellness reminders work when app closed!"
    );
    console.log("❌ If you received none: Check device notification settings");
    console.log(
      "⚠️ If you received some: Check wellness_reminders topic subscription"
    );
    console.log("");
    console.log("🔄 SCHEDULED TIMES:");
    console.log("   • 9:00 AM - Morning wellness boost");
    console.log("   • 5:00 PM - Afternoon reset");
    console.log("   • 11:00 PM - Evening reflection");
    console.log("");
    console.log("💡 These reminders are now SERVER-BASED like anxiety alerts!");
    console.log("   They will work reliably when your app is closed.");
  } catch (error) {
    console.error("❌ Test failed:", error);
  }

  process.exit(0);
}

function testWellnessCategory(timeCategory) {
  return new Promise((resolve, reject) => {
    console.log(`   📡 Sending ${timeCategory} wellness reminder...`);

    const postData = JSON.stringify({
      data: { timeCategory: timeCategory },
    });

    const options = {
      hostname: "us-central1-anxieease-sensors.cloudfunctions.net",
      port: 443,
      path: "/sendManualWellnessReminder",
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          const result = JSON.parse(data);
          if (result.result && result.result.success) {
            console.log(`   ✅ ${timeCategory} reminder sent successfully!`);
            console.log(`   📱 Title: "${result.result.message.title}"`);
            console.log(`   💬 Body: "${result.result.message.body}"`);
            console.log(`   🎯 Type: ${result.result.message.type}`);
            console.log(`   📱 Check your device for notification!`);
          } else {
            console.log(`   ⚠️ ${timeCategory} reminder result:`, result);
          }
          resolve(result);
        } catch (error) {
          console.log(`   📱 ${timeCategory} response:`, data);
          resolve(data);
        }
      });
    });

    req.on("error", (error) => {
      console.error(
        `   ❌ Error sending ${timeCategory} reminder:`,
        error.message
      );
      reject(error);
    });

    req.write(postData);
    req.end();
  });
}

testFCMWellnessReminders();
