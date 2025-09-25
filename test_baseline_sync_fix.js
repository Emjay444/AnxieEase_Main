// TEST BASELINE SYNC FIX
// This script verifies that baselines are properly synced between Supabase tables

const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://qavmkogrwvczwvxnspho.supabase.co";
const supabaseKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFhdm1rb2dyd3Zjend2eG5zcGhvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjYyODg4MDEsImV4cCI6MjA0MTg2NDgwMX0.qNn7KLjzKTZt8a8_jcB2W3VWGBYXGJNOkGT3r0cRrE8";

const supabase = createClient(supabaseUrl, supabaseKey);

async function testBaselineSync() {
  console.log("🔍 TESTING BASELINE SYNC FIX");
  console.log("=============================\n");

  try {
    // Step 1: Check current baseline consistency
    console.log("📊 CURRENT BASELINE STATUS:");
    console.log("============================");

    const { data: devices, error: devicesError } = await supabase
      .from("wearable_devices")
      .select(
        `
                device_id,
                user_id,
                baseline_hr
            `
      )
      .not("user_id", "is", null);

    if (devicesError) {
      throw devicesError;
    }

    const { data: baselines, error: baselinesError } = await supabase.from(
      "baseline_heart_rates"
    ).select(`
                user_id,
                baseline_hr
            `);

    if (baselinesError) {
      throw baselinesError;
    }

    // Compare baselines
    console.log("Device Assignments vs User Baselines:");
    console.log("-------------------------------------");

    for (const device of devices) {
      const userBaseline = baselines.find((b) => b.user_id === device.user_id);
      const deviceBL = device.baseline_hr;
      const userBL = userBaseline?.baseline_hr;

      let status;
      if (deviceBL === userBL) {
        status = "✅ SYNCED";
      } else if (deviceBL === null && userBL === null) {
        status = "✅ BOTH NULL";
      } else {
        status = `❌ MISMATCH (Device: ${deviceBL}, User: ${userBL})`;
      }

      console.log(
        `Device ${device.device_id} → User ${device.user_id.substring(0, 8)}...`
      );
      console.log(`  Device Baseline: ${deviceBL} BPM`);
      console.log(`  User Baseline: ${userBL} BPM`);
      console.log(`  Status: ${status}\n`);
    }

    // Step 2: Test manual baseline update simulation
    console.log("🧪 TESTING MANUAL BASELINE UPDATE:");
    console.log("===================================");

    // Find a user to test with
    const testDevice = devices[0];
    if (testDevice) {
      console.log(`Testing with Device: ${testDevice.device_id}`);
      console.log(`User: ${testDevice.user_id.substring(0, 8)}...\n`);

      // Simulate manual baseline sync (in production, this would be automatic via trigger)
      const userBaseline = baselines.find(
        (b) => b.user_id === testDevice.user_id
      );

      if (userBaseline) {
        console.log(`📋 Manual Sync Test:`);
        console.log(
          `   Current Device Baseline: ${testDevice.baseline_hr} BPM`
        );
        console.log(
          `   User's Actual Baseline: ${userBaseline.baseline_hr} BPM`
        );

        if (testDevice.baseline_hr !== userBaseline.baseline_hr) {
          console.log(
            `   ⚠️  Would update device baseline to: ${userBaseline.baseline_hr} BPM`
          );
          console.log(
            `   📝 SQL: UPDATE wearable_devices SET baseline_hr = ${userBaseline.baseline_hr} WHERE device_id = '${testDevice.device_id}';`
          );
        } else {
          console.log(`   ✅ Already synced!`);
        }
      }
    }

    // Step 3: Show SQL commands to run
    console.log("\n🔧 NEXT STEPS:");
    console.log("===============");
    console.log(
      "1. Run the SQL from fix_baseline_sync_supabase.sql in Supabase SQL Editor"
    );
    console.log("2. This will create automatic sync triggers");
    console.log("3. Test by reassigning a device to a user in admin panel");
    console.log(
      "4. Verify baseline automatically updates to match user profile\n"
    );

    // Step 4: Show Firebase impact
    console.log("🔥 FIREBASE IMPACT:");
    console.log("===================");
    console.log("After fixing Supabase baselines:");
    console.log("• Webhook will sync CORRECT baseline to Firebase");
    console.log("• Anxiety detection will use user's ACTUAL baseline");
    console.log("• No more false alarms from wrong thresholds");
    console.log("• Users get accurate health monitoring\n");
  } catch (error) {
    console.error("❌ Error testing baseline sync:", error.message);
  }
}

// Function to manually sync a specific device (for testing)
async function manualSyncDevice(deviceId) {
  console.log(`🔧 MANUALLY SYNCING DEVICE: ${deviceId}`);
  console.log("==========================================\n");

  try {
    // Get device assignment
    const { data: device, error: deviceError } = await supabase
      .from("wearable_devices")
      .select("*")
      .eq("device_id", deviceId)
      .single();

    if (deviceError) throw deviceError;

    if (!device.user_id) {
      console.log("❌ Device has no user assigned");
      return;
    }

    // Get user's real baseline
    const { data: userBaseline, error: baselineError } = await supabase
      .from("baseline_heart_rates")
      .select("baseline_hr")
      .eq("user_id", device.user_id)
      .single();

    if (baselineError) {
      console.log("⚠️  User has no baseline set - will use null");
    }

    const newBaseline = userBaseline?.baseline_hr || null;

    console.log(`Device: ${device.device_id}`);
    console.log(`User: ${device.user_id.substring(0, 8)}...`);
    console.log(`Current Device Baseline: ${device.baseline_hr} BPM`);
    console.log(`User's Real Baseline: ${newBaseline} BPM`);

    if (device.baseline_hr !== newBaseline) {
      // Update device baseline
      const { error: updateError } = await supabase
        .from("wearable_devices")
        .update({ baseline_hr: newBaseline })
        .eq("device_id", deviceId);

      if (updateError) throw updateError;

      console.log(`✅ Updated device baseline to: ${newBaseline} BPM`);
      console.log("🔥 Firebase will sync this change via webhook");
    } else {
      console.log("✅ Already synced!");
    }
  } catch (error) {
    console.error("❌ Error syncing device:", error.message);
  }
}

// Run the test
testBaselineSync();

// Uncomment to manually sync a specific device:
// manualSyncDevice('AnxieEase001');
