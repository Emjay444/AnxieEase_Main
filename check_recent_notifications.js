// Check recent notifications in Supabase
const SUPABASE_URL = "https://gqsustjxzjzfntcsnvpk.supabase.co";
const SUPABASE_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA";

async function checkNotifications() {
  console.log("🔍 Checking recent notifications in Supabase...");

  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/notifications?user_id=eq.5afad7d4-3dcd-4353-badb-4f155303419a&order=created_at.desc&limit=10`,
    {
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
      },
    }
  );

  if (!response.ok) {
    console.log("❌ Error:", response.status, await response.text());
    return;
  }

  const notifications = await response.json();
  console.log(`📋 Found ${notifications.length} recent notifications:`);
  notifications.forEach((notif, index) => {
    console.log(
      `${index + 1}. [${notif.type}] ${notif.title} - ${notif.created_at}`
    );
  });

  // Check if our test notification is there
  const testNotif = notifications.find((n) =>
    n.title.includes("[TEST] 🟠 Moderate Alert - 70% Confidence")
  );
  if (testNotif) {
    console.log("✅ SUCCESS! Test notification found in Supabase!");
    console.log("📄 Full notification:", JSON.stringify(testNotif, null, 2));
  } else {
    console.log("❌ Test notification not found in Supabase yet");
    console.log("📋 Available notifications:");
    notifications.forEach((n) => console.log(`   - ${n.title}`));
  }
}

checkNotifications().catch(console.error);
