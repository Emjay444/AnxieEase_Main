/**
 * 🔍 ANXIETY DETECTION ALGORITHM ANALYSIS
 * 
 * Investigating:
 * 1. How heart rate thresholds work with user baselines
 * 2. Movement detection and exercise filtering
 * 3. Current algorithm logic vs expected behavior
 */

const admin = require("firebase-admin");
const serviceAccount = require("./service-account-key.json");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/",
  });
}

const db = admin.database();

async function analyzeAnxietyDetectionLogic() {
  console.log("\n🔍 ANXIETY DETECTION ALGORITHM ANALYSIS");
  console.log("========================================");
  
  try {
    const CURRENT_USER = "5afad7d4-3dcd-4353-badb-4f155303419a";
    
    // Step 1: Check user's current baseline
    console.log("📊 Step 1: User Baseline Analysis");
    console.log("=================================");
    
    const userRef = db.ref(`/users/${CURRENT_USER}`);
    const userSnapshot = await userRef.once('value');
    
    if (userSnapshot.exists()) {
      const userData = userSnapshot.val();
      
      if (userData.baseline) {
        const baselineHR = userData.baseline.heartRate;
        console.log(`✅ User Baseline: ${baselineHR} BPM`);
        console.log(`   Source: ${userData.baseline.source}`);
        console.log(`   Device: ${userData.baseline.deviceId || 'Not specified'}`);
        console.log(`   Set: ${new Date(userData.baseline.timestamp).toLocaleString()}`);
        
        // Calculate threshold ranges
        console.log("\n📈 Threshold Calculations:");
        console.log("==========================");
        
        // Common anxiety thresholds
        const thresholds = {
          mild: Math.round(baselineHR * 1.15),      // +15%
          moderate: Math.round(baselineHR * 1.25),  // +25% 
          severe: Math.round(baselineHR * 1.35),    // +35%
        };
        
        console.log(`Baseline HR: ${baselineHR} BPM`);
        console.log(`Mild anxiety (>15%): ${thresholds.mild}+ BPM`);
        console.log(`Moderate anxiety (>25%): ${thresholds.moderate}+ BPM`);
        console.log(`Severe anxiety (>35%): ${thresholds.severe}+ BPM`);
        
        // Check recent alerts against thresholds
        if (userData.alerts) {
          console.log("\n🚨 Recent Alerts Analysis:");
          console.log("===========================");
          
          const alerts = Object.values(userData.alerts);
          const recentAlerts = alerts
            .filter(alert => alert.timestamp > Date.now() - 24*60*60*1000) // Last 24h
            .sort((a, b) => b.timestamp - a.timestamp);
          
          if (recentAlerts.length > 0) {
            console.log(`Found ${recentAlerts.length} alerts in last 24 hours:`);
            
            recentAlerts.slice(0, 5).forEach((alert, index) => {
              const alertHR = alert.heartRate;
              const percentAbove = ((alertHR - baselineHR) / baselineHR * 100).toFixed(1);
              const time = new Date(alert.timestamp).toLocaleTimeString();
              
              console.log(`   ${index + 1}. ${time}: ${alertHR} BPM (+${percentAbove}% above baseline)`);
              console.log(`      Severity: ${alert.severity || 'Unknown'}`);
              console.log(`      Duration: ${alert.duration || 'Unknown'}s`);
            });
          } else {
            console.log("No recent alerts found");
          }
        }
        
      } else {
        console.log("❌ No baseline found for user");
      }
    }
    
    // Step 2: Examine current sensor data
    console.log("\n📱 Step 2: Current Sensor Data Analysis");
    console.log("=======================================");
    
    const currentDataRef = db.ref('/devices/AnxieEase001/current');
    const currentSnapshot = await currentDataRef.once('value');
    
    if (currentSnapshot.exists()) {
      const currentData = currentSnapshot.val();
      
      console.log("Current sensor readings:");
      console.log(`   Heart Rate: ${currentData.heartRate} BPM`);
      console.log(`   SpO2: ${currentData.spo2}%`);
      console.log(`   Body Temp: ${currentData.bodyTemp}°C`);
      console.log(`   Worn: ${currentData.worn ? 'Yes' : 'No'}`);
      console.log(`   Timestamp: ${new Date(currentData.timestamp).toLocaleString()}`);
      
      // Check if current HR would trigger anxiety
      if (userData && userData.baseline) {
        const baselineHR = userData.baseline.heartRate;
        const currentHR = currentData.heartRate;
        const percentDiff = ((currentHR - baselineHR) / baselineHR * 100).toFixed(1);
        
        console.log("\n🎯 Current Status vs Baseline:");
        console.log(`   Baseline: ${baselineHR} BPM`);
        console.log(`   Current: ${currentHR} BPM`);
        console.log(`   Difference: ${percentDiff > 0 ? '+' : ''}${percentDiff}%`);
        
        if (currentHR > baselineHR * 1.15) {
          console.log(`   🚨 Would trigger: Elevated heart rate detected!`);
        } else {
          console.log(`   ✅ Normal: Within acceptable range`);
        }
      }
    }
    
    // Step 3: Movement Detection Questions
    console.log("\n🏃 Step 3: Movement Detection Analysis");
    console.log("=====================================");
    
    console.log("❓ CURRENT QUESTIONS ABOUT MOVEMENT:");
    console.log("1. Does the device have accelerometer/gyroscope data?");
    console.log("2. Is movement data being sent to Firebase?");
    console.log("3. How should exercise vs anxiety be distinguished?");
    
    console.log("\n💡 MOVEMENT DETECTION SCENARIOS:");
    console.log("================================");
    console.log("🏃 Exercise (Should NOT trigger anxiety alert):");
    console.log("   • High HR + Continuous movement");
    console.log("   • Gradual HR increase");
    console.log("   • Sustained activity pattern");
    
    console.log("\n😰 Anxiety (Should trigger alert):");
    console.log("   • High HR + Minimal movement");  
    console.log("   • Sudden HR spike");
    console.log("   • Irregular patterns");
    console.log("   • Resting state with elevated HR");
    
    console.log("\n🤝 Tremors/Restlessness (Anxiety indicator):");
    console.log("   • High HR + Small rapid movements");
    console.log("   • Fidgeting patterns");
    console.log("   • Hand tremors while sitting");
    
    // Step 4: Check if movement data exists
    console.log("\n🔍 Step 4: Checking for Movement Data");
    console.log("=====================================");
    
    console.log("Looking for movement/accelerometer data in current sensor readings...");
    
    if (currentSnapshot.exists()) {
      const currentData = currentSnapshot.val();
      const hasMovementData = !!(
        currentData.accelerometerX || 
        currentData.accelerometerY || 
        currentData.accelerometerZ ||
        currentData.gyroscopeX ||
        currentData.gyroscopeY ||
        currentData.gyroscopeZ ||
        currentData.movement ||
        currentData.activity
      );
      
      if (hasMovementData) {
        console.log("✅ Movement data found:");
        ['accelerometerX', 'accelerometerY', 'accelerometerZ', 
         'gyroscopeX', 'gyroscopeY', 'gyroscopeZ', 
         'movement', 'activity'].forEach(field => {
          if (currentData[field] !== undefined) {
            console.log(`   ${field}: ${currentData[field]}`);
          }
        });
      } else {
        console.log("❌ No movement/accelerometer data found in current readings");
        console.log("   Available fields:");
        Object.keys(currentData).forEach(key => {
          console.log(`   • ${key}: ${currentData[key]}`);
        });
      }
    }
    
    console.log("\n🎯 KEY FINDINGS & RECOMMENDATIONS:");
    console.log("===================================");
    
    console.log("\n1. 📊 HEART RATE THRESHOLDS:");
    if (userData && userData.baseline) {
      console.log(`   ✅ User baseline exists: ${userData.baseline.heartRate} BPM`);
      console.log("   ✅ Thresholds can be calculated from baseline");
      console.log("   ✅ Personalized anxiety detection possible");
    } else {
      console.log("   ❌ No user baseline - using generic thresholds");
    }
    
    console.log("\n2. 🏃 MOVEMENT FILTERING:");
    console.log("   ❓ Need to verify if device sends movement data");
    console.log("   ❓ Exercise detection logic may need implementation");
    console.log("   ❓ Current algorithm may not filter exercise-induced HR spikes");
    
    console.log("\n3. 🚨 ALERT ACCURACY:");
    console.log("   ⚠️  Without movement filtering, exercise could trigger false alarms");
    console.log("   ⚠️  Need to distinguish anxiety vs physical activity");
    
    console.log("\n4. 💡 SUGGESTED IMPROVEMENTS:");
    console.log("   🔧 Add movement data collection if available");
    console.log("   🔧 Implement exercise detection algorithm");  
    console.log("   🔧 Add context-aware anxiety detection");
    console.log("   🔧 Consider time-of-day patterns");
    console.log("   🔧 Add user feedback mechanism ('Was this anxiety?')");
    
  } catch (error) {
    console.error("❌ Analysis failed:", error.message);
  }
}

analyzeAnxietyDetectionLogic();