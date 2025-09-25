const { createClient } = require("@supabase/supabase-js");

const supabaseUrl = "https://gqsustjxzjzfntcsnvpk.supabase.co";
const supabaseAnonKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA";

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Your user credentials
const userEmail = "mjmolina444@gmail.com";
const userPassword = "12345678";

// Your FCM token (replace with your device's actual FCM token)
const fcmToken =
  "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0";

async function testSeverityNotifications() {
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

    // Array of different severity notifications to test
    const severityTests = [
      {
        level: "mild",
        title: "💛 Mild Anxiety Alert",
        message:
          "Your heart rate is slightly elevated. Consider taking a short break and trying some breathing exercises.",
        icon: "💛",
        priority: "normal",
      },
      {
        level: "moderate",
        title: "🧡 Moderate Anxiety Alert",
        message:
          "Your anxiety levels are moderately elevated. It would be good to practice some calming techniques now.",
        icon: "🧡",
        priority: "high",
      },
      {
        level: "severe",
        title: "❤️ Severe Anxiety Alert",
        message:
          "Your anxiety levels are significantly elevated. Please take immediate action to calm yourself and consider contacting support.",
        icon: "❤️",
        priority: "high",
      },
      {
        level: "critical",
        title: "🚨 Critical Anxiety Alert",
        message:
          "Your anxiety levels are critically high. Please seek immediate assistance and contact your healthcare provider if symptoms persist.",
        icon: "🚨",
        priority: "max",
      },
    ];

    console.log(
      `\n🧪 Testing ${severityTests.length} different severity levels...\n`
    );

    for (let i = 0; i < severityTests.length; i++) {
      const test = severityTests[i];
      console.log(
        `${i + 1}. Testing ${test.level.toUpperCase()} severity notification...`
      );

      try {
        // Store notification in Supabase
        const { data: notificationData, error: notificationError } =
          await supabase
            .from("notifications")
            .insert([
              {
                user_id: userId,
                title: test.title,
                message: test.message,
                type: "alert",
                read: false,
                created_at: new Date().toISOString(),
                related_screen: "breathing_screen",
                related_id: null,
              },
            ])
            .select()
            .single();

        if (notificationError) {
          console.error(
            `❌ Failed to store ${test.level} notification:`,
            notificationError.message
          );
          continue;
        }

        console.log(`   ✅ Stored ${test.level} notification in Supabase`);

        // Send FCM push notification
        const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            Authorization:
              "key=AAAAdaxno_4:APA91bFGBBUF3Qq8KrNEpKrV1dYEXSWkB5xRo4g8yF9X8UYbJ1dRa3w5jLOLj1f8ptvMlMsYh8Vbr2QyZYbGG5Y0oQ7HK9xF9wF1b8rA1d4U9LpA6I8a7F0lJ2mQ0S4", // AnxieEase FCM server key
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            to: fcmToken,
            notification: {
              title: test.title,
              body: test.message,
              icon: "notification_icon",
              sound: "default",
              priority: test.priority,
              channel_id: "anxiety_alerts",
            },
            data: {
              type: "alert",
              severity: test.level,
              related_screen: "breathing_screen",
              notification_id: notificationData.id.toString(),
              timestamp: new Date().toISOString(),
            },
            android: {
              priority: test.priority,
              notification: {
                channel_id: "anxiety_alerts",
                priority: test.priority === "max" ? "max" : "high",
                visibility: "public",
                icon: "notification_icon",
                color:
                  test.level === "critical"
                    ? "#E53E3E"
                    : test.level === "severe"
                    ? "#F56500"
                    : test.level === "moderate"
                    ? "#D69E2E"
                    : "#38A169",
              },
            },
          }),
        });

        if (!fcmResponse.ok) {
          const errorText = await fcmResponse.text();
          console.error(`❌ FCM ${test.level} notification failed:`, errorText);
        } else {
          const fcmResult = await fcmResponse.json();
          if (fcmResult.success === 1) {
            console.log(
              `   ✅ FCM ${test.level} notification sent successfully`
            );
          } else {
            console.log(
              `   ⚠️  FCM ${test.level} notification sent with issues:`,
              fcmResult
            );
          }
        }

        console.log(
          `   📱 ${
            test.level.charAt(0).toUpperCase() + test.level.slice(1)
          } alert sent!\n`
        );

        // Wait 2 seconds between notifications to see them clearly
        if (i < severityTests.length - 1) {
          await new Promise((resolve) => setTimeout(resolve, 2000));
        }
      } catch (error) {
        console.error(
          `❌ Error sending ${test.level} notification:`,
          error.message
        );
      }
    }

    console.log("🎉 All severity level notifications have been sent!");
    console.log("\n📱 Check your device for:");
    console.log("   • Push notifications (when app is in background)");
    console.log("   • In-app banner popups (when app is open)");
    console.log("   • Homepage notification cards");
    console.log("   • Notification screen entries");

    console.log(
      "\n🎨 Each severity level should have different colors and styling:"
    );
    console.log("   💛 Mild: Light green colors");
    console.log("   🧡 Moderate: Orange/yellow colors");
    console.log("   ❤️ Severe: Red/orange colors");
    console.log("   🚨 Critical: Bright red colors with urgent styling");

    // Verify notifications were stored
    const { data: storedNotifications, error: fetchError } = await supabase
      .from("notifications")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(4);

    if (fetchError) {
      console.error(
        "❌ Failed to verify stored notifications:",
        fetchError.message
      );
    } else {
      console.log(
        `\n✅ Verified ${storedNotifications.length} notifications stored in database`
      );
    }
  } catch (error) {
    console.error("❌ Script error:", error.message);
  }
}

testSeverityNotifications();
