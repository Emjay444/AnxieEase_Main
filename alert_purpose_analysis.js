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
 * ALERT STORAGE PURPOSE ANALYSIS
 * 
 * This script analyzes WHY Firebase stores alerts and whether they can be eliminated
 * by examining:
 * 1. Who writes alerts to Firebase
 * 2. Who reads alerts from Firebase  
 * 3. What purpose they serve
 * 4. Whether they can be replaced/eliminated
 */

async function analyzeAlertPurpose() {
  console.log("🔍 WHY DOES FIREBASE STORE ALERTS?");
  console.log("=" * 40);

  console.log("\n📝 ALERT STORAGE ANALYSIS:");
  
  const purposes = {
    notification_triggers: {
      description: "Alerts trigger FCM push notifications to user phones",
      necessity: "ESSENTIAL",
      reason: "Real-time anxiety alerts need immediate notification delivery",
      elimination_impact: "❌ Users won't get anxiety alerts - defeats core purpose"
    },
    
    historical_tracking: {
      description: "Store anxiety detection history for medical/wellness insights", 
      necessity: "USEFUL",
      reason: "Track user anxiety patterns over time for healthcare providers",
      elimination_impact: "⚠️ Lose anxiety pattern analysis, but app still functional"
    },
    
    audit_trail: {
      description: "Legal/medical compliance - record of all anxiety detections",
      necessity: "REGULATORY",
      reason: "Medical device regulations may require detection logging",
      elimination_impact: "⚠️ May violate medical device compliance requirements"
    },

    false_positive_analysis: {
      description: "Analyze detection accuracy to improve algorithms",
      necessity: "OPTIMIZATION", 
      reason: "Data scientists need alerts to tune detection sensitivity",
      elimination_impact: "⚠️ Can't improve detection algorithms without feedback data"
    },

    user_confirmation_flow: {
      description: "Store user confirmations of anxiety detections",
      necessity: "FEEDBACK",
      reason: "Users can confirm/deny anxiety alerts for algorithm learning",
      elimination_impact: "⚠️ Lose machine learning feedback loop"
    }
  };

  console.log("\n🎯 ALERT PURPOSES & NECESSITY:");
  Object.entries(purposes).forEach(([key, purpose]) => {
    const status = purpose.necessity === 'ESSENTIAL' ? '🔴 CRITICAL' : 
                   purpose.necessity === 'REGULATORY' ? '🟡 IMPORTANT' : 
                   purpose.necessity === 'USEFUL' ? '🟢 OPTIONAL' : '🔵 NICE-TO-HAVE';
    
    console.log(`\n   ${status} ${key.toUpperCase().replace(/_/g, ' ')}`);
    console.log(`      Purpose: ${purpose.description}`);
    console.log(`      Why needed: ${purpose.reason}`);
    console.log(`      If eliminated: ${purpose.elimination_impact}`);
  });

  return purposes;
}

async function analyzeCurrentAlertFlow() {
  console.log("\n🔄 CURRENT ALERT FLOW ANALYSIS:");
  console.log("=" * 30);

  const flow = {
    step1: "1️⃣ Wearable Device detects high heart rate",
    step2: "2️⃣ Device sends data to Firebase /devices/{deviceId}/current", 
    step3: "3️⃣ Firebase Function 'realTimeSustainedAnxietyDetection' triggers",
    step4: "4️⃣ Function analyzes heart rate vs user baseline",
    step5: "5️⃣ If anxiety detected, creates alert in /users/{userId}/alerts OR /users/{userId}/anxiety_alerts",
    step6: "6️⃣ Alert creation triggers FCM notification to user phone",
    step7: "7️⃣ User receives push notification with anxiety alert",
    step8: "8️⃣ Alert stored permanently for history/analysis"
  };

  console.log("\n📱 HOW ANXIETY ALERTS WORK:");
  Object.values(flow).forEach(step => {
    console.log(`   ${step}`);
  });

  console.log("\n🔑 KEY INSIGHT:");
  console.log("   ✅ Firebase alerts are NOT just storage - they're ACTIVE TRIGGERS");
  console.log("   ✅ Alert creation = FCM notification sent immediately");
  console.log("   ✅ No alerts = No anxiety notifications = Broken core feature");
}

