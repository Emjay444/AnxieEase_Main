const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert("./service-account-key.json"),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

/**
 * USERS NODE ANALYSIS
 * 
 * This script analyzes the current users node structure to identify
 * redundancy and unnecessary session duplication
 */

async function analyzeUsersStructure() {
  console.log("🔍 ANALYZING USERS NODE STRUCTURE");
  console.log("🎯 Identifying redundancy and unnecessary session duplication");
  console.log("");

  try {
    // Get users data
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    
    if (!usersSnapshot.exists()) {
      console.log("❌ No users node found");
      return;
    }

    const users = usersSnapshot.val();
    const userIds = Object.keys(users);
    
    console.log(`📊 USERS OVERVIEW:`);
    console.log(`   👥 Total users: ${userIds.length}`);
    console.log("");

    let totalSessions = 0;
    let totalHistoryEntries = 0;
    let redundantSessions = 0;
    let activeSessions = 0;
    let completedSessions = 0;
    
    // Analyze each user
    for (const userId of userIds) {
      const user = users[userId];
      console.log(`👤 USER: ${userId}`);
      
      // Check profile
      if (user.profile) {
        console.log(`   📋 Profile: ${user.profile.firstName || 'N/A'} ${user.profile.lastName || 'N/A'}`);
        console.log(`   📧 Email: ${user.profile.email || 'N/A'}`);
        console.log(`   🔗 Role: ${user.profile.role || 'N/A'}`);
      } else {
        console.log(`   📋 Profile: Missing`);
      }

      // Analyze sessions
      if (user.sessions) {
        const sessionIds = Object.keys(user.sessions);
        totalSessions += sessionIds.length;
        
        console.log(`   📊 Sessions: ${sessionIds.length}`);
        
        let userActiveSessions = 0;
        let userCompletedSessions = 0;
        let userHistoryEntries = 0;
        
        // Check each session
        sessionIds.forEach((sessionId, index) => {
          const session = user.sessions[sessionId];
          
          // Basic session info
          const status = session.metadata?.status || 'unknown';
          const deviceId = session.metadata?.deviceId || 'N/A';
          const startTime = session.metadata?.startTime ? new Date(session.metadata.startTime).toISOString().slice(0, 19) : 'N/A';
          const endTime = session.metadata?.endTime ? new Date(session.metadata.endTime).toISOString().slice(0, 19) : 'ongoing';
          
          if (status === 'active') {
            userActiveSessions++;
            activeSessions++;
          } else if (status === 'completed') {
            userCompletedSessions++;
            completedSessions++;
          }

          // Count history entries
          const historyCount = session.history ? Object.keys(session.history).length : 0;
          userHistoryEntries += historyCount;
          totalHistoryEntries += historyCount;

          // Show first few sessions in detail
          if (index < 3) {
            console.log(`      📁 Session ${sessionId}:`);
            console.log(`         Status: ${status}`);
            console.log(`         Device: ${deviceId}`);
            console.log(`         Period: ${startTime} → ${endTime}`);
            console.log(`         History entries: ${historyCount}`);
            console.log(`         Has current data: ${session.current ? 'Yes' : 'No'}`);
            console.log(`         Has analytics: ${session.analytics ? 'Yes' : 'No'}`);
          } else if (index === 3) {
            console.log(`      ... (${sessionIds.length - 3} more sessions)`);
          }
        });
        
        console.log(`   📈 Summary: ${userActiveSessions} active, ${userCompletedSessions} completed, ${userHistoryEntries} total history entries`);
        
        // Check for potential redundancy
        if (userActiveSessions > 1) {
          redundantSessions += (userActiveSessions - 1);
          console.log(`   ⚠️  POTENTIAL ISSUE: ${userActiveSessions} active sessions (should be max 1)`);
        }
        
        if (userCompletedSessions > 10) {
          console.log(`   ⚠️  STORAGE CONCERN: ${userCompletedSessions} completed sessions (consider cleanup)`);
        }
        
      } else {
        console.log(`   📊 Sessions: None`);
      }
      
      console.log("");
    }

    // Overall analysis
    console.log("=" * 60);
    console.log("📊 OVERALL ANALYSIS");
    console.log("=" * 60);
    
    console.log(`📈 TOTALS:`);
    console.log(`   👥 Users: ${userIds.length}`);
    console.log(`   📁 Sessions: ${totalSessions}`);
    console.log(`   📊 History entries: ${totalHistoryEntries.toLocaleString()}`);
    console.log(`   ✅ Active sessions: ${activeSessions}`);
    console.log(`   ⏹️  Completed sessions: ${completedSessions}`);
    
    console.log(`\n⚠️  REDUNDANCY ANALYSIS:`);
    if (redundantSessions > 0) {
      console.log(`   🔴 Redundant active sessions: ${redundantSessions}`);
      console.log(`   💡 Each user should have max 1 active session`);
    } else {
      console.log(`   ✅ No redundant active sessions detected`);
    }
    
    const avgSessionsPerUser = (totalSessions / userIds.length).toFixed(1);
    const avgHistoryPerUser = (totalHistoryEntries / userIds.length).toFixed(0);
    
    console.log(`\n📊 AVERAGES:`);
    console.log(`   📁 Sessions per user: ${avgSessionsPerUser}`);
    console.log(`   📊 History entries per user: ${avgHistoryPerUser}`);
    
    // Purpose analysis
    console.log(`\n🎯 PURPOSE ANALYSIS:`);
    console.log(`\n✅ NECESSARY DATA:`);
    console.log(`   👤 User profiles - User identification and info`);
    console.log(`   📱 Active sessions - Current device monitoring`);
    console.log(`   📊 Recent history - Anxiety detection (last 50 entries per session)`);
    console.log(`   📈 Session analytics - Health insights and baselines`);
    
    console.log(`\n❓ QUESTIONABLE DATA:`);
    console.log(`   📁 Multiple active sessions - Should be max 1 per user`);
    console.log(`   ⏹️  Old completed sessions - May not need infinite retention`);
    console.log(`   📊 Excessive history - Sliding window should limit entries`);
    console.log(`   🔄 Redundant metadata - Some fields may be duplicated`);
    
    // Storage impact
    const estimatedStorageKB = Math.round(totalHistoryEntries * 0.5);
    console.log(`\n💾 STORAGE IMPACT:`);
    console.log(`   📊 Estimated user data size: ~${estimatedStorageKB} KB`);
    console.log(`   📈 Growth rate: ~${Math.round(activeSessions * 8.64)} KB/day (if 1 entry/5min)`);
    
    // Recommendations
    console.log(`\n🚀 RECOMMENDATIONS:`);
    console.log(`   1. 🔧 Limit to 1 active session per user`);
    console.log(`   2. 🗑️  Auto-cleanup completed sessions > 30 days old`);
    console.log(`   3. ⚡ Implement sliding window (50 entries max per session)`);
    console.log(`   4. 📊 Keep analytics but remove redundant metadata`);
    console.log(`   5. 💡 Consider moving old data to cheaper storage`);

    return {
      totalUsers: userIds.length,
      totalSessions,
      totalHistoryEntries,
      redundantSessions,
      activeSessions,
      completedSessions,
      avgSessionsPerUser: parseFloat(avgSessionsPerUser),
      needsOptimization: redundantSessions > 0 || completedSessions > 50
    };

  } catch (error) {
    console.error("❌ Error analyzing users structure:", error);
    throw error;
  }
}

