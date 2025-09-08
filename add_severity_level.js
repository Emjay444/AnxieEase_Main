// Simple Firebase update to add missing severityLevel field
// Add this to your Firebase Realtime Database manually

const updateData = {
  "devices/AnxieEase001/current/severityLevel": "mild",
  "devices/AnxieEase001/current/timestamp": { ".sv": "timestamp" },
};

console.log("🔧 Add this to your Firebase Console:");
console.log("");
console.log("1. Go to Firebase Console → Realtime Database");
console.log("2. Navigate to: devices/AnxieEase001/current/");
console.log('3. Add new child: severityLevel = "mild"');
console.log("");
console.log("Or import this JSON:");
console.log(
  JSON.stringify(
    {
      severityLevel: "mild",
    },
    null,
    2
  )
);

console.log("");
console.log(
  "✅ After adding this field, your IoT service will automatically update it with real values!"
);
console.log('📊 Expected values: "mild", "moderate", or "severe"');
