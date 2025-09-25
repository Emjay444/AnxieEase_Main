const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://gqsustjxzjzfntcsnvpk.supabase.co";
const supabaseAnonKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA";

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Your user credentials
const userEmail = "mjmolina444@gmail.com";
const userPassword = "12345678";

async function testInAppNotifications() {
  try {
    console.log("🔐 Signing in to Supabase...");
    const { data: authData, error: authError } =
      await supabase.auth.signInWithPassword({
        email: userEmail,
        password: userPassword,
      });

    if (authError) {
      console.error("❌ Authentication failed:", authError.message);
      return;
    }

    console.log("✅ Authentication successful for:", authData.user.email);
    const userId = authData.user.id;

    // Array of additional test notifications for in-app testing
    const testNotifications = [
      {
        title: "🌟 Daily Wellness Check",
        message:
          "Time for your daily wellness check-in! How are you feeling today?",
        type: "reminder",
        icon: "💙",
      },
      {
        title: "🫁 Breathing Exercise Reminder",
        message:
          "Take a moment to practice deep breathing. Your mental health matters!",
        type: "reminder",
        icon: "🌬️",
      },
      {
        title: "📊 Weekly Progress Update",
        message:
          "Great job this week! You completed 5 breathing exercises and 3 wellness check-ins.",
        type: "log",
        icon: "📈",
      },
      {
        title: "🆘 Emergency Contact Added",
        message: "Dr. Sarah Wilson has been added as your emergency contact.",
        type: "alert",
        icon: "👩‍⚕️",
      },
    ];

    console.log(
      `\n🧪 Adding ${testNotifications.length} more test notifications...\n`
    );

    for (let i = 0; i < testNotifications.length; i++) {
      const notification = testNotifications[i];
      console.log(
        `${i + 1}. Adding "${notification.title.replace(
          /[^\w\s]/gi,
          ""
        )}" notification...`
      );

      try {
        // Store notification in Supabase
        const { data: notificationData, error: notificationError } =
          await supabase
            .from("notifications")
            .insert([
              {
                user_id: userId,
                title: notification.title,
                message: notification.message,
                type: notification.type,
                read: false,
                created_at: new Date().toISOString(),
                related_screen:
                  notification.type === "reminder"
                    ? "breathing_screen"
                    : "home_screen",
                related_id: null,
              },
            ])
            .select()
            .single();

        if (notificationError) {
          console.error(
            `❌ Failed to store notification:`,
            notificationError.message
          );
          continue;
        }

        console.log(
          `   ✅ Stored "${notification.type}" notification successfully`
        );

        // Wait 1 second between notifications
        if (i < testNotifications.length - 1) {
          await new Promise((resolve) => setTimeout(resolve, 1000));
        }
      } catch (error) {
        console.error(`❌ Error adding notification:`, error.message);
      }
    }

    console.log("\n🎉 All in-app notifications have been added!");

    // Get current notification count
    const { data: allNotifications, error: fetchError } = await supabase
      .from("notifications")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(10);

    if (fetchError) {
      console.error("❌ Failed to verify notifications:", fetchError.message);
    } else {
      console.log(
        `\n📊 Total notifications in database: ${allNotifications.length}`
      );
      console.log("\nLatest notifications:");
      allNotifications.forEach((notif, index) => {
        const time = new Date(notif.created_at).toLocaleTimeString();
        console.log(
          `   ${index + 1}. [${notif.type.toUpperCase()}] ${notif.title.replace(
            /[^\w\s]/gi,
            ""
          )} (${time})`
        );
      });
    }

    console.log("\n📱 Now check your AnxieEase app:");
    console.log(
      '   • Homepage "Recent Notifications" section should show new cards'
    );
    console.log('   • Tap "See All" to view the notification screen');
    console.log(
      "   • Different notification types should have different colors"
    );
    console.log("   • Pull to refresh should update the notifications");

    console.log("\n🎨 Expected UI improvements:");
    console.log("   ✅ Modern notification card design with better colors");
    console.log('   ✅ "Loading..." instead of "Hello Guest" during startup');
    console.log("   ✅ Better error handling for network issues");
    console.log(
      "   ✅ Improved in-app banner popups (when new notifications arrive)"
    );
  } catch (error) {
    console.error("❌ Script error:", error.message);
  }
}

testInAppNotifications();
