/**
 * Severity test against the real baseline (73 BPM) for user
 * 8b5f8b4a-bd2e-44ed-833c-ffd5d9a1475b / device AnxieEase001.
 *
 * Usage: node test_severity_baseline73.js <mild|moderate|severe|critical>
 *
 * Sustains an elevated heart rate for just over 120s (the function's
 * MIN_SUSTAINED_DURATION_SECONDS) so realTimeSustainedAnxietyDetection
 * actually has a chance to fire, then checks whether an alert/notification
 * was produced, then resets the device back to baseline.
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
  });
}

const db = admin.database();

const USER_ID = "8b5f8b4a-bd2e-44ed-833c-ffd5d9a1475b";
const DEVICE_ID = "AnxieEase001";
const BASELINE_HR = 73;

// Midpoint of each severity band (percentage above baseline), per
// getSeverityLevel() in realTimeSustainedAnxietyDetection.js:
//   mild: 20-29%, moderate: 30-49%, severe: 50-79%, critical: 80%+
const SEVERITY_HR = {
  mild: Math.round(BASELINE_HR * 1.25), // ~91 BPM
  moderate: Math.round(BASELINE_HR * 1.4), // ~102 BPM
  severe: Math.round(BASELINE_HR * 1.65), // ~120 BPM
  critical: Math.round(BASELINE_HR * 1.9), // ~139 BPM
};

const TOTAL_SECONDS = 130; // > 120s required sustained duration, +10s buffer
const INTERVAL_SECONDS = 3;

async function clearRateLimits() {
  await db.ref(`/users/${USER_ID}/lastAnxietyNotification`).remove();
  await db.ref(`/rateLimits/${USER_ID}`).remove();
  console.log("🧹 Rate limits cleared for this user");
}

async function run(severity) {
  const hr = SEVERITY_HR[severity];
  if (!hr) {
    console.error(
      `❌ Unknown severity "${severity}". Use one of: mild, moderate, severe, critical`
    );
    process.exit(1);
  }

  console.log(`🧪 Testing "${severity}" severity (${hr} BPM, baseline ${BASELINE_HR} BPM, ~${Math.round(((hr - BASELINE_HR) / BASELINE_HR) * 100)}% above)\n`);

  // Confirm device assignment first
  const assignmentSnap = await db
    .ref(`/devices/${DEVICE_ID}/assignment`)
    .once("value");
  const assignment = assignmentSnap.val();
  if (!assignment || assignment.assignedUser !== USER_ID) {
    console.error(
      `❌ Device ${DEVICE_ID} is not currently assigned to ${USER_ID}. Aborting.`
    );
    console.error("   Current assignment:", assignment);
    process.exit(1);
  }
  console.log(`✅ Device assigned to this user, session: ${assignment.activeSessionId}\n`);

  await clearRateLimits();

  const currentRef = db.ref(`/devices/${DEVICE_ID}/current`);
  const steps = Math.ceil(TOTAL_SECONDS / INTERVAL_SECONDS);

  console.log(`💓 Sustaining ${hr} BPM for ~${TOTAL_SECONDS}s (${steps} updates every ${INTERVAL_SECONDS}s)...\n`);

  for (let i = 0; i < steps; i++) {
    const now = new Date();
    const ts = now.toISOString().slice(0, 19).replace("T", " "); // "YYYY-MM-DD HH:MM:SS"

    await currentRef.set({
      heartRate: hr + Math.floor(Math.random() * 2),
      timestamp: ts,
      spo2: 97 + Math.random() * 2,
      worn: 1,
      battPerc: 85,
    });

    const elapsed = (i + 1) * INTERVAL_SECONDS;
    process.stdout.write(
      `\r   [${elapsed}/${TOTAL_SECONDS}s] HR=${hr} BPM written at ${ts}   `
    );

    await new Promise((resolve) => setTimeout(resolve, INTERVAL_SECONDS * 1000));
  }

  console.log("\n\n✅ Sustained sequence complete. Waiting 15s for the Cloud Function to process the final update...\n");
  await new Promise((resolve) => setTimeout(resolve, 15000));

  console.log("📋 Checking for a resulting alert/notification...");
  const alertsSnap = await db
    .ref(`/users/${USER_ID}/alerts`)
    .orderByChild("timestamp")
    .limitToLast(1)
    .once("value");

  if (alertsSnap.exists()) {
    const alerts = alertsSnap.val();
    const id = Object.keys(alerts)[0];
    console.log("🚨 Alert found:", JSON.stringify(alerts[id], null, 2));
  } else {
    console.log("⚠️  No alert under /users/<id>/alerts yet.");
    console.log("   Check function logs:");
    console.log(
      "   npx firebase-tools functions:log --only realTimeSustainedAnxietyDetection -n 30"
    );
  }

  console.log("\n🔄 Resetting heart rate back to baseline...");
  await currentRef.update({
    heartRate: BASELINE_HR,
    timestamp: new Date().toISOString().slice(0, 19).replace("T", " "),
  });
  console.log(`✅ Reset to ${BASELINE_HR} BPM`);

  process.exit(0);
}

const severity = process.argv[2];
if (!severity) {
  console.log("Usage: node test_severity_baseline73.js <mild|moderate|severe|critical>");
  console.log(`\nThresholds for baseline ${BASELINE_HR} BPM:`);
  for (const [level, hr] of Object.entries(SEVERITY_HR)) {
    console.log(`   ${level}: ${hr} BPM`);
  }
  process.exit(0);
}

run(severity).catch((error) => {
  console.error("❌ Error during test:", error);
  process.exit(1);
});
