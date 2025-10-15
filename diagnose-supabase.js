// Diagnostic script for Supabase connection
// Run this in the browser console to check configuration

console.log('🔍 SUPABASE CONNECTION DIAGNOSTIC');
console.log('================================');

// Check environment variables
console.log('📋 Environment Variables:');
console.log('VITE_SUPABASE_URL:', import.meta.env.VITE_SUPABASE_URL);
console.log('VITE_SUPABASE_ANON_KEY:', import.meta.env.VITE_SUPABASE_ANON_KEY ? 'Present' : 'Missing');

// Check if Supabase client is created
try {
  const { createClient } = await import('@supabase/supabase-js');
  
  const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
  const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
  
  if (!supabaseUrl || !supabaseAnonKey) {
    console.error('❌ Missing environment variables');
    console.log('Expected: VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY');
  } else {
    console.log('✅ Environment variables present');
    
    // Test Supabase connection
    const supabase = createClient(supabaseUrl, supabaseAnonKey);
    
    console.log('🔗 Testing Supabase connection...');
    
    // Test 1: Check if we can connect to Supabase
    try {
      const { data, error } = await supabase.from('profiles').select('count').limit(1);
      if (error) {
        console.error('❌ Supabase connection failed:', error);
      } else {
        console.log('✅ Supabase connection successful');
      }
    } catch (err) {
      console.error('❌ Supabase connection error:', err);
    }
    
    // Test 2: Check authentication
    console.log('🔐 Testing authentication...');
    try {
      const { data: { session }, error } = await supabase.auth.getSession();
      if (error) {
        console.error('❌ Auth session error:', error);
      } else {
        console.log('✅ Auth session check successful');
        console.log('Current session:', session ? 'Active' : 'None');
      }
    } catch (err) {
      console.error('❌ Auth session error:', err);
    }
    
    // Test 3: Try to sign in with test credentials
    console.log('🧪 Testing login with provided credentials...');
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: 'pacifiquebashamuka@gmail.com',
        password: 'admin'
      });
      
      if (error) {
        console.error('❌ Login test failed:', error);
        console.log('Error details:', {
          code: error.status,
          message: error.message,
          details: error
        });
      } else {
        console.log('✅ Login test successful');
        console.log('User data:', data.user);
        
        // Sign out after test
        await supabase.auth.signOut();
      }
    } catch (err) {
      console.error('❌ Login test error:', err);
    }
  }
} catch (err) {
  console.error('❌ Script error:', err);
}

console.log('================================');
console.log('🏁 Diagnostic complete');
