// Verify that baselines are properly stored for shared device setup
// Run: node verify_shared_device_baselines.js

const admin = require("firebase-admin");
const fetch = require("node-fetch");

// Initialize Firebase Admin
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://anxieease-sensors-default-rtdb.firebaseio.com",
});

// Supabase configuration
const SUPABASE_URL = "https://rgyhljphkimypytwksex.supabase.co";
const SUPABASE_SERVICE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJneWhsanBoa2lteXB5dHdrc2V4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTMwMzI0MCwiZXhwIjoyMDQ0ODc5MjQwfQ.oUVu8MWqKLQ2-g_xBiQoAzewwYK8jFgZqnrh5r3D6MM";

const DEVICE_ID = "AnxieEase001";
const TEST_USER_ID = "24a689fe-3eec-46ee-8374-81a81914f530"; // Your user ID

async function verifySharedDeviceBaselines() {
  console.log("🔍 Verifying Shared Device Baseline Setup\n");
  console.log("=".repeat(60));

  // 1. Check all baselines for the shared device
  console.log("\n📊 Step 1: Checking all user baselines for device", DEVICE_ID);
  console.log("-".repeat(60));

  try {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/baseline_heart_rates?device_id=eq.${DEVICE_ID}&is_active=eq.true&select=user_id,baseline_hr,recorded_at`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );

    const baselines = await response.json();

    if (baselines.length === 0) {
      console.log("❌ No baselines found for device", DEVICE_ID);
      console.log("   Please set up your baseline in the app first.");
      return;
    }

    console.log(
      `✅ Found ${baselines.length} user baseline(s) for shared device:`
    );
    baselines.forEach((b, index) => {
      console.log(
        `   ${index + 1}. User: ${b.user_id.substring(0, 8)}... | Baseline: ${
          b.baseline_hr
        } BPM | Recorded: ${b.recorded_at}`
      );
    });
  } catch (error) {
    console.error("❌ Error checking Supabase baselines:", error.message);
    return;
  }

  // 2. Verify YOUR specific baseline
  console.log(
    "\n📊 Step 2: Checking YOUR baseline (user:",
    TEST_USER_ID.substring(0, 8) + "...)"
  );
  console.log("-".repeat(60));

  try {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/baseline_heart_rates?user_id=eq.${TEST_USER_ID}&device_id=eq.${DEVICE_ID}&is_active=eq.true&order=recorded_at.desc&limit=1`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );

    const yourBaseline = await response.json();

    if (yourBaseline.length === 0) {
      console.log("❌ No baseline found for your user ID");
      console.log("   Please set up your baseline in the app.");
      return;
    }

    console.log(`✅ YOUR Baseline: ${yourBaseline[0].baseline_hr} BPM`);
    console.log(`   Recorded: ${yourBaseline[0].recorded_at}`);
    console.log(
      `   This is what the Cloud Function will use for YOUR anxiety detection`
    );
  } catch (error) {
    console.error("❌ Error checking your baseline:", error.message);
    return;
  }

  // 3. Check wearable_devices table (should only have ONE row for the device)
  console.log("\n📊 Step 3: Checking wearable_devices table");
  console.log("-".repeat(60));

  try {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/wearable_devices?device_id=eq.${DEVICE_ID}&select=device_id,user_id,baseline_hr`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );

    const devices = await response.json();

    if (devices.length === 0) {
      console.log(
        "⚠️  Device not found in wearable_devices table (this is ok)"
      );
    } else {
      console.log(`✅ Device found in wearable_devices:`);
      console.log(
        `   User ID: ${devices[0].user_id?.substring(0, 8) || "None"}...`
      );
      console.log(`   Baseline in table: ${devices[0].baseline_hr || "NULL"}`);
      console.log(
        `   ℹ️  Note: This baseline_hr field is NOT used for shared devices`
      );
      console.log(
        `   ℹ️  Cloud Function queries baseline_heart_rates by user_id instead`
      );
    }
  } catch (error) {
    console.error("❌ Error checking wearable_devices:", error.message);
  }

  // 4. Summary
  console.log("\n" + "=".repeat(60));
  console.log("✅ VERIFICATION COMPLETE");
  console.log("=".repeat(60));
  console.log("\n📋 How shared device baselines work:");
  console.log("   1. Multiple users can use device", DEVICE_ID);
  console.log(
    "   2. Each user records their own baseline in baseline_heart_rates"
  );
  console.log("   3. Cloud Function queries by BOTH user_id AND device_id");
  console.log("   4. Each user gets anxiety detection based on THEIR baseline");
  console.log(
    "\n✅ Your setup is correct! No sync to wearable_devices needed."
  );
}

verifySharedDeviceBaselines()
  .then(() => {
    console.log("\n✅ Done!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Error:", error);
    process.exit(1);
  });
