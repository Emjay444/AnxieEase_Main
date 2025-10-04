const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert("./service-account-key.json"),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

/**
 * Clean up duplicate baseline entries and duplicate users
 */
async function cleanupDuplicatesAndBaselines() {
  console.log("🧹 Starting cleanup of duplicate baselines and user entries...");
  console.log("");

  try {
    // STEP 1: Create backup of current state
    console.log("📦 Creating backup before cleanup...");
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    const usersData = usersSnapshot.val();

    const userBaselinesRef = db.ref("/user_baselines");
    const userBaselinesSnapshot = await userBaselinesRef.once("value");
    const userBaselinesData = userBaselinesSnapshot.val();

    // Store backup
    const backupRef = db.ref("/system/backups/cleanup_baselines_duplicates");
    await backupRef.set({
      timestamp: new Date().toISOString(),
      users_before_cleanup: usersData,
      user_baselines_before_cleanup: userBaselinesData,
      operation: "baseline_and_duplicate_cleanup",
    });

    console.log(
      "✅ Backup created at /system/backups/cleanup_baselines_duplicates"
    );
    console.log("");

    // STEP 2: Analyze current structure
    console.log("🔍 Analyzing current database structure...");

    const userIds = usersData ? Object.keys(usersData) : [];
    const uniqueUserIds = [...new Set(userIds)];
    const duplicateUserIds = userIds.filter(
      (item, index) => userIds.indexOf(item) !== index
    );

    console.log(`📊 Analysis results:`);
    console.log(`   Total user entries: ${userIds.length}`);
    console.log(`   Unique users: ${uniqueUserIds.length}`);
    console.log(`   Duplicate entries: ${duplicateUserIds.length}`);

    if (duplicateUserIds.length > 0) {
      console.log(`   Duplicate user IDs: ${duplicateUserIds.join(", ")}`);
    }

    // Check which users have duplicate baseline data
    let usersWithDuplicateBaselines = 0;
    if (usersData) {
      for (const userId of uniqueUserIds) {
        const userHasBaseline = usersData[userId]?.baseline !== undefined;
        const userBaselinesHasEntry = userBaselinesData?.[userId] !== undefined;

        if (userHasBaseline && userBaselinesHasEntry) {
          usersWithDuplicateBaselines++;
        }
      }
    }

    console.log(
      `   Users with duplicate baseline data: ${usersWithDuplicateBaselines}`
    );
    console.log("");

    // STEP 3: Remove duplicate baseline entries from users node
    console.log(
      "🗑️ Removing duplicate baseline entries from users/[userId]/baseline/..."
    );

    let baselinesCleaned = 0;
    if (usersData) {
      for (const userId of uniqueUserIds) {
        const user = usersData[userId];
        if (user && user.baseline !== undefined) {
          // Remove the baseline field from users node
          await db.ref(`/users/${userId}/baseline`).remove();
          baselinesCleaned++;
          console.log(
            `   ✅ Removed duplicate baseline for user: ${userId.substring(
              0,
              8
            )}...`
          );
        }
      }
    }

    console.log(`✅ Cleaned up ${baselinesCleaned} duplicate baseline entries`);
    console.log("");

    // STEP 4: Handle duplicate user entries (if any)
    if (duplicateUserIds.length > 0) {
      console.log("🔄 Handling duplicate user entries...");

      // For each duplicate, we need to merge the data and keep only one entry
      for (const duplicateUserId of duplicateUserIds) {
        console.log(
          `   Processing duplicate user: ${duplicateUserId.substring(0, 8)}...`
        );

        // Find all instances of this user ID
        const userInstances = [];
        userIds.forEach((id, index) => {
          if (id === duplicateUserId) {
            userInstances.push({ index, data: usersData[id] });
          }
        });

        if (userInstances.length > 1) {
          // Merge all instances (combine sessions, alerts, etc.)
          const mergedUser = { ...userInstances[0].data };

          for (let i = 1; i < userInstances.length; i++) {
            const instance = userInstances[i].data;

            // Merge sessions
            if (instance.sessions) {
              mergedUser.sessions = {
                ...(mergedUser.sessions || {}),
                ...instance.sessions,
              };
            }

            // Merge alerts
            if (instance.alerts) {
              mergedUser.alerts = {
                ...(mergedUser.alerts || {}),
                ...instance.alerts,
              };
            }

            // Merge anxiety_alerts
            if (instance.anxiety_alerts) {
              mergedUser.anxiety_alerts = {
                ...(mergedUser.anxiety_alerts || {}),
                ...instance.anxiety_alerts,
              };
            }

            // Keep the most recent profile data
            if (instance.profile) {
              mergedUser.profile = instance.profile;
            }
          }

          // Update the user with merged data
          await db.ref(`/users/${duplicateUserId}`).set(mergedUser);
          console.log(
            `   ✅ Merged duplicate entries for user: ${duplicateUserId.substring(
              0,
              8
            )}...`
          );
        }
      }
    }

    // STEP 5: Verify user_baselines structure is intact
    console.log("✅ Verifying user_baselines structure...");

    const finalUserBaselinesSnapshot = await userBaselinesRef.once("value");
    const finalUserBaselinesData = finalUserBaselinesSnapshot.val();

    if (finalUserBaselinesData) {
      const baselineUserCount = Object.keys(finalUserBaselinesData).length;
      console.log(`   user_baselines contains ${baselineUserCount} users`);

      // Show sample baseline structure
      const sampleUserId = Object.keys(finalUserBaselinesData)[0];
      const sampleBaseline = finalUserBaselinesData[sampleUserId];
      console.log(
        `   Sample baseline structure for ${sampleUserId.substring(0, 8)}...:`
      );
      Object.keys(sampleBaseline).forEach((key) => {
        console.log(`     ${key}: ${sampleBaseline[key]}`);
      });
    }

    console.log("");

    // STEP 6: Final verification
    console.log("🔍 Final verification...");

    const finalUsersSnapshot = await usersRef.once("value");
    const finalUsersData = finalUsersSnapshot.val();

    if (finalUsersData) {
      const finalUserIds = Object.keys(finalUsersData);
      const finalUniqueUserIds = [...new Set(finalUserIds)];

      // Check if any users still have baseline field
      let remainingDuplicateBaselines = 0;
      for (const userId of finalUniqueUserIds) {
        if (finalUsersData[userId]?.baseline !== undefined) {
          remainingDuplicateBaselines++;
        }
      }

      console.log(`📊 Final results:`);
      console.log(`   Total user entries: ${finalUserIds.length}`);
      console.log(`   Unique users: ${finalUniqueUserIds.length}`);
      console.log(
        `   Remaining duplicate baselines: ${remainingDuplicateBaselines}`
      );
      console.log(
        `   user_baselines entries: ${
          finalUserBaselinesData
            ? Object.keys(finalUserBaselinesData).length
            : 0
        }`
      );
    }

    console.log("");
    console.log("🎉 Cleanup completed successfully!");
    console.log("✅ Recommended structure now in place:");
    console.log("   - Baselines: user_baselines/[userId]/ (canonical)");
    console.log("   - User data: users/[userId]/ (no duplicate baselines)");
    console.log("   - Backup available for recovery if needed");
  } catch (error) {
    console.error("❌ Error during cleanup:", error);
    console.log(
      "🔒 Backup is available for recovery at /system/backups/cleanup_baselines_duplicates"
    );
    throw error;
  }
}

