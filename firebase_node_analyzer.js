/**
 * 🎯 FIREBASE NODE ANALYZER & CLEANUP
 * 
 * Specifically analyzes your Firebase structure to identify unnecessary nodes
 * Based on your database screenshot and requirements
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

class FirebaseNodeAnalyzer {
  constructor() {
    this.analysisResults = {
      unnecessaryNodes: [],
      duplicateData: [],
      testData: [],
      largeSections: [],
      recommendations: []
    };
  }

  async analyzeDatabase() {
    console.log("\n🔍 FIREBASE DATABASE ANALYSIS");
    console.log("=============================");
    
    await this.analyzeDeviceNodes();
    await this.analyzeUserNodes();
    await this.identifyUnnecessaryNodes();
    await this.analyzeDuplicateHistory();
    await this.generateReport();
    
    return this.analysisResults;
  }

  async analyzeDeviceNodes() {
    console.log("\n📱 ANALYZING DEVICE NODES");
    console.log("=========================");
    
    try {
      const devicesSnapshot = await db.ref("/devices").once("value");
      
      if (!devicesSnapshot.exists()) {
        console.log("❌ No devices found");
        return;
      }
      
      const devices = devicesSnapshot.val();
      
      for (const deviceId of Object.keys(devices)) {
        console.log(`🔍 Analyzing device: ${deviceId}`);
        const device = devices[deviceId];
        
        // Check for unnecessary nodes based on your screenshot
        await this.checkDeviceNode(deviceId, device);
      }
      
    } catch (error) {
      console.error("❌ Error analyzing device nodes:", error.message);
    }
  }

  async checkDeviceNode(deviceId, device) {
    const unnecessaryNodes = [];
    
    // 1. Check for testNotification node (visible in your screenshot)
    if (device.testNotification) {
      unnecessaryNodes.push({
        path: `/devices/${deviceId}/testNotification`,
        reason: "Test notification data - should be removed",
        size: JSON.stringify(device.testNotification).length,
        canDelete: true
      });
    }
    
    // 2. Check for notifications node (if it contains test data)
    if (device.notifications) {
      unnecessaryNodes.push({
        path: `/devices/${deviceId}/notifications`,
        reason: "Device-level notifications - users should have individual notification history",
        size: JSON.stringify(device.notifications).length,
        canDelete: true
      });
    }
    
    // 3. Check for userNotifications node (duplicate data)
    if (device.userNotifications) {
      unnecessaryNodes.push({
        path: `/devices/${deviceId}/userNotifications`,
        reason: "Duplicate user notifications - data should only be in /users/{userId}/",
        size: JSON.stringify(device.userNotifications).length,
        canDelete: true
      });
    }
    
    // 4. Check history size
    if (device.history) {
      const historySize = Object.keys(device.history).length;
      if (historySize > 1000) {
        this.analysisResults.largeSections.push({
          path: `/devices/${deviceId}/history`,
          reason: `Large history section with ${historySize} entries`,
          size: historySize,
          recommendation: "Consider archiving entries older than 7 days"
        });
      }
    }
    
    // Add to results
    this.analysisResults.unnecessaryNodes.push(...unnecessaryNodes);
    
    if (unnecessaryNodes.length > 0) {
      console.log(`❌ Found ${unnecessaryNodes.length} unnecessary nodes in ${deviceId}`);
    } else {
      console.log(`✅ ${deviceId} structure looks clean`);
    }
  }

  async analyzeUserNodes() {
    console.log("\n👥 ANALYZING USER NODES");
    console.log("========================");
    
    try {
      const usersSnapshot = await db.ref("/users").once("value");
      
      if (!usersSnapshot.exists()) {
        console.log("❌ No users found");
        return;
      }
      
      const users = usersSnapshot.val();
      const userIds = Object.keys(users);
      
      console.log(`👥 Found ${userIds.length} users`);
      
      for (const userId of userIds) {
        await this.analyzeUser(userId, users[userId]);
      }
      
    } catch (error) {
      console.error("❌ Error analyzing user nodes:", error.message);
    }
  }

  async analyzeUser(userId, userData) {
    // Check if this looks like a test user
    const isTestUser = this.identifyTestUser(userId, userData);
    
    if (isTestUser) {
      this.analysisResults.testData.push({
        path: `/users/${userId}`,
        reason: "Test user account",
        userId: userId,
        canDelete: true
      });
    }
    
    // Check for duplicate history in user sessions
    if (userData.sessions) {
      await this.checkUserSessionHistory(userId, userData.sessions);
    }
    
    // Check alerts count
    if (userData.alerts) {
      const alertCount = Object.keys(userData.alerts).length;
      if (alertCount > 100) {
        this.analysisResults.largeSections.push({
          path: `/users/${userId}/alerts`,
          reason: `User has ${alertCount} alerts`,
          size: alertCount,
          recommendation: "Consider archiving alerts older than 90 days"
        });
      }
    }
  }

  identifyTestUser(userId, userData) {
    // Based on your screenshot, identify test users
    const testPatterns = [
      /test/i,
      /demo/i,
      /debug/i,
      /temp/i,
      // Add specific test user IDs from your screenshot if needed
      /e0997cb7-684f-41e5-929f-4480788d4ad0/, // If this is a test user
    ];
    
    // Check user ID patterns
    for (const pattern of testPatterns) {
      if (pattern.test(userId)) {
        return true;
      }
    }
    
    // Check if user has minimal real data (might be test)
    const hasBaseline = userData.baseline && userData.baseline.heartRate;
    const hasRealAlerts = userData.alerts && Object.keys(userData.alerts).length > 0;
    const hasFCMToken = userData.fcmToken;
    
    // If user has no real data, might be test user
    if (!hasBaseline && !hasRealAlerts && !hasFCMToken) {
      return true;
    }
    
    return false;
  }

  async checkUserSessionHistory(userId, sessions) {
    const deviceHistoryRef = db.ref("/devices/AnxieEase001/history");
    
    try {
      const deviceHistorySnapshot = await deviceHistoryRef.once("value");
      
      if (!deviceHistorySnapshot.exists()) {
        return;
      }
      
      const deviceHistory = deviceHistorySnapshot.val();
      const deviceTimestamps = new Set(Object.keys(deviceHistory));
      
      // Check each session for duplicate data
      for (const sessionId of Object.keys(sessions)) {
        const session = sessions[sessionId];
        
        if (session.data) {
          const sessionTimestamps = Object.keys(session.data);
          const duplicates = sessionTimestamps.filter(ts => deviceTimestamps.has(ts));
          
          if (duplicates.length > 0) {
            this.analysisResults.duplicateData.push({
              path: `/users/${userId}/sessions/${sessionId}/data`,
              reason: `${duplicates.length} timestamps duplicate device history`,
              duplicateCount: duplicates.length,
              userId: userId,
              sessionId: sessionId,
              canClean: true
            });
          }
        }
      }
      
    } catch (error) {
      console.error(`❌ Error checking session history for ${userId}:`, error.message);
    }
  }

  async identifyUnnecessaryNodes() {
    console.log("\n🎯 IDENTIFYING SPECIFIC UNNECESSARY NODES");
    console.log("==========================================");
    
    // Based on your screenshot, check for these specific issues:
    const specificChecks = [
      {
        path: "/devices/AnxieEase001/testNotification",
        reason: "Test notification visible in screenshot"
      },
      {
        path: "/devices/AnxieEase001/notifications",
        reason: "Device notifications should be user-specific"
      },
      {
        path: "/devices/AnxieEase001/userNotifications",
        reason: "User notifications duplicated from device level"
      }
    ];
    
    for (const check of specificChecks) {
      try {
        const snapshot = await db.ref(check.path).once("value");
        
        if (snapshot.exists()) {
          const data = snapshot.val();
          this.analysisResults.unnecessaryNodes.push({
            ...check,
            size: JSON.stringify(data).length,
            canDelete: true,
            priority: "HIGH"
          });
          console.log(`❌ FOUND: ${check.path} - ${check.reason}`);
        }
      } catch (error) {
        console.error(`Error checking ${check.path}:`, error.message);
      }
    }
  }

  async analyzeDuplicateHistory() {
    console.log("\n🔄 ANALYZING DUPLICATE HISTORY");
    console.log("==============================");
    
    try {
      // This addresses your concern about history being copied to users
      const [deviceHistorySnapshot, usersSnapshot] = await Promise.all([
        db.ref("/devices/AnxieEase001/history").once("value"),
        db.ref("/users").once("value")
      ]);
      
      if (!deviceHistorySnapshot.exists() || !usersSnapshot.exists()) {
        console.log("✅ No data to compare");
        return;
      }
      
      const deviceHistory = deviceHistorySnapshot.val();
      const users = usersSnapshot.val();
      const deviceTimestamps = new Set(Object.keys(deviceHistory));
      
      let totalDuplicates = 0;
      
      for (const userId of Object.keys(users)) {
        const userSessions = users[userId].sessions;
        
        if (!userSessions) continue;
        
        for (const sessionId of Object.keys(userSessions)) {
          const sessionData = userSessions[sessionId].data;
          
          if (!sessionData) continue;
          
          const duplicateTimestamps = Object.keys(sessionData).filter(ts => 
            deviceTimestamps.has(ts)
          );
          
          if (duplicateTimestamps.length > 0) {
            totalDuplicates += duplicateTimestamps.length;
            console.log(`🔄 User ${userId.substring(0, 8)}: ${duplicateTimestamps.length} duplicates`);
          }
        }
      }
      
      if (totalDuplicates > 0) {
        this.analysisResults.recommendations.push({
          type: "DUPLICATE_CLEANUP",
          message: `Remove ${totalDuplicates} duplicate history entries from user sessions`,
          impact: "HIGH",
          savingsEstimate: `${Math.round(totalDuplicates * 0.1)}KB`
        });
      }
      
    } catch (error) {
      console.error("❌ Error analyzing duplicate history:", error.message);
    }
  }

  async generateReport() {
    console.log("\n📊 ANALYSIS REPORT");
    console.log("==================");
    
    const { unnecessaryNodes, duplicateData, testData, largeSections, recommendations } = this.analysisResults;
    
    console.log(`❌ Unnecessary nodes: ${unnecessaryNodes.length}`);
    console.log(`🔄 Duplicate data sections: ${duplicateData.length}`);
    console.log(`🧪 Test data sections: ${testData.length}`);
    console.log(`📈 Large data sections: ${largeSections.length}`);
    
    // Calculate potential savings
    let totalSavings = 0;
    unnecessaryNodes.forEach(node => {
      if (typeof node.size === 'number') {
        totalSavings += node.size;
      }
    });
    
    console.log(`💾 Estimated storage savings: ${Math.round(totalSavings / 1024)}KB`);
    
    // High priority items
    const highPriorityNodes = unnecessaryNodes.filter(node => node.priority === "HIGH");
    
    if (highPriorityNodes.length > 0) {
      console.log("\n🚨 HIGH PRIORITY REMOVALS:");
      highPriorityNodes.forEach(node => {
        console.log(`  ❌ ${node.path} - ${node.reason}`);
      });
    }
    
    // Recommendations
    if (recommendations.length > 0) {
      console.log("\n💡 RECOMMENDATIONS:");
      recommendations.forEach(rec => {
        console.log(`  ${rec.impact === 'HIGH' ? '🔥' : '💡'} ${rec.message}`);
      });
    }
    
    console.log("\n🧹 SUGGESTED CLEANUP ORDER:");
    console.log("============================");
    console.log("1. Remove test data (immediate)");
    console.log("2. Remove duplicate user notifications");
    console.log("3. Clean duplicate history from user sessions");
    console.log("4. Archive old device history (>7 days)");
    console.log("5. Remove test user accounts");
    
    return this.analysisResults;
  }

  // Quick cleanup method for immediate removals
  async performQuickCleanup(dryRun = true) {
    console.log("\n🧹 PERFORMING QUICK CLEANUP");
    console.log(`Mode: ${dryRun ? 'DRY RUN' : 'LIVE'}` );
    console.log("===========================");
    
    const highPriorityNodes = this.analysisResults.unnecessaryNodes.filter(
      node => node.canDelete && node.priority === "HIGH"
    );
    
    let removedCount = 0;
    
    for (const node of highPriorityNodes) {
      try {
        if (!dryRun) {
          await db.ref(node.path).remove();
          removedCount++;
          console.log(`✅ Removed: ${node.path}`);
        } else {
          console.log(`🔍 [DRY RUN] Would remove: ${node.path}`);
        }
      } catch (error) {
        console.error(`❌ Error removing ${node.path}:`, error.message);
      }
    }
    
    console.log(`${dryRun ? 'Would remove' : 'Removed'} ${highPriorityNodes.length} unnecessary nodes`);
    
    return removedCount;
  }
}

// Main execution
async function main() {
  const analyzer = new FirebaseNodeAnalyzer();
  
  console.log("🔍 Starting Firebase database analysis...");
  const results = await analyzer.analyzeDatabase();
  
  console.log("\n🤔 WANT TO PERFORM QUICK CLEANUP?");
  console.log("==================================");
  console.log("Uncomment the line below to perform safe cleanup of unnecessary nodes:");
  console.log("// await analyzer.performQuickCleanup(false); // Set to false for live cleanup");
  
  // Uncomment this line to perform cleanup (start with dryRun = true)
  // await analyzer.performQuickCleanup(true);
  
  return results;
}

// Export for use in other scripts
module.exports = { FirebaseNodeAnalyzer };

// Run if executed directly
if (require.main === module) {
  main().catch(console.error);
}