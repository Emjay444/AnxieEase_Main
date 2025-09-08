// Simple Firebase cleanup script using the Firebase CLI tools
// This removes old Bluetooth data structure from your database

const data = {
  devices: {
    AnxieEase001: {
      metadata: {
        deviceId: "AnxieEase001",
        deviceType: "simulated_health_monitor",
        userId: "user_001",
        status: "initialized",
        isSimulated: true,
        architecture: "pure_iot_firebase",
        version: "2.0.0",
      },
      current: {
        heartRate: 72,
        spo2: 98,
        bodyTemp: 36.5,
        ambientTemp: 23.0,
        battPerc: 85,
        worn: true,
        deviceId: "AnxieEase001",
        userId: "user_001",
        severityLevel: "mild",
        source: "iot_simulation",
        connectionStatus: "ready",
      },
    },
  },
  users: {
    user_001: {
      userId: "user_001",
      deviceId: "AnxieEase001",
      preferences: {
        dataFrequency: 2000,
        stressDetection: true,
        historicalDataRetention: 30,
      },
    },
  },
};

console.log("🔧 New IoT Firebase Structure:");
console.log(JSON.stringify(data, null, 2));
console.log("\n📋 Manual Steps:");
console.log("1. Go to Firebase Console: https://console.firebase.google.com/");
console.log("2. Select your AnxieEase project");
console.log("3. Go to Realtime Database");
console.log(
  '4. Delete the old "devices/AnxieEase001" node with Bluetooth data'
);
console.log("5. Import the above JSON structure");
console.log("6. Update Database Rules using database_rules_iot.json");
