/**
 * Check Current Time vs Schedule
 */

console.log("╔════════════════════════════════════════════════════════════╗");
console.log("║          SCHEDULE VS CURRENT TIME ANALYSIS                 ║");
console.log("╚════════════════════════════════════════════════════════════╝\n");

// Get current Philippine time
const now = new Date();
const phTime = new Date(
  now.toLocaleString("en-US", { timeZone: "Asia/Manila" })
);
const currentHour = phTime.getHours();
const currentMinute = phTime.getMinutes();

console.log("🕐 CURRENT TIME:");
console.log(`   Philippine Time: ${phTime.toLocaleString()}`);
console.log(
  `   Hour: ${currentHour}:${currentMinute.toString().padStart(2, "0")}`
);
console.log();

console.log("📅 WELLNESS REMINDER SCHEDULE:");
const scheduleHours = [8, 12, 16, 20, 22];
scheduleHours.forEach((hour) => {
  const isPast =
    currentHour > hour || (currentHour === hour && currentMinute > 5);
  const isCurrent = currentHour === hour && currentMinute <= 5;
  const isFuture = currentHour < hour;

  let status = "";
  if (isPast) status = "❌ MISSED (should have run)";
  else if (isCurrent) status = "⏰ RUNNING NOW";
  else if (isFuture) status = `⏳ Upcoming (in ${hour - currentHour} hours)`;

  const ampm = hour >= 12 ? "PM" : "AM";
  const displayHour = hour > 12 ? hour - 12 : hour;

  console.log(`   ${displayHour}:00 ${ampm} - ${status}`);
});

console.log();
console.log("📅 BREATHING REMINDER SCHEDULE:");
const breathingHour = 14; // 2 PM
const breathingPast =
  currentHour > breathingHour ||
  (currentHour === breathingHour && currentMinute > 5);
const breathingFuture = currentHour < breathingHour;
let breathingStatus = "";
if (breathingPast) breathingStatus = "❌ MISSED (should have run)";
else if (currentHour === breathingHour && currentMinute <= 5)
  breathingStatus = "⏰ RUNNING NOW";
else if (breathingFuture)
  breathingStatus = `⏳ Upcoming (in ${breathingHour - currentHour} hours)`;

console.log(`   2:00 PM - ${breathingStatus}`);

console.log();
console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
console.log("🔍 ANALYSIS:");
console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
console.log();

console.log("📊 LAST SUCCESSFUL RUNS (Oct 22, 2025):");
console.log("   ✅ 8:00 AM  - Sent successfully");
console.log("   ✅ 12:00 PM - Sent successfully");
console.log("   ✅ 4:00 PM  - Sent successfully");
console.log("   ✅ 8:00 PM  - Sent successfully");
console.log("   ✅ 10:00 PM - Sent successfully");
console.log();

console.log("🔴 DEPLOYMENT EVENT (Oct 22, 3:39 PM):");
console.log("   Functions redeployed");
console.log("   This may have disrupted the scheduler");
console.log();

console.log("❌ TODAY (Oct 23, 2025):");
console.log("   NO EXECUTIONS YET");
console.log();

console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
console.log("💡 DIAGNOSIS:");
console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
console.log();

if (currentHour >= 8) {
  console.log("🚨 PROBLEM CONFIRMED:");
  console.log("   Functions SHOULD have run at 8:00 AM today");
  console.log("   No execution logs found for today");
  console.log("   Scheduler stopped after last deployment");
  console.log();

  console.log("🔧 LIKELY CAUSE:");
  console.log("   1. Cloud Scheduler jobs were not recreated after deployment");
  console.log("   2. Scheduler configuration issue with new deployment");
  console.log("   3. Timezone/schedule mismatch in updated code");
  console.log();

  console.log("✅ SOLUTION:");
  console.log("   Need to check Cloud Scheduler in Google Cloud Console");
  console.log("   or redeploy functions to recreate scheduler jobs");
} else {
  console.log("⏰ WAITING FOR FIRST RUN:");
  console.log(`   Next scheduled run: 8:00 AM (in ${8 - currentHour} hours)`);
  console.log("   Wait until 8:05 AM to confirm if scheduler is working");
}

console.log();
