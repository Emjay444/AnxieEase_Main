const { createClient } = require("@supabase/supabase-js");

// Use the correct API key from your Flutter app
const supabase = createClient(
  "https://gqsustjxzjzfntcsnvpk.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA"
);

async function checkNotificationTypes() {
  console.log("🔍 Checking notification_type enum values...");

  try {
    // Get existing notifications to see what types are currently used
    const { data: existingData, error: existingError } = await supabase
      .from("notifications")
      .select("type")
      .limit(20);

    if (existingError) {
      console.log("❌ Failed to query existing notifications:", existingError);
    } else {
      console.log("📊 Current notification types in database:");
      const uniqueTypes = [...new Set(existingData?.map((n) => n.type) || [])];
      uniqueTypes.forEach((type) => console.log("   -", type));
    }

    // Test different possible types
    console.log("\n🧪 Testing different notification types...");
    const testTypes = [
      "alert",
      "reminder",
      "anxiety_alert",
      "anxiety_log",
      "wellness_reminder",
      "anxiety",
      "wellness",
    ];
    const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";

    for (const testType of testTypes) {
      const testData = {
        user_id: userId,
        title: "Test Type: " + testType,
        body: "Testing enum validation",
        type: testType,
        read: false,
        created_at: new Date().toISOString(),
      };

      const { data, error: testError } = await supabase
        .from("notifications")
        .insert(testData)
        .select();

      if (testError) {
        console.log("❌ " + testType + ":", testError.message);
      } else {
        console.log("✅ " + testType + ": Valid type!");
        // Clean up the test record immediately
        if (data && data[0]) {
          await supabase.from("notifications").delete().eq("id", data[0].id);
        }
      }
    }

    // Also try to get the schema information
    console.log("\n📋 Attempting to get schema information...");
    const { data: schemaData, error: schemaError } = await supabase.rpc(
      "get_table_schema",
      { table_name: "notifications" }
    );

    if (schemaError) {
      console.log("❌ Schema query failed:", schemaError.message);
    } else {
      console.log("✅ Schema data:", JSON.stringify(schemaData, null, 2));
    }
  } catch (error) {
    console.error("❌ Unexpected error:", error);
  }
}

checkNotificationTypes().catch(console.error);
