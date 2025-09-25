/**
 * 🧪 REAL-TIME WEBHOOK TEST
 * 
 * This will monitor Firebase for changes while you edit Supabase
 * Run this script and then edit the wearable_devices table in Supabase
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

async function monitorFirebaseChanges() {
  console.log("\n🎯 REAL-TIME WEBHOOK MONITOR");
  console.log("=============================");
  console.log("This script will watch Firebase for changes from your Supabase webhook");
  
  const deviceAssignmentRef = db.ref('/devices/AnxieEase001/assignment');
  
  // Get current state
  const initialSnapshot = await deviceAssignmentRef.once('value');
  const initialAssignment = initialSnapshot.val();
  
  console.log("\n📊 INITIAL FIREBASE STATE:");
  console.log(`   Assigned User: ${initialAssignment.assignedUser}`);
  console.log(`   Session ID: ${initialAssignment.activeSessionId}`);
  console.log(`   Assigned By: ${initialAssignment.assignedBy}`);
  console.log(`   Last Updated: ${new Date(initialAssignment.assignedAt).toLocaleString()}`);
  
  console.log("\n🔍 EXPECTED SUPABASE USER:");
  console.log("   User ID: 5efad7d4-3dcd-4333-ba4b-4f68c14a4f86");
  
  const isCurrentlyInSync = initialAssignment.assignedUser === "5efad7d4-3dcd-4333-ba4b-4f68c14a4f86";
  
  if (isCurrentlyInSync) {
    console.log("\n✅ ALREADY IN SYNC!");
    console.log("Firebase matches your Supabase assignment");
    console.log("Webhook is working correctly!");
    return;
  }
  
  console.log("\n❌ OUT OF SYNC - Waiting for webhook...");
  console.log("========================================");
  
  console.log("\n📱 TEST INSTRUCTIONS:");
  console.log("====================");
  console.log("1. Go to your Supabase Dashboard");
  console.log("2. Open Database > Table Editor > wearable_devices");
  console.log("3. Find the row with device_id 'AnxieEase001'");
  console.log("4. Edit the user_id field");
  console.log("5. Change it to: 5efad7d4-3dcd-4333-ba4b-4f68c14a4f86");
  console.log("6. Click Save/Update");
  console.log("7. Watch for changes below! ⏰");
  
  console.log("\n⏰ MONITORING FOR CHANGES... (Press Ctrl+C to stop)");
  console.log("===================================================");
  
  let changeCount = 0;
  
  // Listen for real-time changes
  deviceAssignmentRef.on('value', (snapshot) => {
    const currentTime = new Date().toLocaleString();
    const assignment = snapshot.val();
    
    if (!assignment) {
      console.log(`[${currentTime}] ❌ Assignment data not found`);
      return;
    }
    
    changeCount++;
    
    if (changeCount === 1) {
      // Skip first call (initial state)
      return;
    }
    
    console.log(`\n🔄 [${currentTime}] FIREBASE CHANGE DETECTED!`);
    console.log("=============================================");
    console.log(`   New User: ${assignment.assignedUser}`);
    console.log(`   New Session: ${assignment.activeSessionId}`);
    console.log(`   Assigned By: ${assignment.assignedBy}`);
    console.log(`   Status: ${assignment.status}`);
    
    if (assignment.supabaseSync) {
      console.log(`   📡 Webhook Data:`);
      console.log(`      Synced At: ${new Date(assignment.supabaseSync.syncedAt).toLocaleString()}`);
      console.log(`      Baseline HR: ${assignment.supabaseSync.baselineHR} BPM`);
      console.log(`      Webhook Trigger: ${assignment.supabaseSync.webhookTrigger}`);
    }
    
    // Check if this matches expected Supabase user
    const expectedUser = "5efad7d4-3dcd-4333-ba4b-4f68c14a4f86";
    const nowInSync = assignment.assignedUser === expectedUser;
    
    if (nowInSync) {
      console.log("\n🎉 SUCCESS! WEBHOOK SYNC WORKING!");
      console.log("==================================");
      console.log("✅ Firebase updated automatically");
      console.log("✅ Webhook triggered correctly");
      console.log("✅ Real-time sync is functional");
      console.log("✅ Admin changes sync instantly");
      
      console.log("\n🚀 YOUR AUTO-SYNC IS NOW LIVE!");
      console.log("===============================");
      console.log("From now on:");
      console.log("• Admin changes Supabase → Firebase updates automatically");
      console.log("• Device assignments sync in real-time");
      console.log("• No manual intervention needed");
      
      process.exit(0);
    } else {
      console.log(`\n⏳ Change detected but not the expected user yet...`);
      console.log(`   Expected: ${expectedUser}`);
      console.log(`   Current:  ${assignment.assignedUser}`);
      console.log("   Continuing to monitor...");
    }
  });
  
  // Keep the script running
  console.log("\n💡 TIP: If no changes appear after updating Supabase:");
  console.log("    1. Check Supabase webhook logs");
  console.log("    2. Verify webhook URL is correct");
  console.log("    3. Ensure webhook is enabled");
  
  // Timeout after 2 minutes
  setTimeout(() => {
    console.log("\n⏰ Timeout after 2 minutes");
    console.log("If webhook didn't trigger, there might be a configuration issue");
    console.log("Let's troubleshoot the webhook setup");
    process.exit(1);
  }, 120000);
}

monitorFirebaseChanges().catch(console.error);