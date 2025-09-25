const { createClient } = require('@supabase/supabase-js');
const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://anxieease-sensors-default-rtdb.asia-southeast1.firebasedatabase.app/',
  });
}

// Initialize Supabase
const supabaseUrl = 'https://gqsustjxzjzfntcsnvpk.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Helper function to sleep/wait
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

async function testNotificationsWithBetterDesign() {
  console.log('🎨 NOTIFICATION TEST WITH UI IMPROVEMENTS');
  console.log('=' .repeat(50));
  
  try {
    // Step 1: Authenticate
    console.log('\n🔐 Step 1: Authenticating with Supabase...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: 'mjmolina444@gmail.com',
      password: '12345678'
    });
    
    if (authError) throw authError;
    console.log('✅ Signed in as:', authData.user.email);
    
    const userId = authData.user.id;
    
    // Step 2: Get FCM token
    console.log('\n📱 Step 2: Getting FCM token...');
    const userSnapshot = await admin.database().ref(`users/${userId}`).once('value');
    const userData = userSnapshot.val();
    
    if (!userData?.fcmToken) {
      console.log('❌ No FCM token found. Please run your Flutter app first to register FCM token.');
      return;
    }
    
    const fcmToken = userData.fcmToken;
    console.log('✅ FCM Token found');
    
    // Step 3: Clear old notifications first
    console.log('\n🗑️ Step 3: Clearing old test notifications...');
    const { error: deleteError } = await supabase
      .from('notifications')
      .delete()
      .eq('user_id', userId)
      .or('title.ilike.%test%,title.ilike.%demo%,title.ilike.%🔴%,title.ilike.%💚%,title.ilike.%🫁%');
    
    if (deleteError) {
      console.log('⚠️ Could not clear old notifications:', deleteError.message);
    } else {
      console.log('✅ Cleared old test notifications');
    }
    
    // Wait a moment for deletion to process
    await sleep(2000);
    
    // Step 4: Send better designed push notifications with delays
    console.log('\n📤 Step 4: Sending improved push notifications...');
    
    // Notification 1: High Priority Anxiety Alert
    const anxietyMessage = {
      notification: {
        title: '🚨 Anxiety Alert',
        body: 'Elevated heart rate detected (105 BPM). Take deep breaths and find a calm space.',
      },
      data: {
        type: 'anxiety_alert',
        severity: 'high',
        heartRate: '105',
        timestamp: Date.now().toString(),
        related_screen: 'breathing_screen',
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: 'anxiety_alerts',
          color: '#FF5722',
          sound: 'default',
        },
      },
      token: fcmToken,
    };
    
    const anxietyResponse = await admin.messaging().send(anxietyMessage);
    console.log('✅ Anxiety alert sent! ID:', anxietyResponse.substring(anxietyResponse.lastIndexOf('/') + 1));
    
    // Wait 3 seconds before next notification
    console.log('⏳ Waiting 3 seconds...');
    await sleep(3000);
    
    // Notification 2: Wellness Check-in
    const wellnessMessage = {
      notification: {
        title: '💙 Daily Wellness Check',
        body: 'How are you feeling today? Take a moment to check in with yourself.',
      },
      data: {
        type: 'wellness_reminder',
        timestamp: Date.now().toString(),
        related_screen: 'wellness_check',
      },
      android: {
        priority: 'normal',
        notification: {
          channel_id: 'wellness_reminders',
          color: '#4CAF50',
          sound: 'default',
        },
      },
      token: fcmToken,
    };
    
    const wellnessResponse = await admin.messaging().send(wellnessMessage);
    console.log('✅ Wellness check sent! ID:', wellnessResponse.substring(wellnessResponse.lastIndexOf('/') + 1));
    
    // Wait 2 seconds before next notification
    console.log('⏳ Waiting 2 seconds...');
    await sleep(2000);
    
    // Step 5: Store notifications in Supabase with better design
    console.log('\n💾 Step 5: Storing notifications with improved styling...');
    
    // Store anxiety alert
    const { data: anxietyData, error: anxietyError } = await supabase
      .from('notifications')
      .insert([
        {
          user_id: userId,
          title: '🚨 Anxiety Alert',
          message: 'Elevated heart rate detected (105 BPM). Your wellness is our priority - take deep breaths and find a calm space.',
          type: 'alert',
          read: false,
          related_screen: 'breathing_screen',
          related_id: null
        }
      ])
      .select();
    
    if (anxietyError) {
      console.log('❌ Anxiety notification storage error:', anxietyError);
    } else {
      console.log('✅ Anxiety alert stored in database');
    }
    
    // Store wellness check
    const { data: wellnessData, error: wellnessError } = await supabase
      .from('notifications')
      .insert([
        {
          user_id: userId,
          title: '💙 Daily Wellness Check',
          message: 'Take a moment to reflect on your feelings today. Your mental health journey matters, and we\'re here to support you.',
          type: 'reminder',
          read: false,
          related_screen: 'wellness_check',
          related_id: null
        }
      ])
      .select();
    
    if (wellnessError) {
      console.log('❌ Wellness notification storage error:', wellnessError);
    } else {
      console.log('✅ Wellness check stored in database');
    }
    
    // Store breathing reminder
    const { data: breathingData, error: breathingError } = await supabase
      .from('notifications')
      .insert([
        {
          user_id: userId,
          title: '🌬️ Breathing Exercise',
          message: 'A few minutes of focused breathing can help calm your mind and reduce stress. Try the 4-7-8 technique.',
          type: 'reminder',
          read: false,
          related_screen: 'breathing_screen',
          related_id: null
        }
      ])
      .select();
    
    if (breathingError) {
      console.log('❌ Breathing notification storage error:', breathingError);
    } else {
      console.log('✅ Breathing exercise stored in database');
    }
    
    // Step 6: Verify notifications were saved
    console.log('\n📊 Step 6: Verifying stored notifications...');
    
    const { data: allNotifications, error: queryError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })
      .limit(5);
    
    if (queryError) {
      console.log('❌ Query error:', queryError);
    } else {
      console.log(`✅ Found ${allNotifications.length} recent notifications:`);
      allNotifications.forEach((notif, index) => {
        console.log(`   ${index + 1}. ${notif.title} (${notif.type})`);
        console.log(`      ${notif.message.substring(0, 60)}...`);
        console.log(`      Created: ${new Date(notif.created_at).toLocaleString()}`);
      });
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('🎉 IMPROVED NOTIFICATION TEST COMPLETED!');
    console.log('\n📱 BEHAVIOR EXPLANATION:');
    console.log('===============================');
    console.log('1. 📲 Push notifications appear when app is CLOSED');
    console.log('2. 🏠 In-app notifications appear on homepage when app is OPEN');
    console.log('3. 📋 All notifications are stored in Supabase database');
    console.log('4. 🔄 Opening app after receiving push notifications will show them in-app');
    console.log('5. ⏰ Push notifications may not appear if app was recently opened (Android behavior)');
    
    console.log('\n🧪 TESTING INSTRUCTIONS:');
    console.log('========================');
    console.log('1. 📱 Close your Flutter app COMPLETELY (force close from recents)');
    console.log('2. ⏳ Wait 10 seconds for app to fully close');
    console.log('3. 🔄 Run this script again to send new push notifications');
    console.log('4. 📲 Check your device notification tray for push notifications');
    console.log('5. 🚀 Open Flutter app and check:');
    console.log('   - Homepage "Recent Notifications" section');
    console.log('   - Full notifications screen');
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    // Sign out
    await supabase.auth.signOut();
    console.log('\n🔓 Signed out');
    process.exit(0);
  }
}

testNotificationsWithBetterDesign();