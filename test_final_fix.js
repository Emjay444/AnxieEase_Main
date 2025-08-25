const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testFinalNotificationFix() {
  console.log("🎯 FINAL NOTIFICATION DUPLICATE FIX TEST");
  console.log("");
  console.log("📋 Expected Results:");
  console.log("✅ App OPEN: 1 in-app notification (local Firebase listener)");
  console.log("✅ App CLOSED: 1 device notification (Cloud Function FCM only)");
  console.log("");
  
  console.log("🧪 TEST 1: App CLOSED Test");
  console.log("📱 CLOSE YOUR APP COMPLETELY!");
  console.log("⏳ Waiting 10 seconds for you to close the app...");
  
  await new Promise(resolve => setTimeout(resolve, 10000));
  
  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");
    
    // Clear and set baseline
    await metricsRef.set(null);
    console.log("🧹 Cleared data");
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    const baselineData = {
      heartRate: 75,
      anxietyDetected: {
        severity: "mild",
        timestamp: Date.now(),
        confidence: 0.7
      },
      timestamp: Date.now()
    };
    
    await metricsRef.set(baselineData);
    console.log("📊 Set baseline: mild");
    
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Trigger severe alert
    const alertData = {
      heartRate: 130,
      anxietyDetected: {
        severity: "severe",
        timestamp: Date.now(),
        confidence: 0.95
      },
      timestamp: Date.now()
    };
    
    await metricsRef.set(alertData);
    console.log("🚨 Triggered: mild → severe");
    console.log("📱 Check your device - you should see ONLY 1 notification!");
    console.log("❌ If you see 2 notifications, there's still an issue");
    
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    console.log("\n🧪 TEST 2: App OPEN Test");
    console.log("📱 OPEN YOUR APP NOW!");
    console.log("⏳ Waiting 8 seconds for you to open the app...");
    
    await new Promise(resolve => setTimeout(resolve, 8000));
    
    // Trigger another alert
    const openAppData = {
      heartRate: 110,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.8
      },
      timestamp: Date.now()
    };
    
    await metricsRef.set(openAppData);
    console.log("🟠 Triggered: severe → moderate");
    console.log("📱 Check your app - you should see 1 in-app notification!");
    console.log("✅ No device notification should appear");
    
    console.log("\n🎯 TEST COMPLETE!");
    console.log("If both tests show only 1 notification each, the fix is working!");
    
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
  
  process.exit(0);
}

testFinalNotificationFix();
