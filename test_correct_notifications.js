const { createClient } = require("@supabase/supabase-js");
const admin = require("firebase-admin");

// Initialize Firebase Admin for FCM only
const serviceAccount = require("./service-account-key.json");
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

// Initialize Supabase
const supabaseUrl = "https://gqsustjxzjzfntcsnvpk.supabase.co";
const supabaseAnonKey =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA";
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function testSupabaseNotificationsCorrect() {
  console.log(
    "🚀 Testing Supabase notifications with correct table structure...\n"
  );

  try {
    // Use the user ID from your app logs
    const userId = "5afad7d4-3dcd-4353-badb-4f155303419a";
    const fcmToken =
      "cn2XBAlSTHCrCok-hqkTJy:APA91bHk8LIQFq86JaCHLFv_Sv5P7MPB8WiomcfQzY7lr8fD9zT0hOmKjYjvUUL__7LBQ2LHPgjNSC4-gWDW3FFGviliw9wy7AbaahO6iyTxYOJT63yl7r0";

    console.log("📱 Step 1: Sending FCM push notifications...");

    // Send anxiety alert FCM notification
    const anxietyFCM = {
      notification: {
        title: "🚨 AnxieEase Anxiety Alert",
        body: "Your heart rate is elevated (97 BPM). Are you feeling anxious?",
      },
      data: {
        type: "anxiety",
        severity: "mild",
        heartRate: "97",
        timestamp: Date.now().toString(),
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

    const anxietyResponse = await admin.messaging().send(anxietyFCM);
    console.log("✅ Anxiety FCM sent:", anxietyResponse);

    // Send wellness FCM notification
    const wellnessFCM = {
      notification: {
        title: "💚 Wellness Check-in",
        body: "Take a moment to breathe and check in with yourself.",
      },
      data: {
        type: "wellness",
        timestamp: Date.now().toString(),
      },
      token: fcmToken,
    };

    const wellnessResponse = await admin.messaging().send(wellnessFCM);
    console.log("✅ Wellness FCM sent:", wellnessResponse);

    console.log(
      "\n💾 Step 2: Saving notifications to Supabase (correct table structure)..."
    );

    // Insert anxiety notification using exact table schema
    const { data: anxietyData, error: anxietyError } = await supabase
      .from("notifications")
      .insert([
        {
          user_id: userId,
          title: "🚨 AnxieEase Anxiety Alert",
          message:
            "Your heart rate is elevated (97 BPM). Are you feeling anxious or stressed? Tap to respond.",
          type: "alert", // Using notification_type enum
          read: false,
          related_screen: "breathing_screen",
          related_id: null, // UUID or null
        },
      ])
      .select();

    if (anxietyError) {
      console.log("❌ Anxiety notification error:", anxietyError);
    } else {
      console.log("✅ Anxiety notification saved!");
      console.log("📱 ID:", anxietyData[0].id);
    }

    // Insert wellness notification
    const { data: wellnessData, error: wellnessError } = await supabase
      .from("notifications")
      .insert([
        {
          user_id: userId,
          title: "💚 Wellness Check-in",
          message:
            "Take a moment to breathe and check in with yourself. How are you feeling right now?",
          type: "reminder", // Using notification_type enum
          read: false,
          related_screen: "grounding_screen",
          related_id: null,
        },
      ])
      .select();

    if (wellnessError) {
      console.log("❌ Wellness notification error:", wellnessError);
    } else {
      console.log("✅ Wellness notification saved!");
      console.log("📱 ID:", wellnessData[0].id);
    }

    // Insert a test notification too
    const { data: testData, error: testError } = await supabase
      .from("notifications")
      .insert([
        {
          user_id: userId,
          title: "🧪 System Test",
          message:
            "This is a test notification to verify your notification system is working correctly.",
          type: "system",
          read: false,
          related_screen: null,
          related_id: null,
        },
      ])
      .select();

    if (testError) {
      console.log("❌ Test notification error:", testError);
    } else {
      console.log("✅ Test notification saved!");
      console.log("📱 ID:", testData[0].id);
    }

    console.log("\n📊 Step 3: Verifying notifications in Supabase...");

    // Query recent notifications for this user
    const { data: allNotifications, error: queryError } = await supabase
      .from("notifications")
      .select("id, title, message, type, read, created_at, related_screen")
      .eq("user_id", userId)
      .is("deleted_at", null) // Only active notifications
      .order("created_at", { ascending: false })
      .limit(5);

    if (queryError) {
      console.log("❌ Query error:", queryError);
    } else {
      console.log(`📱 Found ${allNotifications.length} recent notifications:`);
      allNotifications.forEach((notif, index) => {
        console.log(`   ${index + 1}. ${notif.title} (${notif.type})`);
        console.log(`      ${notif.message}`);
        console.log(
          `      Created: ${new Date(notif.created_at).toLocaleString()}`
        );
        console.log(
          `      Read: ${notif.read}, Screen: ${notif.related_screen}`
        );
        console.log("");
      });
    }

    console.log("\n🎉 SUPABASE NOTIFICATION TEST COMPLETE!");
    console.log("=======================================");
    console.log("✅ FCM push notifications sent (for background/closed app)");
    console.log("✅ Notifications saved to Supabase (for in-app display)");
    console.log("✅ Your Flutter app should now show these notifications!");

    console.log("\n📱 TESTING INSTRUCTIONS:");
    console.log("========================");
    console.log("1. 🔔 Check Android notification tray (FCM notifications)");
    console.log("2. 🚀 Open Flutter app: flutter run");
    console.log("3. 📋 Navigate to notification screen in your app");
    console.log("4. 🏠 Check homepage for notification badges/indicators");
    console.log("5. ✅ You should see:");
    console.log("   - Anxiety Alert (97 BPM)");
    console.log("   - Wellness Check-in");
    console.log("   - System Test notification");
    console.log(
      "6. 📱 Tap notifications to test navigation to related screens"
    );

    console.log("\n🔄 FOR BACKGROUND TESTING:");
    console.log("===========================");
    console.log("1. Close Flutter app completely");
    console.log("2. Wait for automatic anxiety detection (HR > 88 BPM)");
    console.log("3. Or wait 30 seconds and run this script again");
    console.log("4. Notifications will appear in Android tray");
    console.log("5. Open app to see them saved in notification screen");
  } catch (error) {
    console.error("❌ Error testing Supabase notifications:", error);
  }

  process.exit(0);
}

testSupabaseNotificationsCorrect();
