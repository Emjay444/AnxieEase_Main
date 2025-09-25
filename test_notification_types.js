const { createClient } = require("@supabase/supabase-js");

const supabase = createClient(
  "https://gqsustjxzjzfntcsnvpk.supabase.co",
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA"
);

async function testNotificationTypes() {
  console.log("🧪 Testing notification types based on Flutter app behavior...");

  // From your Flutter output, it's getting notifications with type 'alert'
  // Let's test the most likely types
  const types = [
    "alert",
    "reminder",
    "anxiety_alert",
    "wellness_reminder",
    "system",
    "emergency",
  ];
  const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";

  for (const type of types) {
    const { data, error } = await supabase
      .from("notifications")
      .insert({
        user_id: userId,
        title: `Test ${type}`,
        message: `Testing ${type} notification type`,
        type: type,
      })
      .select();

    if (error) {
      console.log(`❌ "${type}": ${error.message}`);
    } else {
      console.log(`✅ "${type}": SUCCESS!`);
      // Clean up immediately
      if (data && data[0]) {
        await supabase.from("notifications").delete().eq("id", data[0].id);
        console.log(`   🗑️ Cleaned up test record for ${type}`);
      }
    }
  }
}

testNotificationTypes().catch(console.error);
