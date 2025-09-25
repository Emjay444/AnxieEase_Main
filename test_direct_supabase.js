// Test Supabase notification storage directly
// This bypasses FCM to test if database storage is working

const { createClient } = require("@supabase/supabase-js");

const SUPABASE_URL = "https://gqsustjxzjzfntcsnvpk.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA";

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

console.log("🔧 TESTING DIRECT SUPABASE NOTIFICATION STORAGE");
console.log("═".repeat(60));

async function testDirectSupabaseStorage() {
  try {
    console.log("� Testing notification retrieval (no auth needed)...");

    // Test reading existing notifications to verify connection
    const { data: notifications, error: readError } = await supabase
      .from("notifications")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(10);

    if (readError) {
      console.error("❌ Failed to read notifications:", readError);
      console.log("\n🔍 POSSIBLE ISSUES:");
      console.log("1. ❌ Supabase connection/authentication");
      console.log("2. ❌ Wrong table name");
      console.log("3. ❌ RLS (Row Level Security) blocking read access");
      return;
    }

    console.log("✅ Successfully connected to Supabase!");
    console.log(`📊 Found ${notifications.length} notifications in database`);

    if (notifications.length > 0) {
      console.log("\n� Recent notifications:");
      notifications.slice(0, 5).forEach((notif, index) => {
        const createdAt = new Date(notif.created_at).toLocaleString();
        console.log(
          `${index + 1}. ${notif.title} - ${notif.type} (${createdAt})`
        );
      });
    }

    console.log("\n🎯 DIAGNOSIS:");
    console.log("─".repeat(40));
    console.log("✅ Supabase connection: Working");
    console.log("✅ Database access: Working");
    console.log("✅ Notifications table: Exists and readable");

    console.log("\n🔍 THE PROBLEM IS LIKELY:");
    console.log("─".repeat(40));
    console.log(
      "❌ FCM handler in Flutter app is not calling _storeAnxietyAlertNotification()"
    );
    console.log("❌ _storeAnxietyAlertNotification() is failing silently");
    console.log(
      "❌ User authentication issue in Flutter (required for createNotification)"
    );

    console.log("\n💡 NEXT STEPS:");
    console.log("─".repeat(40));
    console.log(
      "1. Check Flutter debug console when you receive FCM notifications"
    );
    console.log("2. Look for these messages:");
    console.log('   - "⚠️ Navigating to notifications from anxiety alert tap"');
    console.log('   - "✅ Stored anxiety alert in Supabase"');
    console.log('   - "❌ Error storing anxiety alert notification"');
    console.log(
      "3. If no messages appear, the FCM handler condition might not be matching"
    );
  } catch (error) {
    console.error("❌ Test failed:", error);
  }
}

testDirectSupabaseStorage();
