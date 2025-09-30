// Test script to verify Supabase connection from Cloud Functions
// Run this to test if your environment variables are working

const SUPABASE_URL =
  process.env.SUPABASE_URL || "https://gqsustjxzjzfntcsnvpk.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY =
  process.env.SUPABASE_SERVICE_ROLE_KEY ||
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MTIwODg1OCwiZXhwIjoyMDU2Nzg0ODU4fQ.cpwoYCQIEiqnRliT-A25GESAy7lS_YP_ETTYM5idujY";

async function testSupabaseConnection() {
  console.log("🔍 Testing Supabase connection...");
  console.log("📍 SUPABASE_URL:", SUPABASE_URL);
  console.log(
    "🔑 SUPABASE_SERVICE_ROLE_KEY:",
    SUPABASE_SERVICE_ROLE_KEY ? "SET" : "NOT SET"
  );

  if (
    !SUPABASE_SERVICE_ROLE_KEY ||
    SUPABASE_SERVICE_ROLE_KEY === "YOUR_SERVICE_ROLE_KEY_HERE"
  ) {
    console.log("❌ SUPABASE_SERVICE_ROLE_KEY is not configured");
    console.log("📝 Follow the instructions in configure_supabase_env.md");
    return;
  }

  try {
    const url = `${SUPABASE_URL}/rest/v1/notifications`;
    const testPayload = {
      user_id: "5afad7d4-3dcd-4353-badb-4f155303419a",
      title: "[TEST] Connection Test",
      message: "Testing Supabase connection from Cloud Functions",
      type: "alert",
      related_screen: "notifications",
      created_at: new Date().toISOString(),
    };

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        Prefer: "return=representation",
      },
      body: JSON.stringify(testPayload),
    });

    if (response.ok) {
      const result = await response.json();
      console.log("✅ Supabase connection successful!");
      console.log("📄 Test notification created:", result);
      console.log(
        "🎉 Your Cloud Functions can now store notifications to Supabase!"
      );
    } else {
      const error = await response.text();
      console.log("❌ Supabase connection failed:", response.status, error);
    }
  } catch (error) {
    console.log("❌ Connection test error:", error.message);
  }
}

// Run the test
testSupabaseConnection();
