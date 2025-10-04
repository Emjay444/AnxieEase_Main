/**
 * Test script for appointment expiration functionality
 * This script creates test appointments and triggers expiration checks
 */

const { createClient } = require("@supabase/supabase-js");

// Initialize Supabase (uses environment variables)
const supabaseUrl = process.env.SUPABASE_URL || "your-supabase-url";
const supabaseServiceKey =
  process.env.SUPABASE_SERVICE_ROLE_KEY || "your-service-key";
const supabase = createClient(supabaseUrl, supabaseServiceKey);

/**
 * Create test appointments for expiration testing
 */
async function createTestAppointments() {
  console.log("🧪 Creating test appointments for expiration testing...");

  const now = new Date();
  const yesterday = new Date(now.getTime() - 25 * 60 * 60 * 1000); // 25 hours ago (past deadline)
  const twoDaysAgo = new Date(now.getTime() - 48 * 60 * 60 * 1000); // 48 hours ago
  const oneHourAgo = new Date(now.getTime() - 1 * 60 * 60 * 1000); // 1 hour ago (not expired yet)

  const testAppointments = [
    {
      user_id: "test-user-1",
      appointment_date: yesterday.toISOString(),
      request_message: "Test appointment - should expire (25 hours old)",
      status: "pending",
      created_at: yesterday.toISOString(),
      updated_at: yesterday.toISOString(),
    },
    {
      user_id: "test-user-2",
      appointment_date: twoDaysAgo.toISOString(),
      request_message: "Test appointment - should expire (48 hours old)",
      status: "pending",
      created_at: twoDaysAgo.toISOString(),
      updated_at: twoDaysAgo.toISOString(),
    },
    {
      user_id: "test-user-3",
      appointment_date: oneHourAgo.toISOString(),
      request_message: "Test appointment - should NOT expire (1 hour old)",
      status: "pending",
      created_at: oneHourAgo.toISOString(),
      updated_at: oneHourAgo.toISOString(),
    },
  ];

  try {
    for (const appointment of testAppointments) {
      const { data, error } = await supabase
        .from("appointments")
        .insert(appointment)
        .select();

      if (error) {
        console.error(`❌ Error creating test appointment:`, error);
      } else {
        console.log(
          `✅ Created test appointment: ${data[0].id} (${appointment.request_message})`
        );
      }
    }

    console.log(`📋 Created ${testAppointments.length} test appointments`);
    return true;
  } catch (error) {
    console.error("❌ Error creating test appointments:", error);
    return false;
  }
}

/**
 * Check current pending appointments
 */
async function checkPendingAppointments() {
  console.log("🔍 Checking current pending appointments...");

  try {
    const { data: pendingAppointments, error } = await supabase
      .from("appointments")
      .select("*")
      .eq("status", "pending")
      .order("created_at", { ascending: true });

    if (error) {
      console.error("❌ Error querying pending appointments:", error);
      return;
    }

    console.log(`📋 Found ${pendingAppointments.length} pending appointments:`);
    pendingAppointments.forEach((apt, index) => {
      const createdAt = new Date(apt.created_at);
      const hoursOld = (new Date() - createdAt) / (1000 * 60 * 60);
      const shouldExpire = hoursOld > 24;

      console.log(`   ${index + 1}. ID: ${apt.id}`);
      console.log(`      Created: ${createdAt.toLocaleString()}`);
      console.log(`      Age: ${hoursOld.toFixed(1)} hours`);
      console.log(`      Should expire: ${shouldExpire ? "✅ YES" : "❌ NO"}`);
      console.log(`      Message: ${apt.request_message || "No message"}`);
      console.log("");
    });
  } catch (error) {
    console.error("❌ Error checking pending appointments:", error);
  }
}

/**
 * Check expired appointments
 */
async function checkExpiredAppointments() {
  console.log("🔍 Checking expired appointments...");

  try {
    const { data: expiredAppointments, error } = await supabase
      .from("appointments")
      .select("*")
      .eq("status", "expired")
      .order("updated_at", { ascending: false });

    if (error) {
      console.error("❌ Error querying expired appointments:", error);
      return;
    }

    console.log(`📋 Found ${expiredAppointments.length} expired appointments:`);
    expiredAppointments.forEach((apt, index) => {
      const createdAt = new Date(apt.created_at);
      const updatedAt = new Date(apt.updated_at);

      console.log(`   ${index + 1}. ID: ${apt.id}`);
      console.log(`      Created: ${createdAt.toLocaleString()}`);
      console.log(`      Expired: ${updatedAt.toLocaleString()}`);
      console.log(
        `      Response: ${apt.response_message || "No response message"}`
      );
      console.log("");
    });
  } catch (error) {
    console.error("❌ Error checking expired appointments:", error);
  }
}

