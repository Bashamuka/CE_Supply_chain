// Test script to diagnose the admin permission issue
// This will help us understand what's happening with the authentication

import { supabase } from './src/lib/supabase';

async function diagnoseAdminIssue() {
  console.log('=== DIAGNOSTIC ADMIN PERMISSIONS ===');
  
  try {
    // 1. Check current user authentication
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    console.log('1. Current user:', user ? user.id : 'No user');
    console.log('1. Auth error:', authError);
    
    if (!user) {
      console.log('❌ No authenticated user');
      return;
    }
    
    // 2. Check user profile
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();
    
    console.log('2. Profile:', profile);
    console.log('2. Profile error:', profileError);
    
    if (!profile) {
      console.log('❌ No profile found');
      return;
    }
    
    console.log('2. User role:', profile.role);
    
    // 3. Test direct database access
    const { data: testData, error: testError } = await supabase
      .from('user_module_access')
      .select('*')
      .limit(1);
    
    console.log('3. Test query result:', testData);
    console.log('3. Test query error:', testError);
    
    // 4. Test inserting a module access
    const testUserId = user.id;
    const testModule = 'global_dashboard';
    
    console.log('4. Testing module access insert...');
    const { error: insertError } = await supabase
      .from('user_module_access')
      .upsert({
        user_id: testUserId,
        module_name: testModule,
        has_access: true,
      }, {
        onConflict: 'user_id,module_name'
      });
    
    console.log('4. Insert error:', insertError);
    
    if (insertError) {
      console.log('❌ Insert failed:', insertError);
      console.log('Error code:', insertError.code);
      console.log('Error message:', insertError.message);
      console.log('Error details:', insertError.details);
      console.log('Error hint:', insertError.hint);
    } else {
      console.log('✅ Insert successful');
    }
    
    // 5. Check RLS policies
    console.log('5. Checking RLS policies...');
    const { data: policies, error: policiesError } = await supabase
      .rpc('get_table_policies', { table_name: 'user_module_access' });
    
    console.log('5. Policies:', policies);
    console.log('5. Policies error:', policiesError);
    
  } catch (error) {
    console.error('❌ Diagnostic failed:', error);
  }
}

// Run the diagnostic
diagnoseAdminIssue();
