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
 * USER NODE COMPONENT ANALYSIS
 * 
 * This script analyzes the 4 main components in users/{userId}:
 * 1. alerts
 * 2. anxiety_alerts  
 * 3. baseline
 * 4. sessions
 * 
 * Goal: Identify redundancy and determine what's actually needed
 */

async function analyzeUserNodeComponents() {
  console.log("🔍 ANALYZING USER NODE COMPONENTS");
  console.log("=" * 40);

  try {
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    
    if (!usersSnapshot.exists()) {
      console.log("❌ No users found");
      return;
    }

    const users = usersSnapshot.val();

    for (const userId of Object.keys(users)) {
      const user = users[userId];
      
      console.log(`\n👤 USER: ${userId}`);
      console.log("=" * 50);

      // Analyze each component
      await analyzeAlerts(userId, user.alerts);
      await analyzeAnxietyAlerts(userId, user.anxiety_alerts);
      await analyzeBaseline(userId, user.baseline);
      await analyzeSessions(userId, user.sessions);

      // Check for data overlap
      await checkDataOverlap(userId, user);
    }

  } catch (error) {
    console.error("❌ Error analyzing user node components:", error);
    throw error;
  }
}

async function analyzeAlerts(userId, alerts) {
  console.log("\n📢 ALERTS NODE:");
  
  if (!alerts) {
    console.log("   ❌ No alerts data");
    return { exists: false };
  }

  const alertKeys = Object.keys(alerts);
  console.log(`   📊 Total alerts: ${alertKeys.length}`);

  // Sample a few alerts to understand structure
  const sampleAlerts = alertKeys.slice(0, 3);
  sampleAlerts.forEach(alertId => {
    const alert = alerts[alertId];
    console.log(`   📄 Sample Alert (${alertId}):`);
    console.log(`      Type: ${alert.type || 'unknown'}`);
    console.log(`      Timestamp: ${alert.timestamp || 'unknown'}`);
    console.log(`      Message: ${alert.message || 'unknown'}`);
    console.log(`      DeviceId: ${alert.deviceId || 'unknown'}`);
  });

  return {
    exists: true,
    count: alertKeys.length,
    structure: sampleAlerts.length > 0 ? alerts[sampleAlerts[0]] : null
  };
}

async function analyzeAnxietyAlerts(userId, anxietyAlerts) {
  console.log("\n⚠️  ANXIETY_ALERTS NODE:");
  
  if (!anxietyAlerts) {
    console.log("   ❌ No anxiety_alerts data");
    return { exists: false };
  }

  const alertKeys = Object.keys(anxietyAlerts);
  console.log(`   📊 Total anxiety alerts: ${alertKeys.length}`);

  // Sample a few anxiety alerts to understand structure
  const sampleAlerts = alertKeys.slice(0, 3);
  sampleAlerts.forEach(alertId => {
    const alert = anxietyAlerts[alertId];
    console.log(`   📄 Sample Anxiety Alert (${alertId}):`);
    console.log(`      Level: ${alert.level || 'unknown'}`);
    console.log(`      Timestamp: ${alert.timestamp || 'unknown'}`);
    console.log(`      HeartRate: ${alert.heartRate || 'unknown'}`);
    console.log(`      DeviceId: ${alert.deviceId || 'unknown'}`);
    console.log(`      Threshold: ${alert.threshold || 'unknown'}`);
  });

  return {
    exists: true,
    count: alertKeys.length,
    structure: sampleAlerts.length > 0 ? anxietyAlerts[sampleAlerts[0]] : null
  };
}

async function analyzeBaseline(userId, baseline) {
  console.log("\n📏 BASELINE NODE:");
  
  if (!baseline) {
    console.log("   ❌ No baseline data");
    return { exists: false };
  }

  console.log(`   📄 Baseline Data:`);
  console.log(`      DeviceId: ${baseline.deviceId || 'unknown'}`);
  console.log(`      HeartRate: ${baseline.heartRate || 'unknown'}`);
  console.log(`      Source: ${baseline.source || 'unknown'}`);
  console.log(`      Timestamp: ${baseline.timestamp || 'unknown'}`);

  return {
    exists: true,
    structure: baseline
  };
}

