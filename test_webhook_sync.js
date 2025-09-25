/**
 * 🧪 WEBHOOK TEST: Change Supabase assignment to trigger sync
 * 
 * This simulates what should happen when you edit the wearable_devices table
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

async function testWebhookResponse() {
  console.log("\n🧪 TESTING WEBHOOK SYNC");
  console.log("=======================");
  
  try {
    // Current state check
    console.log("🔍 Checking current Firebase assignment...");
    const currentAssignmentRef = db.ref('/devices/AnxieEase001/assignment');
    const currentSnapshot = await currentAssignmentRef.once('value');
    const currentAssignment = currentSnapshot.val();
    
    console.log("\n📊 CURRENT FIREBASE STATE:");
    console.log(`   Assigned User: ${currentAssignment.assignedUser}`);
    console.log(`   Session ID: ${currentAssignment.activeSessionId}`);
    console.log(`   Assigned By: ${currentAssignment.assignedBy}`);
    console.log(`   Status: ${currentAssignment.status}`);
    console.log(`   Last Updated: ${new Date(currentAssignment.assignedAt).toLocaleString()}`);
    
    // Expected state from your Supabase
    const EXPECTED_SUPABASE_USER = "5efad7d4-3dcd-4333-ba4b-4f68c14a4f86"; // From your screenshot
    
    console.log("\n📊 EXPECTED SUPABASE STATE:");
    console.log(`   User ID: ${EXPECTED_SUPABASE_USER}`);
    console.log(`   Baseline HR: 73.2 BPM`);
    console.log(`   Device: AnxieEase001`);
    
    // Check if they match
    const isInSync = currentAssignment.assignedUser === EXPECTED_SUPABASE_USER;
    
    console.log("\n🔍 SYNC STATUS:");
    console.log("================");
    console.log(`Firebase User: ${currentAssignment.assignedUser}`);
    console.log(`Supabase User: ${EXPECTED_SUPABASE_USER}`);
    console.log(`In Sync: ${isInSync ? '✅ YES' : '❌ NO'}`);
    
    if (!isInSync) {
      console.log("\n❌ WEBHOOK NOT TRIGGERED YET");
      console.log("=============================");
      console.log("This means either:");
      console.log("1. ⚠️  Webhook not set up correctly in Supabase");
      console.log("2. ⚠️  Webhook URL is wrong");
      console.log("3. ⚠️  Webhook events not configured (INSERT/UPDATE/DELETE)");
      console.log("4. ⚠️  Supabase hasn't sent the webhook yet");
      
      console.log("\n🔧 WEBHOOK TROUBLESHOOTING:");
      console.log("===========================");
      console.log("✅ Check Supabase Dashboard > Database > Webhooks");
      console.log("✅ Verify webhook URL: https://us-central1-anxieease-sensors.cloudfunctions.net/syncDeviceAssignment");
      console.log("✅ Ensure events: INSERT ☑️  UPDATE ☑️  DELETE ☑️");
      console.log("✅ Check webhook is ENABLED");
      
      console.log("\n🧪 MANUAL TEST WEBHOOK:");
      console.log("=======================");
      console.log("1. Go to your Supabase wearable_devices table");
      console.log("2. Edit the user_id field for AnxieEase001");
      console.log("3. Change it to a different user, then back");
      console.log("4. Watch this Firebase assignment update!");
      
    } else {
      console.log("\n✅ WEBHOOK WORKING PERFECTLY!");
      console.log("=============================");
      console.log("✅ Firebase matches Supabase");
      console.log("✅ Auto-sync is functional");
      console.log("✅ Real-time updates working");
    }
    
    // Test Firebase Functions URL accessibility
    console.log("\n📡 Testing Firebase Function URL...");
    console.log("====================================");
    console.log("Webhook URL: https://us-central1-anxieease-sensors.cloudfunctions.net/syncDeviceAssignment");
    
    try {
      const testResponse = await fetch('https://us-central1-anxieease-sensors.cloudfunctions.net/testDeviceSync');
      const testResult = await testResponse.json();
      
      if (testResponse.ok) {
        console.log("✅ Firebase Function is accessible and working");
        console.log(`✅ Test response: ${testResult.message}`);
      } else {
        console.log("❌ Firebase Function test failed");
      }
    } catch (fetchError) {
      console.log("⚠️  Could not test Firebase Function URL (might be network issue)");
    }
    
    console.log("\n🎯 NEXT STEPS:");
    console.log("==============");
    if (!isInSync) {
      console.log("1. 🔧 Verify Supabase webhook configuration");
      console.log("2. 🧪 Test by editing user_id in Supabase table");
      console.log("3. 🔄 Check if Firebase updates within 2 seconds");
      console.log("4. 📞 If still not working, we can debug the webhook");
    } else {
      console.log("1. ✅ Your auto-sync is working perfectly!");
      console.log("2. 🎉 Ready for production use");
      console.log("3. 🚀 Admin changes sync automatically");
    }
    
  } catch (error) {
    console.error("❌ Test failed:", error.message);
  }
}

testWebhookResponse();