/**
 * Identify what each part of the users structure is for
 */
async function explainUsersStructurePurpose() {
  console.log("\n🎯 USERS STRUCTURE PURPOSE EXPLANATION");
  console.log("=" * 50);
  
  console.log(`
📁 /users/{userId}/
├── profile/                    ✅ ESSENTIAL
│   ├── firstName              ✅ User identification
│   ├── lastName               ✅ User identification  
│   ├── email                  ✅ Contact/login info
│   └── role                   ✅ Access control (patient/admin)
│
├── sessions/                   ✅ ESSENTIAL (but needs optimization)
│   └── {sessionId}/
│       ├── metadata/          ✅ ESSENTIAL
│       │   ├── deviceId       ✅ Track which device assigned
│       │   ├── startTime      ✅ Session timing
│       │   ├── endTime        ✅ Session completion
│       │   ├── status         ✅ active/completed state
│       │   ├── assignedBy     ⚠️  OPTIONAL (admin tracking)
│       │   ├── adminNotes     ⚠️  OPTIONAL (admin notes)
│       │   └── totalDataPoints ❓ REDUNDANT (can calculate)
│       │
│       ├── current/           ✅ ESSENTIAL
│       │   └── {sensorData}   ✅ Real-time monitoring display
│       │
│       ├── history/           ⚠️  NEEDS OPTIMIZATION  
│       │   └── {timestamp}/   ⚠️  Should be sliding window (50 max)
│       │       └── {sensorData} ✅ Anxiety detection algorithm data
│       │
│       └── analytics/         ✅ USEFUL
│           ├── avgHeartRate   ✅ Health insights
│           ├── maxHeartRate   ✅ Threshold monitoring  
│           ├── anxietyEvents  ✅ Detection results
│           └── totalDuration  ✅ Usage tracking

🎯 KEY PURPOSES:

1. 👤 USER PROFILES:
   - Store user identity and contact info
   - Control access permissions (patient vs admin)
   - Enable personalized features

2. 📱 ACTIVE SESSIONS:
   - Track current device assignment
   - Enable real-time monitoring
   - Provide "current" data for live dashboard

3. 📊 SESSION HISTORY:
   - Power anxiety detection algorithms (needs 10-50 data points)
   - Enable trend analysis and insights
   - Support threshold and baseline calculations

4. 📈 SESSION ANALYTICS:
   - Store computed health metrics
   - Track anxiety events and patterns
   - Provide summary statistics

❌ REDUNDANCY ISSUES:

1. 🔄 Multiple Active Sessions:
   - Each user should have MAX 1 active session
   - Multiple sessions waste storage and confuse tracking

2. 📁 Infinite Session Retention:
   - Completed sessions pile up forever
   - Old sessions rarely accessed but consume storage

3. 📊 Unbounded History Growth:
   - Session history grows without limit
   - Only need ~50 recent entries for anxiety detection

4. 🔢 Redundant Counters:
   - totalDataPoints can be calculated from history length
   - lastActivity often duplicated in multiple places
  `);
}

