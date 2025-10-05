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
 * Read and display all system node contents
 */
async function readSystemNodes() {
  console.log("🔍 READING SYSTEM NODES CONTENT");
  console.log("=" * 50);

  try {
    const systemRef = db.ref("/system");
    const systemSnapshot = await systemRef.once("value");
    
    if (!systemSnapshot.exists()) {
      console.log("❌ No system nodes found");
      return;
    }

    const systemData = systemSnapshot.val();
    const systemNodes = Object.keys(systemData);
    
    console.log(`📊 Found ${systemNodes.length} system nodes:`);
    console.log(`   ${systemNodes.join(", ")}`);
    console.log("");

    // Read each system node
    for (const nodeName of systemNodes) {
      console.log(`\n📁 SYSTEM NODE: /${nodeName}`);
      console.log("─".repeat(60));
      
      const nodeData = systemData[nodeName];
      
      if (typeof nodeData === 'object' && nodeData !== null) {
        // Pretty print the object
        console.log(JSON.stringify(nodeData, null, 2));
      } else {
        console.log(nodeData);
      }
      
      // Add separator between nodes
      console.log("\n" + "─".repeat(60));
    }

    // Summary
    console.log("\n" + "=" * 60);
    console.log("📊 SYSTEM NODES SUMMARY");
    console.log("=" * 60);
    
    systemNodes.forEach(nodeName => {
      const nodeData = systemData[nodeName];
      let description = "";
      
      switch(nodeName) {
        case "backups":
          const backupCount = Object.keys(nodeData || {}).length;
          description = `${backupCount} backup entries`;
          break;
        case "cleanup_logs":
          const logCount = Object.keys(nodeData || {}).length;
          description = `${logCount} cleanup log entries`;
          break;
        case "duplication_prevention":
          description = nodeData?.duplicationStatus || "Status tracking";
          break;
        case "session_management":
          description = nodeData?.policy || "Session management config";
          break;
        case "smart_cleanup_results":
          description = `Last cleanup: ${nodeData?.timestamp ? new Date(nodeData.timestamp).toLocaleString() : 'unknown'}`;
          break;
        default:
          if (typeof nodeData === 'object' && nodeData !== null) {
            const keyCount = Object.keys(nodeData).length;
            description = `${keyCount} entries`;
          } else {
            description = typeof nodeData;
          }
      }
      
      console.log(`   📁 ${nodeName}: ${description}`);
    });

  } catch (error) {
    console.error("❌ Error reading system nodes:", error);
    throw error;
  }
}

// Run if this script is executed directly
if (require.main === module) {
  readSystemNodes()
    .then(() => {
      console.log("\n✅ System nodes read completed successfully");
      process.exit(0);
    })
    .catch((error) => {
      console.error("❌ System nodes read failed:", error);
      process.exit(1);
    });
}

module.exports = {
  readSystemNodes
};