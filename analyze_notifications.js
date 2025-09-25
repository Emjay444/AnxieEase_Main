const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gqsustjxzjzfntcsnvpk.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Your user credentials
const userEmail = 'mjmolina444@gmail.com';
const userPassword = '12345678';

async function analyzeNotifications() {
  try {
    console.log('🔐 Signing in to Supabase...');
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: userEmail,
      password: userPassword,
    });

    if (authError) {
      console.error('❌ Authentication failed:', authError.message);
      return;
    }

    console.log('✅ Authentication successful for:', authData.user.email);
    const userId = authData.user.id;

    // Get ALL notifications for this user (including deleted ones)
    const { data: allNotifications, error: fetchError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false });

    if (fetchError) {
      console.error('❌ Failed to fetch notifications:', fetchError.message);
      return;
    }

    console.log(`\n📊 NOTIFICATION ANALYSIS FOR USER: ${authData.user.email}`);
    console.log('═'.repeat(70));
    console.log(`Total notifications found: ${allNotifications.length}`);

    // Separate active and deleted notifications
    const activeNotifications = allNotifications.filter(n => n.deleted_at === null);
    const deletedNotifications = allNotifications.filter(n => n.deleted_at !== null);

    console.log(`Active notifications: ${activeNotifications.length}`);
    console.log(`Deleted notifications: ${deletedNotifications.length}`);

    // Group by type
    const groupedByType = {};
    activeNotifications.forEach(notif => {
      const type = notif.type || 'unknown';
      if (!groupedByType[type]) {
        groupedByType[type] = [];
      }
      groupedByType[type].push(notif);
    });

    console.log('\n📋 ACTIVE NOTIFICATIONS BY TYPE:');
    console.log('═'.repeat(50));
    Object.keys(groupedByType).forEach(type => {
      console.log(`\n📌 ${type.toUpperCase()} (${groupedByType[type].length} notifications):`);
      groupedByType[type].forEach((notif, index) => {
        const time = new Date(notif.created_at).toLocaleString();
        const readStatus = notif.read ? '✅ Read' : '🔔 Unread';
        const title = notif.title.length > 50 ? notif.title.substring(0, 50) + '...' : notif.title;
        console.log(`   ${index + 1}. ${readStatus} | ${title} | ${time}`);
      });
    });

    // Look for potential duplicates
    console.log('\n🔍 DUPLICATE ANALYSIS:');
    console.log('═'.repeat(50));
    
    const titleGroups = {};
    activeNotifications.forEach(notif => {
      const cleanTitle = notif.title.replace(/[📱💙🫁🚨❤️🧡💛🌟📊🆘]/g, '').trim();
      if (!titleGroups[cleanTitle]) {
        titleGroups[cleanTitle] = [];
      }
      titleGroups[cleanTitle].push(notif);
    });

    const duplicates = Object.keys(titleGroups).filter(title => titleGroups[title].length > 1);
    
    if (duplicates.length > 0) {
      console.log(`\n⚠️  Found ${duplicates.length} potential duplicate groups:`);
      duplicates.forEach(title => {
        const group = titleGroups[title];
        console.log(`\n🔄 "${title}" - ${group.length} duplicates:`);
        group.forEach((notif, index) => {
          const time = new Date(notif.created_at).toLocaleString();
          console.log(`   ${index + 1}. ID: ${notif.id} | Created: ${time} | Read: ${notif.read}`);
        });
      });
    } else {
      console.log('✅ No obvious duplicates found based on titles');
    }

    // Analyze time patterns
    console.log('\n⏰ TIME PATTERN ANALYSIS:');
    console.log('═'.repeat(50));
    
    const today = new Date();
    const timeGroups = {
      'Last Hour': [],
      'Last 6 Hours': [],
      'Last 24 Hours': [],
      'Last Week': [],
      'Older': []
    };

    activeNotifications.forEach(notif => {
      const createdAt = new Date(notif.created_at);
      const hoursDiff = (today - createdAt) / (1000 * 60 * 60);
      
      if (hoursDiff < 1) {
        timeGroups['Last Hour'].push(notif);
      } else if (hoursDiff < 6) {
        timeGroups['Last 6 Hours'].push(notif);
      } else if (hoursDiff < 24) {
        timeGroups['Last 24 Hours'].push(notif);
      } else if (hoursDiff < 168) { // 7 days
        timeGroups['Last Week'].push(notif);
      } else {
        timeGroups['Older'].push(notif);
      }
    });

    Object.keys(timeGroups).forEach(period => {
      const count = timeGroups[period].length;
      if (count > 0) {
        console.log(`📅 ${period}: ${count} notifications`);
      }
    });

    // Show cleanup recommendations
    console.log('\n💡 CLEANUP RECOMMENDATIONS:');
    console.log('═'.repeat(50));
    
    const recommendations = [];
    
    if (duplicates.length > 0) {
      recommendations.push(`🔄 Remove ${duplicates.reduce((sum, title) => sum + titleGroups[title].length - 1, 0)} duplicate notifications`);
    }
    
    if (timeGroups['Older'].length > 10) {
      recommendations.push(`📅 Archive ${timeGroups['Older'].length} old notifications (older than 1 week)`);
    }
    
    const unreadCount = activeNotifications.filter(n => !n.read).length;
    if (unreadCount > 20) {
      recommendations.push(`🔔 Mark ${unreadCount} old unread notifications as read`);
    }
    
    if (recommendations.length === 0) {
      console.log('✅ Your notifications look well-organized!');
    } else {
      recommendations.forEach((rec, index) => {
        console.log(`${index + 1}. ${rec}`);
      });
      
      console.log('\n🛠️  Would you like me to create a cleanup script?');
      console.log('   • Remove duplicates');
      console.log('   • Archive old notifications');
      console.log('   • Mark old notifications as read');
    }

    // Check FCM integration
    console.log('\n📲 FCM INTEGRATION STATUS:');
    console.log('═'.repeat(50));
    console.log('ℹ️  FCM (Firebase Cloud Messaging) analysis requires checking:');
    console.log('   • Firebase Console notification history');
    console.log('   • App notification channels and topics');
    console.log('   • Device registration tokens');
    console.log('   • Current subscription status');
    
    console.log('\n📊 SUMMARY:');
    console.log('═'.repeat(50));
    console.log(`Total notifications: ${allNotifications.length}`);
    console.log(`Active: ${activeNotifications.length} | Deleted: ${deletedNotifications.length}`);
    console.log(`Unread: ${unreadCount} | Read: ${activeNotifications.length - unreadCount}`);
    console.log(`Types: ${Object.keys(groupedByType).join(', ')}`);
    console.log(`Potential duplicates: ${duplicates.length} groups`);

  } catch (error) {
    console.error('❌ Analysis error:', error.message);
  }
}

analyzeNotifications();