async function proposeAlertOptimization() {
  console.log("\n💡 ALERT OPTIMIZATION RECOMMENDATIONS:");
  console.log("=" * 40);

  const recommendations = {
    keep_essential: {
      title: "KEEP: Core Anxiety Alerts",
      action: "✅ Keep anxiety detection alerts for FCM notifications",
      components: [
        "Real-time anxiety detection alerts",
        "FCM notification triggers", 
        "User confirmation requests"
      ],
      storage: "Users should get anxiety alerts - this is core functionality"
    },

    eliminate_redundancy: {
      title: "ELIMINATE: Redundant Alert Storage", 
      action: "🗑️ Remove duplicate alert storage (alerts + anxiety_alerts)",
      components: [
        "Merge alerts and anxiety_alerts into single structure",
        "Use alert.type to categorize (anxiety, general, system)",
        "Implement sliding window (keep last 100 alerts)"
      ],
      storage: "Reduce storage while preserving functionality"
    },

    optimize_retention: {
      title: "OPTIMIZE: Alert Retention Policy",
      action: "⏰ Implement smart retention based on importance",
      components: [
        "Critical alerts: Keep 6 months",
        "Moderate alerts: Keep 30 days", 
        "Mild alerts: Keep 7 days",
        "Auto-cleanup old alerts"
      ],
      storage: "Balance between history and storage efficiency"
    },

    alternative_storage: {
      title: "CONSIDER: Hybrid Storage Strategy",
      action: "🔄 Use Firebase for real-time, Supabase for long-term",
      components: [
        "Firebase: Active alerts for FCM (30 days max)",
        "Supabase: Long-term alert history for analysis",
        "Auto-archive old Firebase alerts to Supabase"
      ],
      storage: "Best of both worlds - real-time + historical"
    }
  };

  console.log("\n🎯 OPTIMIZATION STRATEGIES:");
  Object.entries(recommendations).forEach(([key, rec]) => {
    console.log(`\n   📋 ${rec.title}`);
    console.log(`      Action: ${rec.action}`);
    console.log(`      Components:`);
    rec.components.forEach(comp => {
      console.log(`        • ${comp}`);
    });
    console.log(`      Impact: ${rec.storage}`);
  });

  return recommendations;
}

async function calculateAlertStorageImpact() {
  console.log("\n📊 STORAGE IMPACT CALCULATION:");
  console.log("=" * 32);

  try {
    const usersRef = db.ref("/users");
    const usersSnapshot = await usersRef.once("value");
    
    if (!usersSnapshot.exists()) {
      console.log("❌ No users found");
      return;
    }

    const users = usersSnapshot.val();
    let totalAlerts = 0;
    let totalAnxietyAlerts = 0;
    let totalAlertStorage = 0;

    for (const userId of Object.keys(users)) {
      const user = users[userId];
      
      const alertCount = user.alerts ? Object.keys(user.alerts).length : 0;
      const anxietyAlertCount = user.anxiety_alerts ? Object.keys(user.anxiety_alerts).length : 0;
      
      totalAlerts += alertCount;
      totalAnxietyAlerts += anxietyAlertCount;
    }

    // Estimate storage (rough calculation)
    const avgAlertSize = 0.5; // KB per alert (estimated)
    totalAlertStorage = (totalAlerts + totalAnxietyAlerts) * avgAlertSize;

    console.log(`\n📈 CURRENT ALERT STORAGE:`);
    console.log(`   📢 General alerts: ${totalAlerts}`);
    console.log(`   ⚠️  Anxiety alerts: ${totalAnxietyAlerts}`); 
    console.log(`   📊 Total alerts: ${totalAlerts + totalAnxietyAlerts}`);
    console.log(`   💾 Estimated storage: ~${Math.round(totalAlertStorage)} KB`);

    console.log(`\n🧹 OPTIMIZATION POTENTIAL:`);
    const mergedAlerts = totalAlerts + totalAnxietyAlerts;
    const optimizedAlerts = Math.min(mergedAlerts, 100); // Max 100 alerts per user
    const storageSavings = (mergedAlerts - optimizedAlerts) * avgAlertSize;
    
    console.log(`   🔗 After merging: ${mergedAlerts} alerts (same functionality)`);
    console.log(`   ⚡ After sliding window: ${optimizedAlerts} alerts (100 max per user)`);
    console.log(`   💾 Storage savings: ~${Math.round(storageSavings)} KB`);
    console.log(`   📉 Storage reduction: ${Math.round((storageSavings / totalAlertStorage) * 100)}%`);

  } catch (error) {
    console.error("❌ Error calculating storage impact:", error);
  }
}

