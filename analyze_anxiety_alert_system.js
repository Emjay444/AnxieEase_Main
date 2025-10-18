const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require("./service-account-key.json");
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL:
      "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

async function analyzeAnxietyAlertSystem() {
  console.log("🔍 ANXIETY ALERT SYSTEM ANALYSIS");
  console.log("=".repeat(80));
  console.log("");

  try {
    // 1. Check Device Assignment
    console.log("📱 STEP 1: DEVICE ASSIGNMENT CHECK");
    console.log("-".repeat(80));
    const deviceId = "AnxieEase001";
    const assignmentRef = db.ref(`/devices/${deviceId}/assignment`);
    const assignmentSnap = await assignmentRef.once("value");

    let userId = null;
    let sessionId = null;

    if (assignmentSnap.exists()) {
      const assignment = assignmentSnap.val();
      userId = assignment.assignedUser;
      sessionId = assignment.activeSessionId;
      console.log(`✅ Device ${deviceId} is assigned`);
      console.log(`   👤 User: ${userId}`);
      console.log(`   📋 Session: ${sessionId}`);
      console.log(`   ⏰ Assigned: ${new Date(assignment.assignedAt).toLocaleString()}`);
      console.log(`   📊 Status: ${assignment.status}`);
    } else {
      console.log(`❌ Device ${deviceId} is NOT assigned`);
      console.log(`   ⚠️  Anxiety alerts WILL NOT work without device assignment`);
      return;
    }

    console.log("");

    // 2. Check User Baseline
    console.log("💓 STEP 2: USER BASELINE CHECK");
    console.log("-".repeat(80));
    
    // Check device assignment baseline first (correct path)
    const deviceBaselineRef = db.ref(`/devices/${deviceId}/assignment/supabaseSync/baselineHR`);
    const deviceBaselineSnap = await deviceBaselineRef.once("value");
    
    // Also check user profile baseline (legacy path)
    const userBaselineRef = db.ref(`/users/${userId}/profile/baseline`);
    const userBaselineSnap = await userBaselineRef.once("value");

    let baseline = null;
    let baselineSource = null;
    
    if (deviceBaselineSnap.exists()) {
      const baselineHR = deviceBaselineSnap.val();
      baseline = { baselineHR };
      baselineSource = "device_assignment";
      console.log(`✅ User has baseline (from device assignment)`);
      console.log(`   📍 Path: /devices/${deviceId}/assignment/supabaseSync/baselineHR`);
      console.log(`   💓 Baseline HR: ${baselineHR} BPM`);
    } else if (userBaselineSnap.exists()) {
      baseline = userBaselineSnap.val();
      baselineSource = "user_profile";
      console.log(`✅ User has baseline (from user profile)`);
      console.log(`   � Path: /users/${userId}/profile/baseline`);
      console.log(`   �💓 Baseline HR: ${baseline.baselineHR} BPM`);
      console.log(`   📊 Sample Count: ${baseline.sampleCount}`);
      console.log(`   🎯 Confidence: ${baseline.confidence}%`);
      console.log(`   ⏰ Calculated: ${new Date(baseline.calculatedAt).toLocaleString()}`);
    } else {
      console.log(`❌ User does NOT have baseline`);
      console.log(`   ⚠️  Anxiety alerts WILL NOT work without baseline`);
      console.log(`   💡 Baseline should be in: /devices/${deviceId}/assignment/supabaseSync/baselineHR`);
      console.log(`   💡 Or in: /users/${userId}/profile/baseline`);
      return;
    }

    console.log("");

    // 3. Check Current Device Data
    console.log("📊 STEP 3: CURRENT DEVICE DATA CHECK");
    console.log("-".repeat(80));
    const currentDataRef = db.ref(`/devices/${deviceId}/current`);
    const currentDataSnap = await currentDataRef.once("value");

    if (currentDataSnap.exists()) {
      const current = currentDataSnap.val();
      const dataAge = (Date.now() - current.timestamp) / 1000;
      console.log(`✅ Device has current data`);
      console.log(`   💓 Heart Rate: ${current.heartRate} BPM`);
      console.log(`   🌡️  Body Temp: ${current.bodyTemp}°C`);
      console.log(`   🩸 SpO2: ${current.spo2}%`);
      console.log(`   🔋 Battery: ${current.battPerc}%`);
      console.log(`   👕 Worn: ${current.worn ? "Yes" : "No"}`);
      console.log(`   ⏰ Data Age: ${Math.floor(dataAge)}s ago`);

      // Calculate if current HR would trigger alert
      const hrDiff = current.heartRate - baseline.baselineHR;
      const percentAbove = ((hrDiff / baseline.baselineHR) * 100).toFixed(1);
      console.log("");
      console.log(`   📈 Current HR vs Baseline:`);
      console.log(`      Difference: ${hrDiff >= 0 ? "+" : ""}${hrDiff.toFixed(1)} BPM`);
      console.log(`      Percentage: ${percentAbove}% ${hrDiff >= 0 ? "above" : "below"} baseline`);

      if (hrDiff >= 45) {
        console.log(`      🚨 CRITICAL range (+45 BPM) - Would trigger alert`);
      } else if (hrDiff >= 35) {
        console.log(`      🔴 SEVERE range (+35 BPM) - Would trigger alert`);
      } else if (hrDiff >= 25) {
        console.log(`      🟡 MODERATE range (+25 BPM) - Would trigger alert`);
      } else if (hrDiff >= 15) {
        console.log(`      🟢 MILD range (+15 BPM) - Would trigger alert`);
      } else {
        console.log(`      ✅ NORMAL range (under +15 BPM) - No alert`);
      }
    } else {
      console.log(`❌ No current device data`);
    }

    console.log("");

    // 4. Check Session History
    console.log("📜 STEP 4: SESSION HISTORY CHECK");
    console.log("-".repeat(80));
    const historyRef = db.ref(`/users/${userId}/sessions/${sessionId}/history`);
    const historySnap = await historyRef.once("value");

    if (historySnap.exists()) {
      const history = historySnap.val();
      const historyArray = Object.entries(history).map(([key, value]) => ({
        key,
        ...value,
      }));

      // Get last 40 seconds of data
      const cutoffTime = Date.now() - 40 * 1000;
      const recentHistory = historyArray.filter((h) => h.timestamp >= cutoffTime);

      console.log(`✅ Session has history data`);
      console.log(`   📊 Total history points: ${historyArray.length}`);
      console.log(`   ⏰ Recent points (last 40s): ${recentHistory.length}`);

      if (recentHistory.length >= 3) {
        console.log(`   ✅ Sufficient data for sustained detection (3+ points needed)`);

        // Analyze recent trend
        const avgHR =
          recentHistory.reduce((sum, h) => sum + h.heartRate, 0) /
          recentHistory.length;
        const hrDiff = avgHR - baseline.baselineHR;
        const percentAbove = ((hrDiff / baseline.baselineHR) * 100).toFixed(1);

        console.log(`   📈 Recent HR trend (last ${recentHistory.length} points):`);
        console.log(`      Average HR: ${avgHR.toFixed(1)} BPM`);
        console.log(`      vs Baseline: ${hrDiff >= 0 ? "+" : ""}${hrDiff.toFixed(1)} BPM (${percentAbove}%)`);

        // Check for sustained elevation
        const elevatedPoints = recentHistory.filter(
          (h) => h.heartRate - baseline.baselineHR >= 15
        );
        if (elevatedPoints.length >= 3) {
          console.log(`   ⚠️  SUSTAINED ELEVATION DETECTED!`);
          console.log(`      ${elevatedPoints.length} consecutive elevated readings`);
        }
      } else {
        console.log(
          `   ⚠️  Not enough data for sustained detection (${recentHistory.length} < 3 points)`
        );
      }

      // Show last 5 readings
      console.log(`   📋 Last 5 readings:`);
      const last5 = historyArray.slice(-5);
      last5.forEach((h, i) => {
        const age = Math.floor((Date.now() - h.timestamp) / 1000);
        console.log(
          `      ${i + 1}. ${h.heartRate} BPM (${age}s ago) - ${h.spo2}% SpO2`
        );
      });
    } else {
      console.log(`❌ No session history data`);
      console.log(`   ⚠️  Cannot perform sustained detection without history`);
    }

    console.log("");

    // 5. Check for Recent Alerts
    console.log("🔔 STEP 5: RECENT ALERT ACTIVITY");
    console.log("-".repeat(80));

    // Check device alerts (native format)
    const deviceAlertsRef = db.ref(`/devices/${deviceId}/alerts`);
    const deviceAlertsSnap = await deviceAlertsRef
      .orderByChild("timestamp")
      .limitToLast(5)
      .once("value");

    if (deviceAlertsSnap.exists()) {
      const alerts = deviceAlertsSnap.val();
      const alertArray = Object.entries(alerts).map(([key, value]) => ({
        key,
        ...value,
      }));
      console.log(`📱 Device alerts: ${alertArray.length} recent alerts`);
      alertArray.forEach((alert, i) => {
        const age = Math.floor((Date.now() - alert.timestamp) / 1000);
        console.log(
          `   ${i + 1}. ${alert.severity.toUpperCase()} - ${alert.heartRate} BPM (${age}s ago)`
        );
      });
    } else {
      console.log(`📱 No device alerts found`);
    }

    // Check user anxiety_alerts
    const userAlertsRef = db.ref(`/users/${userId}/anxiety_alerts`);
    const userAlertsSnap = await userAlertsRef
      .orderByChild("timestamp")
      .limitToLast(5)
      .once("value");

    if (userAlertsSnap.exists()) {
      const alerts = userAlertsSnap.val();
      const alertArray = Object.entries(alerts).map(([key, value]) => ({
        key,
        ...value,
      }));
      console.log(`👤 User anxiety alerts: ${alertArray.length} recent alerts`);
      alertArray.forEach((alert, i) => {
        const age = Math.floor((Date.now() - alert.timestamp) / 1000);
        console.log(
          `   ${i + 1}. ${alert.severity.toUpperCase()} - ${alert.heartRate} BPM (${age}s ago)`
        );
      });
    } else {
      console.log(`👤 No user anxiety alerts found`);
    }

    console.log("");

    // 6. Check FCM Token
    console.log("🔔 STEP 6: FCM TOKEN CHECK");
    console.log("-".repeat(80));
    const fcmTokenRef = db.ref(`/devices/${deviceId}/assignment/fcmToken`);
    const fcmTokenSnap = await fcmTokenRef.once("value");

    if (fcmTokenSnap.exists()) {
      const token = fcmTokenSnap.val();
      console.log(`✅ FCM token exists`);
      console.log(`   📍 Path: /devices/${deviceId}/assignment/fcmToken`);
      console.log(`   📱 Token: ${token.substring(0, 20)}...${token.substring(token.length - 10)}`);
    } else {
      console.log(`❌ No FCM token found`);
      console.log(`   📍 Expected path: /devices/${deviceId}/assignment/fcmToken`);
      console.log(`   ⚠️  Notifications WILL NOT be delivered without FCM token`);
    }

    console.log("");

    // 7. System Configuration Check
    console.log("⚙️  STEP 7: SYSTEM CONFIGURATION");
    console.log("-".repeat(80));
    console.log(`📊 Detection Thresholds:`);
    console.log(`   🟢 MILD:     +15 BPM (60% confidence)`);
    console.log(`   🟡 MODERATE: +25 BPM (75% confidence)`);
    console.log(`   🔴 SEVERE:   +35 BPM (85% confidence)`);
    console.log(`   🚨 CRITICAL: +45 BPM (95% confidence)`);
    console.log(``);
    console.log(`⏱️  Duration Requirements:`);
    console.log(`   Sustained: 90+ seconds of continuous elevation`);
    console.log(`   History: 40 seconds of recent data analyzed`);
    console.log(`   Minimum points: 3+ data points required`);
    console.log(``);
    console.log(`🔕 Rate Limiting:`);
    console.log(`   Cooldown: 2 minutes between notifications`);
    console.log(`   Per user: Prevents duplicate alerts`);

    console.log("");

    // 8. System Status Summary
    console.log("📋 STEP 8: SYSTEM STATUS SUMMARY");
    console.log("=".repeat(80));

    const checks = {
      deviceAssigned: assignmentSnap.exists() && userId && sessionId,
      baselineExists: baseline !== null,
      currentDataExists: currentDataSnap.exists(),
      historyDataExists:
        historySnap.exists() &&
        Object.keys(historySnap.val()).length >= 3,
      fcmTokenExists: fcmTokenSnap.exists(),
    };

    const allChecks = Object.values(checks).every((v) => v === true);

    if (allChecks) {
      console.log(`✅ ALL SYSTEMS OPERATIONAL`);
      console.log(`   Anxiety alert system is fully functional and ready to detect`);
      if (baselineSource) {
        console.log(`   📍 Using baseline from: ${baselineSource}`);
      }
    } else {
      console.log(`⚠️  SYSTEM ISSUES DETECTED`);
      console.log(`   Some components are not properly configured:`);
      if (!checks.deviceAssigned)
        console.log(`   ❌ Device not assigned to user`);
      if (!checks.baselineExists)
        console.log(`   ❌ User baseline not calculated`);
      if (!checks.currentDataExists)
        console.log(`   ❌ No current device data`);
      if (!checks.historyDataExists)
        console.log(`   ❌ Insufficient session history`);
      if (!checks.fcmTokenExists)
        console.log(`   ❌ No FCM token for notifications`);
    }

    console.log("");
    console.log("=".repeat(80));
    console.log("✅ Analysis complete!");
    console.log("");

    process.exit(0);
  } catch (error) {
    console.error("❌ Error during analysis:", error);
    process.exit(1);
  }
}

analyzeAnxietyAlertSystem();
