const { createClient } = require('@supabase/supabase-js');

// Initialize Supabase
const supabaseUrl = 'https://gqsustjxzjzfntcsnvpk.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

async function checkSupabaseStructure() {
  console.log('🔍 Checking Supabase notifications table structure...\n');
  
  try {
    // First, let's sign in as the test user
    const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
      email: 'mjmolina444@gmail.com',
      password: 'kevin123'
    });
    
    if (authError) throw authError;
    console.log('✅ Signed in as:', authData.user.email);
    console.log('📱 User ID:', authData.user.id);
    
    // Try to get existing notifications to see table structure
    const { data: notifications, error: queryError } = await supabase
      .from('notifications')
      .select('*')
      .limit(1);
    
    if (queryError) {
      console.log('❌ Query error:', queryError);
    } else {
      console.log('\n📋 Current notifications table structure:');
      if (notifications.length > 0) {
        console.log('Columns:', Object.keys(notifications[0]));
        console.log('Sample notification:', notifications[0]);
      } else {
        console.log('No notifications found, will try to insert a simple one...');
      }
    }
    
    // Try a simple insert to see what columns are available
    console.log('\n📝 Attempting to insert a simple notification...');
    
    const { data: insertData, error: insertError } = await supabase
      .from('notifications')
      .insert([
        {
          user_id: authData.user.id,
          title: '🧪 Test Notification',
          message: 'This is a test notification from Supabase',
          type: 'test',
          read: false
        }
      ])
      .select();
    
    if (insertError) {
      console.log('❌ Insert error:', insertError);
      console.log('This tells us about the table structure requirements');
    } else {
      console.log('✅ Successfully inserted notification!');
      console.log('📱 Inserted notification:', insertData[0]);
      
      // Now try to query it back
      const { data: verifyData, error: verifyError } = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', authData.user.id)
        .eq('type', 'test')
        .order('created_at', { ascending: false })
        .limit(1);
      
      if (verifyError) {
        console.log('❌ Verification error:', verifyError);
      } else {
        console.log('✅ Verification successful!');
        console.log('📋 Retrieved notification:', verifyData[0]);
      }
    }
    
  } catch (error) {
    console.error('❌ Error:', error);
  }
  
  process.exit(0);
}

checkSupabaseStructure();