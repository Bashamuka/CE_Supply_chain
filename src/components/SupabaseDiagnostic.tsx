import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { AlertCircle, CheckCircle, Loader2, Database, Key, User } from 'lucide-react';

interface DiagnosticResult {
  test: string;
  status: 'pass' | 'fail' | 'pending';
  message: string;
  details?: any;
}

export function SupabaseDiagnostic() {
  const [results, setResults] = useState<DiagnosticResult[]>([]);
  const [running, setRunning] = useState(false);

  const runDiagnostic = async () => {
    setRunning(true);
    setResults([]);

    const tests: DiagnosticResult[] = [];

    try {
      // Test 1: Check environment variables
      tests.push({ test: 'Environment Variables', status: 'pending', message: 'Checking environment variables...' });
      setResults([...tests]);

      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

      if (!supabaseUrl || !supabaseAnonKey) {
        tests[0] = { 
          test: 'Environment Variables', 
          status: 'fail', 
          message: 'Missing environment variables',
          details: {
            VITE_SUPABASE_URL: supabaseUrl ? 'Present' : 'Missing',
            VITE_SUPABASE_ANON_KEY: supabaseAnonKey ? 'Present' : 'Missing'
          }
        };
        setResults([...tests]);
        return;
      }

      tests[0] = { 
        test: 'Environment Variables', 
        status: 'pass', 
        message: 'Environment variables present',
        details: {
          VITE_SUPABASE_URL: supabaseUrl,
          VITE_SUPABASE_ANON_KEY: supabaseAnonKey.substring(0, 20) + '...'
        }
      };
      setResults([...tests]);

      // Test 2: Check Supabase connection
      tests.push({ test: 'Supabase Connection', status: 'pending', message: 'Testing database connection...' });
      setResults([...tests]);

      const { data: connectionData, error: connectionError } = await supabase
        .from('profiles')
        .select('count')
        .limit(1);

      if (connectionError) {
        tests[1] = { 
          test: 'Supabase Connection', 
          status: 'fail', 
          message: 'Database connection failed',
          details: connectionError
        };
        setResults([...tests]);
        return;
      }

      tests[1] = { test: 'Supabase Connection', status: 'pass', message: 'Database connection successful' };
      setResults([...tests]);

      // Test 3: Check authentication system
      tests.push({ test: 'Authentication System', status: 'pending', message: 'Testing authentication...' });
      setResults([...tests]);

      const { data: { session }, error: sessionError } = await supabase.auth.getSession();

      if (sessionError) {
        tests[2] = { 
          test: 'Authentication System', 
          status: 'fail', 
          message: 'Authentication system error',
          details: sessionError
        };
        setResults([...tests]);
        return;
      }

      tests[2] = { 
        test: 'Authentication System', 
        status: 'pass', 
        message: 'Authentication system working',
        details: { currentSession: session ? 'Active' : 'None' }
      };
      setResults([...tests]);

      // Test 4: Test login with provided credentials
      tests.push({ test: 'Login Test', status: 'pending', message: 'Testing login with provided credentials...' });
      setResults([...tests]);

      const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({
        email: 'pacifiquebashamuka@gmail.com',
        password: 'admin'
      });

      if (loginError) {
        tests[3] = { 
          test: 'Login Test', 
          status: 'fail', 
          message: 'Login failed',
          details: {
            code: loginError.status,
            message: loginError.message,
            error: loginError
          }
        };
        setResults([...tests]);
        return;
      }

      if (!loginData?.user) {
        tests[3] = { 
          test: 'Login Test', 
          status: 'fail', 
          message: 'No user returned after login'
        };
        setResults([...tests]);
        return;
      }

      tests[3] = { 
        test: 'Login Test', 
        status: 'pass', 
        message: 'Login successful',
        details: { 
          userId: loginData.user.id,
          email: loginData.user.email
        }
      };
      setResults([...tests]);

      // Test 5: Check user profile
      tests.push({ test: 'User Profile', status: 'pending', message: 'Checking user profile...' });
      setResults([...tests]);

      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', loginData.user.id)
        .single();

      if (profileError) {
        tests[4] = { 
          test: 'User Profile', 
          status: 'fail', 
          message: 'Profile retrieval failed',
          details: profileError
        };
        setResults([...tests]);
      } else {
        tests[4] = { 
          test: 'User Profile', 
          status: 'pass', 
          message: 'Profile retrieved successfully',
          details: { role: profile?.role || 'No role assigned' }
        };
        setResults([...tests]);
      }

      // Sign out after test
      await supabase.auth.signOut();

    } catch (error: any) {
      tests.push({ test: 'General Error', status: 'fail', message: 'Unexpected error', details: error });
      setResults([...tests]);
    } finally {
      setRunning(false);
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
      <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center gap-2">
        <Database className="h-5 w-5 text-blue-600" />
        Supabase Connection Diagnostic
      </h3>
      
      <button
        onClick={runDiagnostic}
        disabled={running}
        className="mb-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
      >
        {running ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" />
            Running Diagnostic...
          </>
        ) : (
          'Run Supabase Diagnostic'
        )}
      </button>

      {results.length > 0 && (
        <div className="space-y-3">
          {results.map((result, index) => (
            <div key={index} className="flex items-start gap-3 p-3 rounded-lg border">
              {result.status === 'pending' && (
                <Loader2 className="h-5 w-5 animate-spin text-blue-600 mt-0.5" />
              )}
              {result.status === 'pass' && (
                <CheckCircle className="h-5 w-5 text-green-600 mt-0.5" />
              )}
              {result.status === 'fail' && (
                <AlertCircle className="h-5 w-5 text-red-600 mt-0.5" />
              )}
              
              <div className="flex-1">
                <div className="font-medium text-gray-900">{result.test}</div>
                <div className={`text-sm ${
                  result.status === 'pass' ? 'text-green-700' : 
                  result.status === 'fail' ? 'text-red-700' : 
                  'text-blue-700'
                }`}>
                  {result.message}
                </div>
                {result.details && (
                  <details className="mt-2">
                    <summary className="text-xs text-gray-500 cursor-pointer">Technical Details</summary>
                    <pre className="text-xs bg-gray-100 p-2 rounded mt-1 overflow-auto">
                      {JSON.stringify(result.details, null, 2)}
                    </pre>
                  </details>
                )}
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="mt-4 p-3 bg-yellow-50 border-l-4 border-yellow-400 rounded">
        <div className="flex">
          <AlertCircle className="w-5 h-5 text-yellow-600 mt-0.5 mr-3 flex-shrink-0" />
          <div>
            <p className="text-sm text-yellow-800">
              <strong>Note:</strong> If the login test fails, check that the user account exists in your Supabase database 
              and that the password is correct. The test uses: pacifiquebashamuka@gmail.com / admin
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
