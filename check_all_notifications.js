// Check all notifications in Supabase using service role key
const SUPABASE_URL = "https://gqsustjxzjzfntcsnvpk.supabase.co";
const SUPABASE_SERVICE_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTIwODg1OCwiZXhwIjoyMDU2Nzg0ODU4fQ.cpwoYCQIEiqnRliT-A25GESAy7lS_YP_ETTYM5idujY";

async function checkAllNotifications() {
  console.log("🔍 Checking all notifications in Supabase...");

  try {
    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/notifications?order=created_at.desc&limit=20`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
        },
      }
    );

    if (!response.ok) {
      console.log("❌ Error:", response.status, await response.text());
      return;
    }

    const notifications = await response.json();
    console.log(`📋 Found ${notifications.length} notifications:`);

    if (notifications.length === 0) {
      console.log("   No notifications found");
    } else {
      notifications.forEach((notif, index) => {
        console.log(
          `${index + 1}. [${notif.user_id}] [${notif.type}] ${notif.title} - ${
            notif.created_at
          }`
        );
      });

      // Look for our test notification
      const testNotif = notifications.find((n) =>
        n.title.includes("Moderate Alert - 70% Confidence")
      );
      if (testNotif) {
        console.log("✅ SUCCESS! Test notification found!");
        console.log(
          "📄 Full notification:",
          JSON.stringify(testNotif, null, 2)
        );
      } else {
        console.log("❌ Test notification not found");
      }
    }
  } catch (error) {
    console.log("❌ Request error:", error.message);
  }
}

checkAllNotifications();