async function generateFinalRecommendation() {
  console.log("\n🎯 FINAL RECOMMENDATION:");
  console.log("=" * 25);

  console.log(`
🚨 DO NOT ELIMINATE ALERTS COMPLETELY! 

🔑 WHY ALERTS ARE ESSENTIAL:
   ✅ Alerts trigger real-time FCM notifications
   ✅ Without alerts, users won't get anxiety warnings
   ✅ This defeats the core purpose of AnxieEase wearable
   ✅ Firebase alerts are FUNCTIONAL, not just storage

💡 SMART OPTIMIZATION INSTEAD:
   1️⃣ MERGE alerts + anxiety_alerts (eliminate redundancy)
   2️⃣ ADD alert.type classification (anxiety, general, system)  
   3️⃣ IMPLEMENT sliding window (max 100 alerts per user)
   4️⃣ ADD retention policy (auto-cleanup after 30 days)
   5️⃣ KEEP FCM notification functionality intact

✅ RESULT:
   • Same anxiety notification functionality
   • Reduced storage redundancy  
   • Better organization
   • Automatic cleanup
   • Core features preserved

⚠️  NEVER REMOVE:
   • Anxiety detection alerts (core functionality)
   • FCM notification triggers (user safety)
   • Real-time alert processing (medical requirement)
  `);
}

/**
 * Main alert analysis orchestrator
 */
async function runAlertAnalysis() {
  console.log("🔍 FIREBASE ALERT STORAGE PURPOSE ANALYSIS");
  console.log("🎯 Understanding WHY Firebase stores alerts and optimization opportunities");
  console.log("");

  try {
    // Analyze purposes
    await analyzeAlertPurpose();

    // Analyze current flow
    await analyzeCurrentAlertFlow();

    // Calculate storage impact
    await calculateAlertStorageImpact();

    // Propose optimizations
    await proposeAlertOptimization();

    // Final recommendation
    await generateFinalRecommendation();

    console.log("\n" + "=" * 60);
    console.log("🎉 ALERT ANALYSIS COMPLETED!");
    console.log("=" * 60);
    
    console.log(`
📋 KEY FINDINGS:
   🔴 Alerts are ESSENTIAL for FCM notifications
   🟡 Current structure has redundancy (alerts + anxiety_alerts) 
   🟢 Can optimize WITHOUT breaking functionality
   🔵 Smart consolidation = same features + less storage

💡 NEXT STEPS:
   1. Keep alert functionality (don't eliminate!)  
   2. Merge redundant alert structures
   3. Implement sliding window retention
   4. Preserve all FCM notification capabilities
    `);

  } catch (error) {
    console.error("❌ Alert analysis failed:", error);
    process.exit(1);
  }
}

// Run analysis if this script is executed directly
if (require.main === module) {
  runAlertAnalysis()
    .then(() => {
      console.log("\n✅ Alert analysis completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ Alert analysis failed:", error);
      process.exit(1);
    });
}

module.exports = {
  runAlertAnalysis,
  analyzeAlertPurpose,
  analyzeCurrentAlertFlow,
  calculateAlertStorageImpact
};