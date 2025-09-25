/**
 * 🚀 FIREBASE CLEANUP RUNNER
 * 
 * Easy-to-use script for running Firebase cleanup tasks
 * Run with: node run_cleanup.js [mode]
 */

const { FirebaseCleanup, CLEANUP_CONFIG } = require('./firebase_auto_cleanup.js');
const { FirebaseNodeAnalyzer } = require('./firebase_node_analyzer.js');
const { getCurrentConfig, validateConfig } = require('./firebase_cleanup_config.js');

async function runCleanup(mode = 'analyze') {
  console.log("🧹 ANXIEEASE FIREBASE CLEANUP");
  console.log("=============================");
  
  const config = getCurrentConfig();
  console.log(`📋 Using profile: ${config.PROFILE_NAME}`);
  
  // Validate configuration
  const warnings = validateConfig();
  if (warnings.length > 0) {
    console.log("\n⚠️  CONFIGURATION WARNINGS:");
    warnings.forEach(warning => console.log(`  ${warning}`));
    console.log("");
  }
  
  switch (mode.toLowerCase()) {
    case 'analyze':
    case 'analysis':
      await runAnalysis();
      break;
      
    case 'preview':
    case 'dry-run':
      await runPreview();
      break;
      
    case 'clean':
    case 'cleanup':
      await runFullCleanup();
      break;
      
    case 'quick':
    case 'quick-clean':
      await runQuickCleanup();
      break;
      
    default:
      showUsage();
  }
}

async function runAnalysis() {
  console.log("\n🔍 RUNNING DATABASE ANALYSIS");
  console.log("============================");
  
  const analyzer = new FirebaseNodeAnalyzer();
  const results = await analyzer.analyzeDatabase();
  
  console.log("\n📊 ANALYSIS COMPLETE");
  console.log("===================");
  console.log("Review the results above and choose your next action:");
  console.log("• node run_cleanup.js preview    - Preview cleanup actions");
  console.log("• node run_cleanup.js quick      - Remove unnecessary nodes");
  console.log("• node run_cleanup.js clean      - Full cleanup with current config");
}

async function runPreview() {
  console.log("\n👀 RUNNING CLEANUP PREVIEW");
  console.log("==========================");
  
  // Temporarily set DRY_RUN to true for preview
  const originalDryRun = CLEANUP_CONFIG.DRY_RUN;
  CLEANUP_CONFIG.DRY_RUN = true;
  
  const cleanup = new FirebaseCleanup();
  await cleanup.runFullCleanup();
  
  // Restore original setting
  CLEANUP_CONFIG.DRY_RUN = originalDryRun;
  
  console.log("\n🎯 PREVIEW COMPLETE");
  console.log("==================");
  console.log("If you're satisfied with the preview:");
  console.log("• node run_cleanup.js clean      - Run actual cleanup");
}

async function runFullCleanup() {
  console.log("\n🧹 RUNNING FULL CLEANUP");
  console.log("=======================");
  
  const config = getCurrentConfig();
  
  if (config.DRY_RUN) {
    console.log("ℹ️  DRY_RUN is enabled - no actual changes will be made");
  } else {
    console.log("⚠️  LIVE MODE - Changes will be permanent!");
    console.log("Press Ctrl+C to cancel or wait 5 seconds to continue...");
    
    // Give user chance to cancel
    await new Promise(resolve => setTimeout(resolve, 5000));
  }
  
  const cleanup = new FirebaseCleanup();
  const report = await cleanup.runFullCleanup();
  
  console.log("\n✅ CLEANUP COMPLETE");
  console.log("==================");
  console.log(`Total deletions: ${report.totalDeletions}`);
  console.log(`Errors: ${report.errors.length}`);
}

async function runQuickCleanup() {
  console.log("\n⚡ RUNNING QUICK CLEANUP");
  console.log("=======================");
  console.log("This will remove obviously unnecessary nodes (test data, etc.)");
  
  // First analyze to find issues
  const analyzer = new FirebaseNodeAnalyzer();
  await analyzer.analyzeDatabase();
  
  // Then perform quick cleanup
  console.log("\n🧹 Removing unnecessary nodes...");
  const removedCount = await analyzer.performQuickCleanup(false);
  
  console.log("\n✅ QUICK CLEANUP COMPLETE");
  console.log("=========================");
  console.log(`Removed ${removedCount} unnecessary nodes`);
  console.log("For comprehensive cleanup, run: node run_cleanup.js clean");
}

function showUsage() {
  console.log("\n📖 USAGE");
  console.log("========");
  console.log("node run_cleanup.js [mode]");
  console.log("");
  console.log("Available modes:");
  console.log("  analyze   - Analyze database structure (default)");
  console.log("  preview   - Preview cleanup actions without changes");
  console.log("  clean     - Run full cleanup with current configuration");
  console.log("  quick     - Remove obviously unnecessary nodes");
  console.log("");
  console.log("Examples:");
  console.log("  node run_cleanup.js analyze    # Safe analysis only");
  console.log("  node run_cleanup.js preview    # See what would be cleaned");
  console.log("  node run_cleanup.js quick      # Remove test data and duplicates");
  console.log("  node run_cleanup.js clean      # Full cleanup");
  console.log("");
  console.log("Configuration:");
  console.log("  Edit firebase_cleanup_config.js to change cleanup settings");
  console.log(`  Current profile: ${getCurrentConfig().PROFILE_NAME}`);
}

// Get command line argument
const mode = process.argv[2] || 'analyze';

// Run the cleanup
runCleanup(mode).catch(error => {
  console.error("❌ Cleanup failed:", error.message);
  process.exit(1);
});

module.exports = { runCleanup };