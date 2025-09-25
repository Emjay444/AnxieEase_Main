/**
 * 🔧 FIREBASE CLEANUP CONFIGURATION
 * 
 * Easy-to-modify settings for Firebase auto-cleanup system
 * Adjust these values based on your storage needs and data importance
 */

const CLEANUP_PROFILES = {
  // 🧪 DEVELOPMENT MODE - Aggressive cleanup for testing
  DEVELOPMENT: {
    DEVICE_HISTORY_RETENTION: 1,        // 1 day
    USER_SESSION_RETENTION: 3,          // 3 days  
    ANXIETY_ALERTS_RETENTION: 7,        // 1 week
    TEST_DATA_RETENTION: 0,             // Remove immediately
    
    CLEANUP_DEVICE_HISTORY: true,
    CLEANUP_OLD_SESSIONS: true,
    CLEANUP_OLD_ALERTS: false,          // Keep for development analysis
    CLEANUP_TEST_DATA: true,
    CLEANUP_DUPLICATE_HISTORY: true,
    
    DRY_RUN: false,
    MAX_DELETIONS_PER_RUN: 500,
    BACKUP_BEFORE_DELETE: true,
  },

  // 🏥 PRODUCTION MODE - Conservative cleanup for real users
  PRODUCTION: {
    DEVICE_HISTORY_RETENTION: 7,        // 1 week
    USER_SESSION_RETENTION: 30,         // 1 month
    ANXIETY_ALERTS_RETENTION: 90,       // 3 months  
    TEST_DATA_RETENTION: 0,             // Remove immediately
    
    CLEANUP_DEVICE_HISTORY: true,
    CLEANUP_OLD_SESSIONS: true,
    CLEANUP_OLD_ALERTS: true,
    CLEANUP_TEST_DATA: true,
    CLEANUP_DUPLICATE_HISTORY: true,
    
    DRY_RUN: false,
    MAX_DELETIONS_PER_RUN: 1000,
    BACKUP_BEFORE_DELETE: true,
  },

  // 🔒 SAFE MODE - Preview only, no actual deletions
  SAFE_PREVIEW: {
    DEVICE_HISTORY_RETENTION: 7,
    USER_SESSION_RETENTION: 30,
    ANXIETY_ALERTS_RETENTION: 90,
    TEST_DATA_RETENTION: 0,
    
    CLEANUP_DEVICE_HISTORY: true,
    CLEANUP_OLD_SESSIONS: true,
    CLEANUP_OLD_ALERTS: true,
    CLEANUP_TEST_DATA: true,
    CLEANUP_DUPLICATE_HISTORY: true,
    
    DRY_RUN: true,                      // Only preview, don't delete
    MAX_DELETIONS_PER_RUN: 1000,
    BACKUP_BEFORE_DELETE: false,        // No need for backup in preview mode
  },

  // 🚨 EMERGENCY MODE - Aggressive cleanup for storage crisis
  EMERGENCY: {
    DEVICE_HISTORY_RETENTION: 1,        // 1 day only
    USER_SESSION_RETENTION: 7,          // 1 week only
    ANXIETY_ALERTS_RETENTION: 30,       // 1 month only
    TEST_DATA_RETENTION: 0,             // Remove everything
    
    CLEANUP_DEVICE_HISTORY: true,
    CLEANUP_OLD_SESSIONS: true,
    CLEANUP_OLD_ALERTS: true,
    CLEANUP_TEST_DATA: true,
    CLEANUP_DUPLICATE_HISTORY: true,
    
    DRY_RUN: false,
    MAX_DELETIONS_PER_RUN: 5000,       // Higher limit for emergency
    BACKUP_BEFORE_DELETE: true,         // Critical - always backup
  }
};

// 🎯 CURRENT ACTIVE PROFILE
// Change this to switch between cleanup modes
const ACTIVE_PROFILE = 'PRODUCTION'; // Options: DEVELOPMENT, PRODUCTION, SAFE_PREVIEW, EMERGENCY

// 📊 STORAGE THRESHOLDS
const STORAGE_THRESHOLDS = {
  WARNING_SIZE_MB: 50,      // Warn when Firebase exceeds 50MB
  CRITICAL_SIZE_MB: 80,     // Critical when Firebase exceeds 80MB
  EMERGENCY_SIZE_MB: 95,    // Emergency cleanup at 95MB
};

