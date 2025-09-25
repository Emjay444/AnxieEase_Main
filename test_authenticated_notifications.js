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

async function testNotificationsWithAuth() {
  console.log('🔔 AUTHENTICATED NOTIFICATION TEST');
  console.log('=' .repeat(50));
  
  try {
    // Step 1: Authenticate as your user
    console.log('\n🔐 Step 1: Authenticating with Supabase...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: 'mjmolina444@gmail.com',
      password: '12345678'
    });
    
    if (authError) throw authError;
    console.log('✅ Signed in as:', authData.user.email);
    console.log('📱 User ID:', authData.user.id);
    
    const userId = authData.user.id;
    
    // Step 2: Get user's FCM token for push notifications
    console.log('\n🔍 Step 2: Getting FCM token...');
    const userSnapshot = await admin.database().ref(`users/${userId}`).once('value');
    const userData = userSnapshot.val();
    
    if (!userData) {
      console.log('⚠️ No user data found in Firebase RTDB');
      return;
    }
    
    const fcmToken = userData.fcmToken;
    console.log('📱 FCM Token found:', fcmToken ? 'Yes' : 'No');
    
    // Step 3: Send FCM push notifications (works when app is closed)
    console.log('\n📤 Step 3: Sending FCM push notifications...');
    
    // Send anxiety alert notification
    const anxietyMessage = {
      notification: {
        title: '🔴 Anxiety Alert Detected',
        body: 'We detected elevated anxiety levels. Take a moment to breathe and check in with yourself.',
      },
      data: {
        type: 'anxiety_alert',
        severity: 'moderate',
        heartRate: '95',
        timestamp: Date.now().toString(),
        related_screen: 'anxiety_management',
      },
      token: fcmToken,
    };
    
    const anxietyResponse = await admin.messaging().send(anxietyMessage);
    console.log('✅ Anxiety alert sent! ID:', anxietyResponse);
    
    // Send wellness reminder notification
    const wellnessMessage = {
      notification: {
        title: '💚 Wellness Check-in',
        body: 'Time for your wellness check-in! How are you feeling right now?',
      },
      data: {
        type: 'wellness_reminder',
        timestamp: Date.now().toString(),
        related_screen: 'wellness_check',
      },
      token: fcmToken,
    };
    
    const wellnessResponse = await admin.messaging().send(wellnessMessage);
    console.log('✅ Wellness reminder sent! ID:', wellnessResponse);
    
    // Step 4: Insert notifications into Supabase (for in-app display)
    console.log('\n💾 Step 4: Storing notifications in Supabase...');
    
    // Insert anxiety alert notification
    const { data: anxietyData, error: anxietyError } = await supabase
      .from('notifications')
      .insert([
        {
          user_id: userId,
          title: '🔴 Anxiety Alert Detected',
          message: 'We detected elevated anxiety levels. Take a moment to breathe and check in with yourself.',
          type: 'alert', // Valid enum value
          read: false,
          related_screen: 'anxiety_management',
          related_id: null
        }
      ])
      .select();
    
    if (anxietyError) {
      console.log('❌ Anxiety notification error:', anxietyError);
    } else {
      console.log('✅ Anxiety notification stored!');
      console.log('📱 ID:', anxietyData[0].id);
    }
    
    // Insert wellness notification
    const { data: wellnessData, error: wellnessError } = await supabase
      .from('notifications')
      .insert([
        {
          user_id: userId,
          title: '💚 Wellness Check-in',
          message: 'Time for your wellness check-in! How are you feeling right now?',
          type: 'reminder', // Valid enum value
          read: false,
          related_screen: 'wellness_check',
          related_id: null
        }
      ])
      .select();
    
    if (wellnessError) {
      console.log('❌ Wellness notification error:', wellnessError);
    } else {
      console.log('✅ Wellness notification stored!');
      console.log('📱 ID:', wellnessData[0].id);
    }
    
    // Insert breathing reminder notification
    const { data: breathingData, error: breathingError } = await supabase
      .from('notifications')
      .insert([
        {
          user_id: userId,
          title: '🫁 Breathing Exercise Reminder',
          message: 'Take a moment to practice deep breathing. Your mental health matters.',
          type: 'reminder', // Valid enum value
          read: false,
          related_screen: 'breathing_screen',
          related_id: null
        }
      ])
      .select();
    
    if (breathingError) {
      console.log('❌ Breathing notification error:', breathingError);
    } else {
      console.log('✅ Breathing notification stored!');
      console.log('📱 ID:', breathingData[0].id);
    }
    
    // Step 5: Verify notifications were saved
    console.log('\n📊 Step 5: Verifying notifications in Supabase...');
    
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
        console.log(`      Created: ${new Date(notif.created_at).toLocaleString()}`);
      });
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('🎉 NOTIFICATION TEST COMPLETED!');
    console.log('\n📱 TESTING INSTRUCTIONS:');
    console.log('1. Close your Flutter app completely');
    console.log('2. You should receive push notifications on your device');
    console.log('3. Open the app and check:');
    console.log('   - Homepage notification section');
    console.log('   - Notifications screen');
    console.log('4. Notifications should appear in both locations');
    
  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    // Sign out
    await supabase.auth.signOut();
    console.log('\n🔓 Signed out');
    process.exit(0);
  }
}

testNotificationsWithAuth();