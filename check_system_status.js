const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function checkSystemStatus() {
  console.log("🔍 SYSTEM DIAGNOSTIC CHECK");
  console.log("═══════════════════════════");
  
  try {
    // Check device assignment
    console.log("📱 Checking device assignment...");
    const assignmentRef = db.ref("/devices/AnxieEase001/assignment");
    const assignmentSnapshot = await assignmentRef.once("value");
    
    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      console.log("✅ Device assignment found:");
      console.log(`   👤 User: ${assignment.assignedUser}`);
      console.log(`   📋 Session: ${assignment.activeSessionId}`);
      console.log(`   ⏰ Assigned: ${assignment.assignedAt}`);
      
      const userId = assignment.assignedUser;
      
      // Check user baseline
      console.log("\n📊 Checking user baseline...");
      const baselineRef = db.ref(`/users/${userId}/deviceProfiles/AnxieEase001/baseline`);
      const baselineSnapshot = await baselineRef.once("value");
      
      if (baselineSnapshot.exists()) {
        const baseline = baselineSnapshot.val();
        console.log("✅ User baseline found:");
        console.log(`   💓 Baseline HR: ${baseline.baselineHR} BPM`);
        console.log(`   📅 Created: ${baseline.createdAt}`);
        console.log(`   📈 Sample count: ${baseline.sampleCount}`);
      } else {
        console.log("❌ User baseline NOT found!");
        console.log("   This explains why notifications aren't working");
        console.log("   The function requires a baseline to calculate severity");
      }
      
      // Check recent device data
      console.log("\n📡 Checking recent device data...");
      const currentRef = db.ref("/devices/AnxieEase001/current");
      const currentSnapshot = await currentRef.once("value");
      
      if (currentSnapshot.exists()) {
        const current = currentSnapshot.val();
        console.log("✅ Current device data:");
        console.log(`   💓 Heart Rate: ${current.heartRate} BPM`);
        console.log(`   🕐 Timestamp: ${current.timestamp}`);
        console.log(`   🔋 Battery: ${current.battPerc}%`);
      } else {
        console.log("❌ No current device data found");
      }
      
    } else {
      console.log("❌ Device assignment NOT found!");
      console.log("   Device AnxieEase001 is not assigned to any user");
      console.log("   This explains why notifications aren't working");
    }
    
  } catch (error) {
    console.error("❌ Error checking system status:", error);
  }
  
  console.log("\n🎯 SUMMARY");
  console.log("══════════");
  console.log("For notifications to work, you need:");
  console.log("1. ✅ Device assignment (user + session)");
  console.log("2. ✅ User baseline heart rate");
  console.log("3. ✅ Recent heart rate data");
  console.log("4. ✅ Firebase function execution");
  
  process.exit(0);
}

checkSystemStatus().catch(console.error);