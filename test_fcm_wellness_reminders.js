const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL:
    "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

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
    // Test 1: Manual morning wellness reminder
    console.log("🌅 TEST 1: Morning Wellness Reminder");

    const morningTest = await admin.firestore().doc("test").set({}); // This will trigger our function

    // Call the manual wellness reminder function
    const morningResponse = await callCloudFunction(
      "sendManualWellnessReminder",
      {
        timeCategory: "morning",
      }
    );

    console.log("✅ Morning reminder result:", morningResponse.data);
    console.log("📱 Check your device for morning wellness reminder!");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Test 2: Afternoon wellness reminder
    console.log("\n🌞 TEST 2: Afternoon Wellness Reminder");

    const afternoonResponse = await callCloudFunction(
      "sendManualWellnessReminder",
      {
        timeCategory: "afternoon",
      }
    );

    console.log("✅ Afternoon reminder result:", afternoonResponse.data);
    console.log("📱 Check your device for afternoon wellness reminder!");

    await new Promise((resolve) => setTimeout(resolve, 5000));

    // Test 3: Evening wellness reminder
    console.log("\n🌙 TEST 3: Evening Wellness Reminder");

    const eveningResponse = await callCloudFunction(
      "sendManualWellnessReminder",
      {
        timeCategory: "evening",
      }
    );

    console.log("✅ Evening reminder result:", eveningResponse.data);
    console.log("📱 Check your device for evening wellness reminder!");

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

// Helper function to call Cloud Functions
async function callCloudFunction(functionName, data) {
  try {
    const functions = admin.functions();
    const callable = functions.httpsCallable(functionName);
    return await callable(data);
  } catch (error) {
    console.error(`Error calling ${functionName}:`, error);
    throw error;
  }
}

testFCMWellnessReminders();
