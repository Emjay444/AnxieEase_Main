const admin = require("firebase-admin");

// Initialize Firebase
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app",
});

async function testSingleNotification() {
  console.log("🧪 TESTING SINGLE NOTIFICATION (No More Duplicates!)");
  console.log("📱 Open your AnxieEase app and watch the logs");
  console.log("⏳ Triggering Firebase data change in 5 seconds...\n");
  
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  try {
    const db = admin.database();
    const metricsRef = db.ref("devices/AnxieEase001/Metrics");
    
    // Set test data that will trigger both Cloud Function AND app listener
    const testData = {
      heartRate: 110,
      anxietyDetected: {
        severity: "moderate",
        timestamp: Date.now(),
        confidence: 0.85
      },
      timestamp: Date.now()
    };
    
    await metricsRef.set(testData);
    console.log("✅ Firebase updated with moderate severity");
    console.log("📱 You should now see only ONE notification instead of two!");
    console.log("🔍 Check your app logs for:");
    console.log("   - '📊 Firebase data changed - saving record'");
    console.log("   - '🚫 Local notifications disabled'");
    console.log("   - No '🔔 Firebase data changed - sending notification'");
    
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
  
  process.exit(0);
}

testSingleNotification();
