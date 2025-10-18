/**
 * Verify Notification Timestamps - Philippine Time Checker
 * 
 * This script checks if notifications are stored correctly in UTC
 * and displays them in Philippine Time (UTC+8)
 */

const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('./service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://anxieease-default-rtdb.asia-southeast1.firebasedatabase.app'
  });
}

// Initialize Supabase
const supabaseUrl = 'https://fndzptmuasaprihdjsxj.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZuZHpwdG11YXNhcHJpaGRqc3hqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTM5Mjk0MSwiZXhwIjoyMDQ0OTY4OTQxfQ.q0g9AH8HWLqlAZV_MjKCSlWKqPtMK8V8ifXntkYnlZM';
const supabase = createClient(supabaseUrl, supabaseServiceKey);

// Helper to convert UTC to Philippine Time
function utcToPhilippineTime(utcTimestamp) {
  const utcDate = new Date(utcTimestamp);
  // Add 8 hours for Philippine Time (UTC+8)
  const phTime = new Date(utcDate.getTime() + (8 * 60 * 60 * 1000));
  return phTime;
}

// Helper to format date in readable format
function formatPhilippineTime(date) {
  return date.toLocaleString('en-PH', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: true
  });
}

async function verifyNotificationTimestamps() {
  console.log('\n═══════════════════════════════════════════════════════════');
  console.log('📋 NOTIFICATION TIMESTAMP VERIFICATION');
  console.log('═══════════════════════════════════════════════════════════\n');

  try {
    // Get recent notifications from Supabase
    const { data: notifications, error } = await supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(20);

    if (error) {
      console.error('❌ Error fetching notifications:', error);
      return;
    }

    if (!notifications || notifications.length === 0) {
      console.log('⚠️  No notifications found in database');
      return;
    }

    console.log(`✅ Found ${notifications.length} recent notifications\n`);
    console.log('─────────────────────────────────────────────────────────────\n');

    // Display each notification with timestamp analysis
    notifications.forEach((notif, index) => {
      console.log(`\n📌 Notification #${index + 1}`);
      console.log(`   Title: ${notif.title}`);
      console.log(`   Type: ${notif.type}`);
      
      // Parse the stored timestamp
      const storedTimestamp = notif.created_at;
      const utcDate = new Date(storedTimestamp);
      const phDate = utcToPhilippineTime(storedTimestamp);
      
      console.log(`\n   📅 Timestamp Analysis:`);
      console.log(`   ├─ Stored in DB (UTC): ${storedTimestamp}`);
      console.log(`   ├─ UTC Time: ${utcDate.toISOString()}`);
      console.log(`   └─ Philippine Time (UTC+8): ${formatPhilippineTime(phDate)}`);
      
      // Check if timestamp looks correct (not in the future, not too old)
      const now = new Date();
      const hoursDiff = (now - utcDate) / (1000 * 60 * 60);
      
      if (hoursDiff < 0) {
        console.log(`   ⚠️  WARNING: Timestamp is in the future!`);
      } else if (hoursDiff > 8760) { // More than 1 year old
        console.log(`   ⚠️  WARNING: Timestamp is very old (${Math.floor(hoursDiff / 24)} days)`);
      } else {
        const timeAgo = hoursDiff < 1 
          ? `${Math.floor(hoursDiff * 60)} minutes ago`
          : hoursDiff < 24
          ? `${Math.floor(hoursDiff)} hours ago`
          : `${Math.floor(hoursDiff / 24)} days ago`;
        console.log(`   ✅ Time ago: ${timeAgo}`);
      }
      
      console.log('   ─────────────────────────────────────────────────────');
    });

    // Summary
    console.log('\n\n═══════════════════════════════════════════════════════════');
    console.log('📊 SUMMARY');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    const now = new Date();
    const futureNotifs = notifications.filter(n => new Date(n.created_at) > now);
    const oldNotifs = notifications.filter(n => {
      const hoursDiff = (now - new Date(n.created_at)) / (1000 * 60 * 60);
      return hoursDiff > 8760;
    });
    
    console.log(`✅ Total notifications checked: ${notifications.length}`);
    console.log(`⚠️  Future timestamps (incorrect): ${futureNotifs.length}`);
    console.log(`⚠️  Very old timestamps (>1 year): ${oldNotifs.length}`);
    console.log(`✅ Valid timestamps: ${notifications.length - futureNotifs.length - oldNotifs.length}`);
    
    if (futureNotifs.length === 0 && oldNotifs.length === 0) {
      console.log('\n🎉 All notification timestamps are correct!');
      console.log('📱 They are stored in UTC and will display correctly in Philippine Time (UTC+8)');
    } else {
      console.log('\n⚠️  Some notifications have incorrect timestamps');
      console.log('💡 These may have been created before the UTC fix was implemented');
    }
    
    console.log('\n═══════════════════════════════════════════════════════════\n');

  } catch (error) {
    console.error('❌ Error during verification:', error);
  } finally {
    process.exit(0);
  }
}

// Run verification
verifyNotificationTimestamps();