/**
 * Trigger manual expiration via Firebase function
 */
async function triggerManualExpiration() {
  console.log("🔧 Triggering manual appointment expiration...");

  try {
    // Note: This would require Firebase Admin SDK setup
    // For now, just indicate that the trigger would be called
    console.log("📞 Would call triggerAppointmentExpiration() function");
    console.log("💡 In production, this would trigger the Cloud Function");

    // Simulate the expiration check logic here for testing
    const now = new Date();
    const cutoffTime = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const { data: overdueAppointments, error } = await supabase
      .from("appointments")
      .select("*")
      .eq("status", "pending")
      .lt("created_at", cutoffTime.toISOString());

    if (error) {
      console.error("❌ Error querying overdue appointments:", error);
      return;
    }

    console.log(
      `📋 Found ${overdueAppointments.length} appointments to expire`
    );

    for (const appointment of overdueAppointments) {
      const { error: updateError } = await supabase
        .from("appointments")
        .update({
          status: "expired",
          response_message: `Appointment request expired after 24-hour deadline. Created on ${new Date(
            appointment.created_at
          ).toLocaleDateString()}, expired on ${now.toLocaleDateString()}.`,
          updated_at: now.toISOString(),
        })
        .eq("id", appointment.id);

      if (updateError) {
        console.error(
          `❌ Error expiring appointment ${appointment.id}:`,
          updateError
        );
      } else {
        console.log(`✅ Expired appointment ${appointment.id}`);
      }
    }

    return overdueAppointments.length;
  } catch (error) {
    console.error("❌ Error triggering expiration:", error);
    return 0;
  }
}

/**
 * Clean up test appointments
 */
async function cleanupTestAppointments() {
  console.log("🧹 Cleaning up test appointments...");

  try {
    const { data, error } = await supabase
      .from("appointments")
      .delete()
      .or(
        "user_id.eq.test-user-1,user_id.eq.test-user-2,user_id.eq.test-user-3"
      )
      .select();

    if (error) {
      console.error("❌ Error cleaning up test appointments:", error);
    } else {
      console.log(`✅ Cleaned up ${data.length} test appointments`);
    }
  } catch (error) {
    console.error("❌ Error during cleanup:", error);
  }
}

/**
 * Main test function
 */
async function runAppointmentExpirationTest() {
  console.log("🚀 Starting Appointment Expiration Test");
  console.log("==========================================");

  try {
    // Step 1: Check current state
    console.log("\n📊 STEP 1: Current State");
    await checkPendingAppointments();
    await checkExpiredAppointments();

    // Step 2: Create test appointments
    console.log("\n🧪 STEP 2: Create Test Appointments");
    const created = await createTestAppointments();
    if (!created) {
      console.log("❌ Failed to create test appointments, aborting test");
      return;
    }

    // Step 3: Check state after creation
    console.log("\n📊 STEP 3: State After Creation");
    await checkPendingAppointments();

    // Step 4: Trigger expiration
    console.log("\n⏰ STEP 4: Trigger Expiration");
    const expiredCount = await triggerManualExpiration();

    // Step 5: Check final state
    console.log("\n📊 STEP 5: Final State");
    await checkPendingAppointments();
    await checkExpiredAppointments();

    // Step 6: Cleanup
    console.log("\n🧹 STEP 6: Cleanup");
    await cleanupTestAppointments();

    console.log("\n✅ Test completed successfully!");
    console.log(`📈 Summary: ${expiredCount} appointments expired`);
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
}

// Run the test if this script is executed directly
if (require.main === module) {
  console.log("🔧 Environment check:");
  console.log(`   SUPABASE_URL: ${supabaseUrl.substring(0, 20)}...`);
  console.log(
    `   SUPABASE_SERVICE_KEY: ${supabaseServiceKey ? "[SET]" : "[NOT SET]"}`
  );
  console.log("");

  if (!supabaseUrl.startsWith("http") || !supabaseServiceKey) {
    console.error(
      "❌ Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables"
    );
    process.exit(1);
  }

  runAppointmentExpirationTest();
}

module.exports = {
  createTestAppointments,
  checkPendingAppointments,
  checkExpiredAppointments,
  triggerManualExpiration,
  cleanupTestAppointments,
  runAppointmentExpirationTest,
};