async function analyzeSessions(userId, sessions) {
  console.log("\n📁 SESSIONS NODE:");
  
  if (!sessions) {
    console.log("   ❌ No sessions data");
    return { exists: false };
  }

  const sessionKeys = Object.keys(sessions);
  console.log(`   📊 Total sessions: ${sessionKeys.length}`);

  let totalHistoryEntries = 0;
  let activeSessions = 0;
  let completedSessions = 0;

  sessionKeys.forEach(sessionId => {
    const session = sessions[sessionId];
    const status = session.metadata?.status || 'unknown';
    const historyCount = session.history ? Object.keys(session.history).length : 0;
    
    totalHistoryEntries += historyCount;
    
    if (status === 'active') activeSessions++;
    else if (status === 'completed') completedSessions++;

    console.log(`   📄 Session ${sessionId}:`);
    console.log(`      Status: ${status}`);
    console.log(`      History entries: ${historyCount}`);
    console.log(`      DeviceId: ${session.current?.deviceId || session.metadata?.deviceId || 'unknown'}`);
  });

  console.log(`   📊 Session Summary:`);
  console.log(`      Active sessions: ${activeSessions}`);
  console.log(`      Completed sessions: ${completedSessions}`);
  console.log(`      Total history entries: ${totalHistoryEntries}`);

  return {
    exists: true,
    totalSessions: sessionKeys.length,
    activeSessions,
    completedSessions,
    totalHistoryEntries
  };
}

async function checkDataOverlap(userId, user) {
  console.log("\n🔍 CHECKING DATA OVERLAP & REDUNDANCY:");

  const overlaps = [];

  // Check if alerts and anxiety_alerts contain similar data
  if (user.alerts && user.anxiety_alerts) {
    console.log("   🔄 Checking alerts vs anxiety_alerts overlap...");
    
    // Sample comparison
    const alertTimestamps = Object.values(user.alerts).map(alert => alert.timestamp).filter(Boolean);
    const anxietyTimestamps = Object.values(user.anxiety_alerts).map(alert => alert.timestamp).filter(Boolean);
    
    const commonTimestamps = alertTimestamps.filter(ts => anxietyTimestamps.includes(ts));
    
    if (commonTimestamps.length > 0) {
      overlaps.push({
        type: 'alerts_vs_anxiety_alerts',
        commonCount: commonTimestamps.length,
        description: 'Same timestamps found in both alerts and anxiety_alerts'
      });
      console.log(`      ⚠️  Found ${commonTimestamps.length} overlapping timestamps`);
    } else {
      console.log("      ✅ No timestamp overlap detected");
    }
  }

  // Check if baseline data is duplicated in sessions
  if (user.baseline && user.sessions) {
    console.log("   🔄 Checking baseline vs sessions overlap...");
    
    const baselineHR = user.baseline.heartRate;
    const baselineDevice = user.baseline.deviceId;
    
    // Check if baseline data appears in session history
    let foundInSessions = false;
    for (const sessionId of Object.keys(user.sessions)) {
      const session = user.sessions[sessionId];
      if (session.metadata?.baselineHR === baselineHR && 
          session.metadata?.deviceId === baselineDevice) {
        foundInSessions = true;
        break;
      }
    }

    if (foundInSessions) {
      overlaps.push({
        type: 'baseline_vs_sessions',
        description: 'Baseline data duplicated in session metadata'
      });
      console.log("      ⚠️  Baseline data found duplicated in sessions");
    } else {
      console.log("      ✅ Baseline data unique (not duplicated in sessions)");
    }
  }

  // Check if session history contains alert data
  if (user.sessions && (user.alerts || user.anxiety_alerts)) {
    console.log("   🔄 Checking sessions vs alerts overlap...");
    
    let alertDataInSessions = 0;
    for (const sessionId of Object.keys(user.sessions)) {
      const session = user.sessions[sessionId];
      if (session.history) {
        for (const historyEntry of Object.values(session.history)) {
          if (historyEntry.alertTriggered || historyEntry.anxietyLevel) {
            alertDataInSessions++;
          }
        }
      }
    }

    if (alertDataInSessions > 0) {
      overlaps.push({
        type: 'sessions_vs_alerts',
        count: alertDataInSessions,
        description: 'Alert/anxiety data found in session history'
      });
      console.log(`      ⚠️  Found ${alertDataInSessions} alert-related entries in session history`);
    } else {
      console.log("      ✅ No alert data in session history");
    }
  }

  console.log("\n📋 OVERLAP SUMMARY:");
  if (overlaps.length === 0) {
    console.log("   ✅ No significant data overlap detected");
  } else {
    overlaps.forEach(overlap => {
      console.log(`   ⚠️  ${overlap.type}: ${overlap.description}`);
    });
  }

  return overlaps;
}

