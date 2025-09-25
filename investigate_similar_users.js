/**
 * 🔍 USER ID INVESTIGATION - Similar IDs, Different Baselines
 * 
 * Analyzing why there are two similar user IDs with different baseline data:
 * - 5afad7d4-3dcd-4353-badb-4f155303419a (73.2 BPM)
 * - 5efad7d4-3dcd-4333-ba4b-41f86         (unknown baseline)
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

async function investigateSimilarUserIDs() {
  console.log("\n🔍 USER ID INVESTIGATION");
  console.log("========================");
  console.log("Analyzing similar user IDs with different data");
  
  try {
    const SIMILAR_USERS = [
      "5afad7d4-3dcd-4353-badb-4f155303419a", // Currently assigned, has baseline 73.2
      "5efad7d4-3dcd-4333-ba4b-41f86",         // Different ID, different data
      "e0997cb7-684f-41e5-929f-4480788d4ad0"   // Another test user
    ];
    
    console.log("🔍 Analyzing each user ID...\n");
    
    for (const userId of SIMILAR_USERS) {
      console.log(`👤 USER: ${userId}`);
      console.log("=" + "=".repeat(userId.length + 7));
      
      const userRef = db.ref(`/users/${userId}`);
      const userSnapshot = await userRef.once('value');
      
      if (userSnapshot.exists()) {
        const userData = userSnapshot.val();
        
        // Baseline analysis
        if (userData.baseline) {
          console.log(`📊 BASELINE:`);
          console.log(`   Heart Rate: ${userData.baseline.heartRate} BPM`);
          console.log(`   Source: ${userData.baseline.source || 'Unknown'}`);
          console.log(`   Device ID: ${userData.baseline.deviceId || 'Not specified'}`);
          console.log(`   Timestamp: ${new Date(userData.baseline.timestamp).toLocaleString()}`);
        } else {
          console.log(`📊 BASELINE: None found`);
        }
        
        // FCM Token
        if (userData.fcmToken) {
          console.log(`📱 FCM TOKEN: ${userData.fcmToken.substring(0, 20)}...`);
        } else {
          console.log(`📱 FCM TOKEN: None`);
        }
        
        // Alerts
        if (userData.alerts) {
          const alertCount = Object.keys(userData.alerts).length;
          console.log(`🚨 ALERTS: ${alertCount} alerts`);
          
          // Show latest alert timestamp
          const alertTimestamps = Object.keys(userData.alerts).map(key => 
            userData.alerts[key].timestamp || 0
          );
          const latestAlert = Math.max(...alertTimestamps);
          if (latestAlert > 0) {
            console.log(`   Latest: ${new Date(latestAlert).toLocaleString()}`);
          }
        } else {
          console.log(`🚨 ALERTS: None`);
        }
        
        // Sessions
        if (userData.sessions) {
          const sessionCount = Object.keys(userData.sessions).length;
          console.log(`📝 SESSIONS: ${sessionCount} sessions`);
          
          // Show active sessions
          let activeSessions = 0;
          for (const [sessionId, session] of Object.entries(userData.sessions)) {
            if (session.metadata && session.metadata.status === 'active') {
              activeSessions++;
            }
          }
          console.log(`   Active: ${activeSessions}`);
        } else {
          console.log(`📝 SESSIONS: None`);
        }
        
      } else {
        console.log(`❌ User data not found`);
      }
      
      console.log(); // Empty line for readability
    }
    
    // Check current device assignment
    console.log("🔐 CURRENT DEVICE ASSIGNMENT:");
    console.log("=============================");
    
    const assignmentRef = db.ref('/devices/AnxieEase001/assignment');
    const assignmentSnapshot = await assignmentRef.once('value');
    
    if (assignmentSnapshot.exists()) {
      const assignment = assignmentSnapshot.val();
      console.log(`📱 Device: AnxieEase001`);
      console.log(`👤 Assigned to: ${assignment.assignedUser}`);
      console.log(`📅 Assigned: ${new Date(assignment.assignedAt).toLocaleString()}`);
      console.log(`🔧 Assigned by: ${assignment.assignedBy}`);
      console.log(`⚡ Status: ${assignment.status}`);
    }
    
    // Analysis
    console.log("\n🎯 ANALYSIS:");
    console.log("=============");
    
    const user1 = "5afad7d4-3dcd-4353-badb-4f155303419a";
    const user2 = "5efad7d4-3dcd-4333-ba4b-41f86";
    
    console.log("🔍 Comparing similar user IDs:");
    console.log(`User 1: ${user1}`);
    console.log(`User 2: ${user2}`);
    console.log();
    
    // Character-by-character comparison
    console.log("📝 Character differences:");
    for (let i = 0; i < Math.max(user1.length, user2.length); i++) {
      const char1 = user1[i] || ' ';
      const char2 = user2[i] || ' ';
      
      if (char1 !== char2) {
        console.log(`   Position ${i}: '${char1}' vs '${char2}' ← DIFFERENT`);
      }
    }
    
    console.log("\n💡 POSSIBLE EXPLANATIONS:");
    console.log("=========================");
    console.log("1. 🔄 Different app sessions/logins created different UUIDs");
    console.log("2. 🧪 Testing with different accounts/profiles");
    console.log("3. 📱 Different device installations");
    console.log("4. 🔑 User recreated account or reset profile");
    console.log("5. 🐛 UUID generation quirk (similar but not identical)");
    
    console.log("\n🎯 RECOMMENDATION:");
    console.log("==================");
    console.log("✅ Keep the user that:");
    console.log("   • Is currently assigned to device");
    console.log("   • Has recent activity/alerts");
    console.log("   • Has proper baseline data");
    console.log("   • Has active FCM token");
    
    console.log("\n❌ Consider removing the user that:");
    console.log("   • Has no recent activity");
    console.log("   • Has incomplete data");
    console.log("   • Is not assigned to any device");
    
    console.log("\n🔄 NEXT STEPS:");
    console.log("==============");
    console.log("1. Identify which user is the 'real' active user");
    console.log("2. Merge important data if needed");
    console.log("3. Remove duplicate/inactive user");
    console.log("4. Ensure device assignment points to correct user");
    
  } catch (error) {
    console.error("❌ Investigation failed:", error.message);
  }
}

investigateSimilarUserIDs();