/**
 * Main analysis function
 */
async function runUsersAnalysis() {
  console.log("🔍 COMPREHENSIVE USERS NODE ANALYSIS");
  console.log("🎯 Understanding purpose and identifying redundancy");
  console.log("");

  try {
    // Explain purpose first
    await explainUsersStructurePurpose();
    
    // Then analyze current state
    const results = await analyzeUsersStructure();
    
    console.log("\n" + "=" * 60);
    console.log("🎯 ANALYSIS COMPLETE");
    console.log("=" * 60);
    
    if (results.needsOptimization) {
      console.log("⚠️  OPTIMIZATION NEEDED:");
      console.log("   - User session structure has redundancy issues");
      console.log("   - Storage usage can be significantly reduced");
      console.log("   - Performance can be improved with cleanup");
    } else {
      console.log("✅ User structure is reasonably optimized");
    }
    
    return results;

  } catch (error) {
    console.error("❌ Users analysis failed:", error);
    throw error;
  }
}

// Run analysis if this script is executed directly
if (require.main === module) {
  runUsersAnalysis()
    .then((results) => {
      console.log("\n✅ Analysis completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Analysis failed:", error);
      process.exit(1);
    });
}

module.exports = { runUsersAnalysis, analyzeUsersStructure, explainUsersStructurePurpose };