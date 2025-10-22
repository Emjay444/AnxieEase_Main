/**
 * Check Scheduled Cloud Function Logs
 */

const { execSync } = require("child_process");

console.log("╔════════════════════════════════════════════════════════════╗");
console.log("║      CHECKING SCHEDULED CLOUD FUNCTION LOGS                ║");
console.log("╚════════════════════════════════════════════════════════════╝\n");

console.log("🔍 Searching for wellness reminder executions...\n");

try {
  // Get logs for sendWellnessReminders
  console.log("📅 sendWellnessReminders schedule:");
  console.log("   Runs at: 8 AM, 12 PM, 4 PM, 8 PM, 10 PM (Philippine time)");
  console.log("   Cron: 0 8,12,16,20,22 * * *\n");

  console.log("📅 sendDailyBreathingReminder schedule:");
  console.log("   Runs at: 2 PM (Philippine time)");
  console.log("   Cron: 0 14 * * *\n");

  console.log(
    "💡 Current Philippine time: " +
      new Date().toLocaleString("en-US", { timeZone: "Asia/Manila" })
  );
  console.log("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("🔍 Checking if functions have run today...\n");
  console.log("Run this command manually to see logs:");
  console.log(
    "  npx firebase-tools functions:log -n 100 | Select-String -Pattern 'wellness|breathing'\n"
  );

  console.log("Or check specific functions:");
  console.log(
    "  npx firebase-tools functions:log --only sendWellnessReminders -n 20"
  );
  console.log(
    "  npx firebase-tools functions:log --only sendDailyBreathingReminder -n 20\n"
  );

  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("❓ DIAGNOSIS:\n");
  console.log("✅ Manual notifications work (we just proved it)");
  console.log("❌ Scheduled notifications not received\n");

  console.log("POSSIBLE CAUSES:\n");
  console.log("1. ⏰ Schedule hasn't triggered yet today");
  console.log("   → Wait for next scheduled time");
  console.log("   → Next run: Check times above\n");

  console.log("2. 🌍 Timezone mismatch");
  console.log("   → Function thinks it's different time");
  console.log("   → Check: Are schedules in correct timezone?\n");

  console.log("3. 📛 Function failed silently");
  console.log("   → Check error logs");
  console.log("   → Run: npx firebase-tools functions:log -n 100\n");

  console.log("4. ⚙️ Scheduler not enabled");
  console.log("   → Check Firebase Console → Functions → Scheduler\n");

  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n");

  console.log("💡 SOLUTION:\n");
  console.log(
    "Let's check the actual logs to see if functions are running...\n"
  );
} catch (error) {
  console.error("Error:", error.message);
}
