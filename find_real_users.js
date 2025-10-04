const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

async function findRealUsers() {
  try {
    console.log("🔍 Finding real users in database...\n");

    // Check users
    const usersRef = admin.database().ref("/users");
    const usersSnapshot = await usersRef.once("value");

    if (usersSnapshot.exists()) {
      const users = usersSnapshot.val();
      const userIds = Object.keys(users);

      console.log(`👥 Found ${userIds.length} users:\n`);

      for (const userId of userIds) {
        const user = users[userId];
        console.log(`📱 User ID: ${userId}`);

        // Check if user has profile info
        if (user.profile) {
          console.log(`   Name: ${user.profile.name || "Not set"}`);
          console.log(`   Email: ${user.profile.email || "Not set"}`);

          // Check baseline
          if (user.profile.baseline) {
            console.log(
              `   Baseline HR: ${
                user.profile.baseline.baselineHR || "Not set"
              } BPM`
            );
          } else {
            console.log(`   Baseline HR: Not set`);
          }
        }

        // Check if user has any sessions
        if (user.sessions) {
          const sessionCount = Object.keys(user.sessions).length;
          console.log(`   Sessions: ${sessionCount}`);
        } else {
          console.log(`   Sessions: 0`);
        }

        console.log(""); // Empty line for spacing
      }

      // Also check device assignments to find which user should be assigned
      console.log("🔗 Checking device assignments...\n");
      const devicesRef = admin.database().ref("/devices");
      const devicesSnapshot = await devicesRef.once("value");

      if (devicesSnapshot.exists()) {
        const devices = devicesSnapshot.val();
        for (const deviceId of Object.keys(devices)) {
          if (devices[deviceId].assignment) {
            const assignment = devices[deviceId].assignment;
            console.log(
              `📱 Device ${deviceId} → User ${assignment.assignedUser}`
            );
          }
        }
      }
    } else {
      console.log("❌ No users found in database");
    }

    process.exit(0);
  } catch (error) {
    console.error("❌ Error finding users:", error);
    process.exit(1);
  }
}

findRealUsers();