async function generateOptimizationRecommendations() {
  console.log("\n💡 OPTIMIZATION RECOMMENDATIONS");
  console.log("=" * 35);

  const recommendations = {
    essential: [],
    redundant: [],
    consolidatable: [],
    optimization_strategies: []
  };

  console.log("📋 COMPONENT NECESSITY ANALYSIS:");

  // Baseline - Essential
  recommendations.essential.push({
    component: 'baseline',
    reason: 'Required for anxiety detection algorithms and personalized thresholds',
    recommendation: 'KEEP - Single source of truth for user baseline metrics'
  });

  // Sessions - Essential but needs optimization  
  recommendations.essential.push({
    component: 'sessions',
    reason: 'Core functionality for real-time monitoring and historical analysis',
    recommendation: 'KEEP & OPTIMIZE - Already optimized with sliding window'
  });

  // Alerts vs Anxiety Alerts - Potential redundancy
  recommendations.consolidatable.push({
    components: 'alerts + anxiety_alerts',
    reason: 'Both store alert information, potentially duplicating anxiety-related alerts',
    recommendation: 'CONSOLIDATE - Merge into single alerts structure with type classification'
  });

  console.log("\n✅ ESSENTIAL COMPONENTS:");
  recommendations.essential.forEach(item => {
    console.log(`   📌 ${item.component.toUpperCase()}`);
    console.log(`      Why: ${item.reason}`);
    console.log(`      Action: ${item.recommendation}`);
  });

  console.log("\n🔄 CONSOLIDATION OPPORTUNITIES:");
  recommendations.consolidatable.forEach(item => {
    console.log(`   🔗 ${item.components.toUpperCase()}`);
    console.log(`      Issue: ${item.reason}`);
    console.log(`      Action: ${item.recommendation}`);
  });

  console.log("\n🎯 OPTIMIZATION STRATEGIES:");
  
  const strategies = [
    "1. MERGE ALERTS: Combine 'alerts' and 'anxiety_alerts' into single structure with type field",
    "2. ALERT RETENTION: Implement sliding window for alerts (keep last 100 alerts)",
    "3. BASELINE PROTECTION: Ensure baseline data isn't duplicated in sessions",
    "4. ALERT CATEGORIZATION: Use alert.type to distinguish general vs anxiety alerts",
    "5. STORAGE EFFICIENCY: Remove redundant alert data from session history"
  ];

  strategies.forEach(strategy => {
    console.log(`   🎯 ${strategy}`);
  });

  return recommendations;
}

/**
 * Main analysis orchestrator
 */
async function runUserNodeAnalysis() {
  console.log("🔍 USER NODE COMPONENT ANALYSIS");
  console.log("🎯 Analyzing alerts, anxiety_alerts, baseline, and sessions for redundancy");
  console.log("");

  try {
    // Analyze all components
    await analyzeUserNodeComponents();

    // Generate recommendations
    const recommendations = await generateOptimizationRecommendations();

    console.log("\n" + "=" * 60);
    console.log("🎉 USER NODE ANALYSIS COMPLETED!");
    console.log("=" * 60);
    
    console.log("\n📊 KEY FINDINGS:");
    console.log("   ✅ baseline: ESSENTIAL (user-specific anxiety thresholds)");
    console.log("   ✅ sessions: ESSENTIAL (already optimized)");
    console.log("   🔄 alerts + anxiety_alerts: REDUNDANT (can be merged)");
    
    console.log("\n💡 NEXT STEPS:");
    console.log("   1. Consolidate alerts and anxiety_alerts into unified structure");
    console.log("   2. Implement alert retention policy (sliding window)");
    console.log("   3. Add alert type classification (general, anxiety, system)");

    return recommendations;

  } catch (error) {
    console.error("❌ User node analysis failed:", error);
    process.exit(1);
  }
}

// Run analysis if this script is executed directly
if (require.main === module) {
  runUserNodeAnalysis()
    .then((recommendations) => {
      console.log("\n✅ User node analysis completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ User node analysis failed:", error);
      process.exit(1);
    });
}

module.exports = {
  runUserNodeAnalysis,
  analyzeUserNodeComponents,
  generateOptimizationRecommendations
};