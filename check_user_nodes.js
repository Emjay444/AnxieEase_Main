const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (admin.apps.length === 0) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

async function checkUserNodes() {
  console.log("🔍 CHECKING FOR USER NODES IN FIREBASE");
  console.log("═".repeat(50));

  try {
    // Check if users node exists
    const usersSnapshot = await db.ref("/users").once("value");

    if (!usersSnapshot.exists()) {
      console.log("❌ NO USER NODES FOUND");
      console.log("   Path: /users");
      console.log("   Status: Does not exist");
      return;
    }

    const users = usersSnapshot.val();
    const userIds = Object.keys(users);

    console.log(`📊 FOUND ${userIds.length} USER NODE(S):`);
    console.log("─".repeat(30));

    for (const userId of userIds) {
      console.log(`\n👤 User: ${userId}`);

      // Check user structure
      const userNode = users[userId];
      const hasBaseline = userNode.baseline ? "✅" : "❌";
      const hasSessions = userNode.sessions ? "✅" : "❌";
      const hasAlerts = userNode.alerts ? "✅" : "❌";

      console.log(
        `   Baseline: ${hasBaseline} ${
          hasBaseline === "✅" ? `(${userNode.baseline?.heartRate} BPM)` : ""
        }`
      );
      console.log(
        `   Sessions: ${hasSessions} ${
          hasSessions === "✅"
            ? `(${Object.keys(userNode.sessions).length} sessions)`
            : ""
        }`
      );
      console.log(
        `   Alerts: ${hasAlerts} ${
          hasAlerts === "✅"
            ? `(${Object.keys(userNode.alerts).length} alerts)`
            : ""
        }`
      );

      // Show session details if they exist
      if (userNode.sessions) {
        const sessions = Object.keys(userNode.sessions);
        console.log("\n   📋 Sessions:");
        sessions.forEach((sessionId) => {
          const session = userNode.sessions[sessionId];
          const hasHistory = session.history
            ? `${Object.keys(session.history).length} data points`
            : "No history";
          const status = session.metadata?.status || "unknown";
          console.log(`      ${sessionId}: ${status} (${hasHistory})`);
        });
      }
    }
  } catch (error) {
    console.error("❌ Error checking user nodes:", error.message);
  }
}

// Also check what the current assignment says should exist
async function checkExpectedUserNode() {
  console.log("\n🔍 CHECKING EXPECTED USER FROM ASSIGNMENT");
  console.log("═".repeat(50));

  try {
    const assignmentSnapshot = await db
      .ref("/devices/AnxieEase001/assignment")
      .once("value");
    if (!assignmentSnapshot.exists()) {
      console.log("❌ No device assignment found");
      return;
    }

    const assignment = assignmentSnapshot.val();
    const expectedUserId = assignment.assignedUser;
    const expectedSessionId = assignment.activeSessionId;

    console.log(`👤 Expected User: ${expectedUserId}`);
    console.log(`📋 Expected Session: ${expectedSessionId}`);

    // Check if this specific user node exists
    const userSnapshot = await db.ref(`/users/${expectedUserId}`).once("value");
    if (userSnapshot.exists()) {
      console.log("✅ User node EXISTS");
      const userData = userSnapshot.val();

      console.log("\n📊 User Data Structure:");
      Object.keys(userData).forEach((key) => {
        console.log(
          `   ${key}: ${
            typeof userData[key] === "object" ? "Object" : userData[key]
          }`
        );
      });
    } else {
      console.log("❌ User node DOES NOT EXIST");
      console.log(`   Missing: /users/${expectedUserId}`);
      console.log(`   This means:`);
      console.log(`     • No user session history storage`);
      console.log(`     • No user baseline for anxiety detection`);
      console.log(`     • Data flows only through device nodes`);
    }
  } catch (error) {
    console.error("❌ Error checking expected user:", error.message);
  }
}

async function main() {
  await checkUserNodes();
  await checkExpectedUserNode();

  console.log("\n💡 SUMMARY:");
  console.log("═".repeat(50));
  console.log("If no user nodes exist, your data flow is:");
  console.log("  Hardware → /devices/current → /devices/history");
  console.log("  (No user isolation, no personalized baselines)");
  console.log("\nIf user nodes exist, your data flow is:");
  console.log(
    "  Hardware → /devices/current → /devices/history → /users/sessions/history"
  );
  console.log("  (Full user isolation, personalized anxiety detection)");
}

main().catch(console.error);
