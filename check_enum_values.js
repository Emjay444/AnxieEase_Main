const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://gqsustjxzjzfntcsnvpk.supabase.co', 
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdxc3VzdGp4emp6Zm50Y3NudnBrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyMDg4NTgsImV4cCI6MjA1Njc4NDg1OH0.RCS_0fSVYnYVY2qr0Ow1__vBC4WRaVg_2SDatKREVHA'
);

async function checkSchema() {
  console.log('🔍 Checking existing notification types...');
  
  // Get existing notifications to see what types are used
  const { data, error } = await supabase
    .from('notifications')
    .select('type, title, message')
    .order('created_at', { ascending: false })
    .limit(15);
    
  if (error) {
    console.log('❌ Error querying notifications:', error);
    return;
  }
  
  console.log(`📊 Found ${data.length} notifications:`);
  data.forEach((notif, i) => {
    console.log(`${i + 1}.) Type: "${notif.type}", Title: "${notif.title.substring(0, 50)}..."`);
  });
  
  const uniqueTypes = [...new Set(data.map(n => n.type))];
  console.log('\n✅ Valid notification_type enum values found:');
  uniqueTypes.forEach(type => console.log(`   - "${type}"`));
  
  // Test inserting with different types to find which ones work
  console.log('\n🧪 Testing enum values...');
  const testTypes = ['alert', 'reminder', 'anxiety', 'wellness', 'system'];
  const userId = '5afad7d4-3dcd-4353-badb-4f155303419a';
  
  for (const testType of testTypes) {
    const { data: insertData, error: insertError } = await supabase
      .from('notifications')
      .insert({
        user_id: userId,
        title: `Test ${testType}`,
        message: 'Testing enum validation',
        type: testType,
        read: false
      })
      .select();
    
    if (insertError) {
      console.log(`❌ "${testType}" - ${insertError.message}`);
    } else {
      console.log(`✅ "${testType}" - Valid!`);
      // Clean up test record
      if (insertData && insertData[0]) {
        await supabase
          .from('notifications')
          .delete()
          .eq('id', insertData[0].id);
      }
    }
  }
}

checkSchema().catch(console.error);