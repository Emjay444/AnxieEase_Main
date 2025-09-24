/**
 * 🚨 URGENT: FCM TOKEN LEAK INVESTIGATION
 * 
 * This investigates why User B received notifications meant for User A
 * Possible causes:
 * 1. Same FCM token being used for both users
 * 2. FCM token not properly isolated by user account
 * 3. Notification system not checking user assignment
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

const USER_A_ID = "5efad7d4-3dcd-4333-ba4b-41f86";  // Assigned to device
const USER_B_ID = "test-user-b-not-assigned";       // NOT assigned

async function investigateFCMTokenLeak() {
  console.log("\n🚨 URGENT: FCM TOKEN LEAK INVESTIGATION");
  console.log("=======================================");
  
  try {
    // Step 1: Check FCM tokens for both users
    console.log("\n🔍 Step 1: Checking FCM tokens...");
    
    const userA_tokenSnapshot = await db.ref(`/users/${USER_A_ID}/fcmToken`).once('value');
    const userA_token = userA_tokenSnapshot.val();
    
    const userB_tokenSnapshot = await db.ref(`/users/${USER_B_ID}/fcmToken`).once('value');
    const userB_token = userB_tokenSnapshot.val();
    
    console.log("User A FCM Token:");
    console.log(userA_token ? `  ${userA_token.substring(0, 30)}...` : "  No token found");
    
    console.log("User B FCM Token:");
    console.log(userB_token ? `  ${userB_token.substring(0, 30)}...` : "  No token found");
    
    // Check if tokens are the same
    if (userA_token && userB_token && userA_token === userB_token) {
      console.log("🚨 CRITICAL ISSUE: Both users have THE SAME FCM TOKEN!");
      console.log("   This explains why User B received User A's notifications");
      console.log("   Solution: Each user must have their own unique FCM token");
    } else if (userA_token && userB_token) {
      console.log("✅ Users have different FCM tokens - investigating further...");
    }
    
    // Step 2: Check device assignment
    console.log("\n📟 Step 2: Checking device assignment...");
    const assignmentSnapshot = await db.ref('/devices/AnxieEase001/assignment').once('value');
    const assignment = assignmentSnapshot.val();
    
    if (assignment) {
      console.log(`Device assigned to: ${assignment.assignedUser}`);
      console.log(`Should only notify: ${assignment.assignedUser}`);
      
      if (assignment.assignedUser === USER_A_ID) {
        console.log("✅ Assignment is correct - User A should get notifications");
      } else {
        console.log("❌ Assignment problem - wrong user assigned");
      }
    }
    
    // Step 3: Check recent alerts and who they targeted
    console.log("\n🔔 Step 3: Checking recent alerts for both users...");
    
    const userA_alertsSnapshot = await db.ref(`/users/${USER_A_ID}/alerts`).once('value');
    const userA_alerts = userA_alertsSnapshot.val();
    
    const userB_alertsSnapshot = await db.ref(`/users/${USER_B_ID}/alerts`).once('value');
    const userB_alerts = userB_alertsSnapshot.val();
    
    if (userA_alerts) {
      const alertCount = Object.keys(userA_alerts).length;
      console.log(`User A alerts in Firebase: ${alertCount}`);
    } else {
      console.log("User A alerts in Firebase: 0");
    }
    
    if (userB_alerts) {
      const alertCount = Object.keys(userB_alerts).length;
      console.log(`User B alerts in Firebase: ${alertCount}`);
    } else {
      console.log("User B alerts in Firebase: 0");
    }
    
    // Step 4: Check the anxiety detection function logs for notification targets
    console.log("\n📊 Step 4: The issue is likely one of these:");
    console.log("1. SAME FCM TOKEN: Both users using the same device/token");
    console.log("2. TOKEN SHARING: App not properly isolating FCM tokens by user");
    console.log("3. FLUTTER APP ISSUE: App showing notifications for wrong user");
    
    console.log("\n🔧 IMMEDIATE FIXES NEEDED:");
    console.log("1. Each user must have their own unique FCM token");
    console.log("2. Flutter app must register separate tokens per user account");
    console.log("3. Verify user login isolation in the app");
    
    // Step 5: Test with different FCM tokens
    console.log("\n🧪 Step 5: To fix this, we need to:");
    console.log("1. Get User B's real FCM token from their device");
    console.log("2. Update User B with their own unique token");
    console.log("3. Re-run the multi-user test");
    
    console.log("\n❓ QUESTIONS FOR YOU:");
    console.log("1. Are you using the same phone for both user accounts?");
    console.log("2. Did you switch user accounts in the same app instance?");
    console.log("3. Or are you using two different phones/devices?");
    
    // Check if we're using the same FCM token for both users
    if (userA_token && userB_token && userA_token === userB_token) {
      console.log("\n🚨 ROOT CAUSE FOUND:");
      console.log("Both users have the same FCM token, so notifications go to the same device!");
      console.log("This is why User B received User A's notifications.");
      
      console.log("\n✅ SOLUTION:");
      console.log("1. Use different devices for different users, OR");
      console.log("2. Implement proper FCM token isolation per user account, OR");
      console.log("3. Test with completely separate devices");
    }
    
  } catch (error) {
    console.error("❌ Investigation failed:", error.message);
  }
}

investigateFCMTokenLeak();