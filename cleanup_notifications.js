const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://gqsustjxzjzfntcsnvpk.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA';

const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Your user credentials
const userEmail = 'mjmolina444@gmail.com';
const userPassword = '12345678';

async function cleanupNotifications() {
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

    // Get all notifications
    const { data: allNotifications, error: fetchError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (fetchError) {
      console.error('❌ Failed to fetch notifications:', fetchError.message);
      return;
    }

    console.log(`\n🧹 STARTING NOTIFICATION CLEANUP`);
    console.log('═'.repeat(50));
    console.log(`Found ${allNotifications.length} active notifications to analyze`);

    // Group by title to find duplicates
    const titleGroups = {};
    allNotifications.forEach(notif => {
      const cleanTitle = notif.title.replace(/[📱💙🫁🚨❤️🧡💛🌟📊🆘🌬️]/g, '').trim();
      if (!titleGroups[cleanTitle]) {
        titleGroups[cleanTitle] = [];
      }
      titleGroups[cleanTitle].push(notif);
    });

    // Find and remove duplicates (keep the most recent one)
    const duplicateGroups = Object.keys(titleGroups).filter(title => titleGroups[title].length > 1);
    let removedCount = 0;

    if (duplicateGroups.length > 0) {
      console.log(`\n🔄 Found ${duplicateGroups.length} duplicate groups. Cleaning up...`);
      
      for (const title of duplicateGroups) {
        const notifications = titleGroups[title];
        // Sort by creation date (newest first)
        notifications.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
        
        // Keep the first (newest) and mark others for deletion
        const toKeep = notifications[0];
        const toRemove = notifications.slice(1);
        
        console.log(`\n📝 "${title}":`);
        console.log(`   ✅ Keeping: ${new Date(toKeep.created_at).toLocaleString()} (ID: ${toKeep.id.substring(0, 8)}...)`);
        
        for (const notif of toRemove) {
          try {
            // Soft delete by setting deleted_at timestamp
            const { error: deleteError } = await supabase
              .from('notifications')
              .update({ deleted_at: new Date().toISOString() })
              .eq('id', notif.id)
              .eq('user_id', userId);

            if (deleteError) {
              console.error(`   ❌ Failed to remove ${notif.id}: ${deleteError.message}`);
            } else {
              console.log(`   🗑️  Removed: ${new Date(notif.created_at).toLocaleString()} (ID: ${notif.id.substring(0, 8)}...)`);
              removedCount++;
            }
          } catch (error) {
            console.error(`   ❌ Error removing ${notif.id}:`, error.message);
          }
        }
      }
    } else {
      console.log('✅ No duplicates found to clean up');
    }

    // Optional: Mark very old unread notifications as read
    const oldThreshold = new Date();
    oldThreshold.setHours(oldThreshold.getHours() - 6); // 6 hours ago

    const oldUnreadNotifications = allNotifications.filter(notif => 
      !notif.read && 
      new Date(notif.created_at) < oldThreshold &&
      !notif.deleted_at
    );

    let markedReadCount = 0;
    if (oldUnreadNotifications.length > 0) {
      console.log(`\n📖 Found ${oldUnreadNotifications.length} old unread notifications. Marking as read...`);
      
      for (const notif of oldUnreadNotifications) {
        try {
          const { error: updateError } = await supabase
            .from('notifications')
            .update({ read: true })
            .eq('id', notif.id)
            .eq('user_id', userId);

          if (updateError) {
            console.error(`   ❌ Failed to mark as read: ${updateError.message}`);
          } else {
            const title = notif.title.length > 40 ? notif.title.substring(0, 40) + '...' : notif.title;
            console.log(`   📖 Marked as read: ${title}`);
            markedReadCount++;
          }
        } catch (error) {
          console.error(`   ❌ Error marking as read:`, error.message);
        }
      }
    }

    // Get updated statistics
    const { data: finalNotifications, error: finalError } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', userId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (!finalError) {
      const finalUnreadCount = finalNotifications.filter(n => !n.read).length;
      
      console.log(`\n✨ CLEANUP COMPLETE!`);
      console.log('═'.repeat(50));
      console.log(`🗑️  Removed duplicates: ${removedCount}`);
      console.log(`📖 Marked as read: ${markedReadCount}`);
      console.log(`📊 Final active notifications: ${finalNotifications.length}`);
      console.log(`🔔 Final unread notifications: ${finalUnreadCount}`);
      
      console.log(`\n📱 Your AnxieEase app should now show:`);
      console.log(`   • Clean notification list without duplicates`);
      console.log(`   • Better organized notification history`);
      console.log(`   • Reduced notification badge count`);
      console.log(`   • Improved app performance`);

      // Show remaining notifications by type
      const typeGroups = {};
      finalNotifications.forEach(notif => {
        const type = notif.type || 'unknown';
        if (!typeGroups[type]) typeGroups[type] = 0;
        typeGroups[type]++;
      });

      console.log(`\n📋 Remaining notifications by type:`);
      Object.keys(typeGroups).forEach(type => {
        console.log(`   ${type.toUpperCase()}: ${typeGroups[type]}`);
      });
    }

  } catch (error) {
    console.error('❌ Cleanup error:', error.message);
  }
}

cleanupNotifications();