/**
 * Show the recommended structure after cleanup
 */
async function showRecommendedStructure() {
  console.log("");
  console.log("📋 RECOMMENDED STRUCTURE (after cleanup):");
  console.log("");
  console.log("✅ user_baselines/[userId]/     ← CANONICAL baseline data");
  console.log("   ├── avgHeartRate: 73.2");
  console.log("   ├── avgMovement: 12.3");
  console.log("   ├── avgSpO2: 98.5");
  console.log("   ├── established: true");
  console.log("   ├── lastUpdated: timestamp");
  console.log("   └── samplesCount: 100");
  console.log("");
  console.log("✅ users/[userId]/              ← User profiles and sessions");
  console.log("   ├── alerts/");
  console.log("   ├── anxiety_alerts/");
  console.log("   ├── sessions/");
  console.log("   ├── profile/");
  console.log("   └── fcmToken/");
  console.log("   (NO baseline/ field - removed duplicate)");
  console.log("");
  console.log("Benefits:");
  console.log("• Single source of truth for baselines");
  console.log("• Better performance and organization");
  console.log("• No data duplication");
  console.log("• Cleaner structure for your capstone demo");
}

// Run the cleanup if this script is executed directly
if (require.main === module) {
  cleanupDuplicatesAndBaselines()
    .then(() => {
      showRecommendedStructure();
      console.log("");
      console.log("✅ Script completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Script failed:", error);
      process.exit(1);
    });
}

module.exports = {
  cleanupDuplicatesAndBaselines,
  showRecommendedStructure,
};
