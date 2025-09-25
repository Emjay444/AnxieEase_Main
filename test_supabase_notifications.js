const { createClient } = require("@supabase/supabase-js");
const admin = require("firebase-admin");

// Initialize Firebase Admin for FCM only
const serviceAccount = require("./service-account-key.json");
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Initialize Supabase (your app's actual database)
const supabaseUrl = "https://gqsustjxzjzfntcsnvpk.supabase.co";
const supabaseAnonKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA";
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testSupabaseNotifications() {
  console.log(
    "🚀 Testing Supabase notifications (where your app actually reads from)...\n"
  );

  try {
    const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
    const fcmToken =
      "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0";

    console.log("📱 Step 1: Sending FCM push notification...");

    // Send FCM push notification for background delivery
    const anxietyNotification = {
      notification: {
        title: "🚨 AnxieEase Anxiety Alert",
        body: "Your heart rate is elevated (96 BPM). Are you feeling anxious?",
      },
      data: {
        type: "anxiety",
        severity: "mild",
        heartRate: "96",
        baseline: "73.2",
        timestamp: Date.now().toString(),
        requiresConfirmation: "true",
      },
      token: fcmToken,
      android: {
        notification: {
          channelId: "anxiety_alerts",
          priority: "high",
          defaultSound: true,
        },
      },
    };

    const pushResponse = await admin.messaging().send(anxietyNotification);
    console.log("✅ FCM push notification sent!");
    console.log(`📱 Message ID: ${pushResponse}`);

    console.log(
      "\n💾 Step 2: Saving to Supabase (where your app reads notifications)..."
    );

    // Save anxiety alert to Supabase notifications table
    const { data: anxietyData, error: anxietyError } = await supabase
      .from("notifications")
      .insert([
        {
          user_id: userId,
          title: "🚨 AnxieEase Anxiety Alert",
          message:
            "Your heart rate is elevated (96 BPM). Are you feeling anxious or stressed?",
          type: "anxiety",
          severity: "mild",
          read: false,
          related_screen: "breathing_screen",
          related_id: `anxiety_${Date.now()}`,
          metadata: {
            heartRate: 96,
            baseline: 73.2,
            deviceId: "AnxieEase001",
            requiresConfirmation: true,
            source: "supabase_test",
          },
        },
      ])
      .select();

    if (anxietyError) throw anxietyError;
    console.log("✅ Anxiety notification saved to Supabase!");
    console.log(`📱 Notification ID: ${anxietyData[0].id}`);

    // Save wellness reminder
    const { data: wellnessData, error: wellnessError } = await supabase
      .from("notifications")
      .insert([
        {
          user_id: userId,
          title: "💚 AnxieEase Wellness Check",
          message:
            "Take a moment to check in with yourself. How are you feeling today?",
          type: "wellness",
          severity: null,
          read: false,
          related_screen: "grounding_screen",
          related_id: `wellness_${Date.now()}`,
          metadata: {
            source: "supabase_test",
            reminderType: "daily_wellness",
          },
        },
      ])
      .select();

    if (wellnessError) throw wellnessError;
    console.log("✅ Wellness notification saved to Supabase!");

    // Send wellness FCM too
    const wellnessFCM = {
      notification: {
        title: "💚 AnxieEase Wellness Check",
        body: "Take a moment to check in with yourself. How are you feeling today?",
      },
      data: {
        type: "wellness",
        timestamp: Date.now().toString(),
      },
      token: fcmToken,
    };

    await admin.messaging().send(wellnessFCM);
    console.log("✅ Wellness FCM notification sent!");

    console.log("\n📊 Step 3: Verifying notifications in Supabase...");

    // Query notifications to verify they were saved
    const { data: allNotifications, error: queryError } = await supabase
      .from("notifications")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(5);

    if (queryError) throw queryError;

    console.log(
      `📱 Found ${allNotifications.length} notifications in Supabase:`
    );
    allNotifications.forEach((notif, index) => {
      console.log(`   ${index + 1}. ${notif.title} (${notif.type})`);
      console.log(
        `      Created: ${new Date(notif.created_at).toLocaleString()}`
      );
      console.log(`      Read: ${notif.read}`);
    });

    console.log("\n🎉 TEST COMPLETE!");
    console.log("==================");
    console.log("✅ FCM notifications sent for background delivery");
    console.log("✅ Notifications saved to Supabase database");
    console.log("✅ Your Flutter app should now show these notifications");

    console.log("\n📱 WHAT TO DO NOW:");
    console.log("==================");
    console.log("1. 🔔 Check your Android notification tray");
    console.log("2. 🚀 Open Flutter app: flutter run");
    console.log("3. 📋 Go to notification screen in app");
    console.log("4. 🏠 Check homepage for notification badges");
    console.log("5. ✅ You should see the anxiety alert and wellness check");
  } catch (error) {
    console.error("❌ Error testing Supabase notifications:", error);
  }

  process.exit(0);
}

testSupabaseNotifications();