// 📅 SCHEDULE CONFIGURATION
const CLEANUP_SCHEDULE = {
  // How often to run cleanup
  FREQUENCY: 'WEEKLY',        // OPTIONS: DAILY, WEEKLY, MONTHLY
  
  // What day/time to run (for scheduling tools)
  DAY_OF_WEEK: 'SUNDAY',      // For weekly cleanup
  HOUR: 2,                    // 2 AM (less likely to interfere with users)
  TIMEZONE: 'UTC',
  
  // Emergency cleanup triggers
  AUTO_EMERGENCY_CLEANUP: true,   // Automatically run emergency cleanup if storage critical
  STORAGE_CHECK_INTERVAL: 'HOURLY', // How often to check storage usage
};

// 🔔 NOTIFICATION SETTINGS
const NOTIFICATION_CONFIG = {
  SEND_CLEANUP_REPORTS: true,
  SEND_STORAGE_WARNINGS: true,
  SEND_ERROR_ALERTS: true,
  
  // Where to send notifications (implement as needed)
  EMAIL_NOTIFICATIONS: false,
  SLACK_NOTIFICATIONS: false,
  CONSOLE_ONLY: true,
};

// 🛡️ SAFETY RULES
const SAFETY_RULES = {
  // Never delete data newer than this (in hours)
  MINIMUM_DATA_AGE_HOURS: 1,
  
  // Always keep at least this many recent entries per category
  MINIMUM_KEEP_COUNT: {
    DEVICE_HISTORY: 100,        // Always keep last 100 device readings
    USER_SESSIONS: 5,           // Always keep last 5 sessions per user
    ANXIETY_ALERTS: 10,         // Always keep last 10 alerts per user
  },
  
  // Refuse to delete more than this percentage in one run
  MAX_DELETE_PERCENTAGE: 50,    // Never delete more than 50% of data at once
  
  // Backup requirements
  REQUIRE_BACKUP_FOR_LARGE_DELETES: true,
  LARGE_DELETE_THRESHOLD: 100,  // Require backup if deleting 100+ items
};

// 🏷️ NODE IDENTIFICATION
// Patterns to identify different types of data nodes
const NODE_PATTERNS = {
  TEST_NODES: [
    /^.*\/testNotification$/,
    /^.*\/test_.*$/,
    /^.*\/debug.*$/,
    /^.*\/development.*$/,
  ],
  
  HISTORY_NODES: [
    /^\/devices\/.*\/history\/.*$/,
    /^\/users\/.*\/sessions\/.*\/data\/.*$/,
  ],
  
  SESSION_NODES: [
    /^\/users\/.*\/sessions\/.*$/,
  ],
  
  ALERT_NODES: [
    /^\/users\/.*\/alerts\/.*$/,
  ],
};

// Export current configuration
function getCurrentConfig() {
  const profile = CLEANUP_PROFILES[ACTIVE_PROFILE];
  
  if (!profile) {
    throw new Error(`Invalid active profile: ${ACTIVE_PROFILE}`);
  }
  
  return {
    ...profile,
    PROFILE_NAME: ACTIVE_PROFILE,
    STORAGE_THRESHOLDS,
    CLEANUP_SCHEDULE,
    NOTIFICATION_CONFIG,
    SAFETY_RULES,
    NODE_PATTERNS,
  };
}

// Validate configuration
function validateConfig() {
  const config = getCurrentConfig();
  const warnings = [];
  
  // Check for potentially dangerous settings
  if (!config.DRY_RUN && config.PROFILE_NAME === 'EMERGENCY') {
    warnings.push('⚠️  Emergency mode with DRY_RUN=false - This will delete a lot of data!');
  }
  
  if (config.ANXIETY_ALERTS_RETENTION < 30 && config.PROFILE_NAME === 'PRODUCTION') {
    warnings.push('⚠️  Anxiety alerts retention < 30 days in production mode');
  }
  
  if (config.MAX_DELETIONS_PER_RUN > 1000 && !config.BACKUP_BEFORE_DELETE) {
    warnings.push('⚠️  High deletion limit without backup enabled');
  }
  
  return warnings;
}

// Quick configuration switcher
function switchProfile(newProfile) {
  if (!CLEANUP_PROFILES[newProfile]) {
    throw new Error(`Unknown profile: ${newProfile}`);
  }
  
  // Note: This would need to modify the file or use environment variables in practice
  console.log(`🔄 Would switch from ${ACTIVE_PROFILE} to ${newProfile}`);
  console.log(`To apply: Change ACTIVE_PROFILE in cleanup_config.js to '${newProfile}'`);
}

module.exports = {
  getCurrentConfig,
  validateConfig,
  switchProfile,
  CLEANUP_PROFILES,
  ACTIVE_PROFILE,
  STORAGE_THRESHOLDS,
  CLEANUP_SCHEDULE,
  NOTIFICATION_CONFIG,
  SAFETY_RULES,
  NODE_PATTERNS,
};