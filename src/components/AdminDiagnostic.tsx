import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { AlertCircle, CheckCircle, Loader2 } from 'lucide-react';

interface DiagnosticResult {
  test: string;
  status: 'pass' | 'fail' | 'pending';
  message: string;
  details?: any;
}

export function AdminDiagnostic() {
  const [results, setResults] = useState<DiagnosticResult[]>([]);
  const [running, setRunning] = useState(false);

  const runDiagnostic = async () => {
    setRunning(true);
    setResults([]);

    const tests: DiagnosticResult[] = [];

    try {
      // Test 1: Check authentication
      tests.push({ test: 'Authentication', status: 'pending', message: 'Checking user authentication...' });
      setResults([...tests]);

      const { data: { user }, error: authError } = await supabase.auth.getUser();
      
      if (authError || !user) {
        tests[0] = { test: 'Authentication', status: 'fail', message: 'User not authenticated', details: authError };
        setResults([...tests]);
        return;
      }

      tests[0] = { test: 'Authentication', status: 'pass', message: `User authenticated: ${user.email}` };
      setResults([...tests]);

      // Test 2: Check profile
      tests.push({ test: 'Profile Check', status: 'pending', message: 'Checking user profile...' });
      setResults([...tests]);

      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

      if (profileError || !profile) {
        tests[1] = { test: 'Profile Check', status: 'fail', message: 'Profile not found', details: profileError };
        setResults([...tests]);
        return;
      }

      tests[1] = { test: 'Profile Check', status: 'pass', message: `Profile found, role: ${profile.role}` };
      setResults([...tests]);

      if (profile.role !== 'admin') {
        tests.push({ test: 'Admin Check', status: 'fail', message: 'User is not an admin' });
        setResults([...tests]);
        return;
      }

      // Test 3: Check table access
      tests.push({ test: 'Table Access', status: 'pending', message: 'Testing table access...' });
      setResults([...tests]);

      const { data: tableData, error: tableError } = await supabase
        .from('user_module_access')
        .select('*')
        .limit(1);

      if (tableError) {
        tests[2] = { test: 'Table Access', status: 'fail', message: 'Cannot access user_module_access table', details: tableError };
        setResults([...tests]);
        return;
      }

      tests[2] = { test: 'Table Access', status: 'pass', message: 'Table access successful' };
      setResults([...tests]);

      // Test 4: Test insert
      tests.push({ test: 'Insert Test', status: 'pending', message: 'Testing module access insert...' });
      setResults([...tests]);

      const { error: insertError } = await supabase
        .from('user_module_access')
        .upsert({
          user_id: user.id,
          module_name: 'global_dashboard',
          has_access: true,
        }, {
          onConflict: 'user_id,module_name'
        });

      if (insertError) {
        tests[3] = { test: 'Insert Test', status: 'fail', message: 'Insert failed', details: insertError };
        setResults([...tests]);
        return;
      }

      tests[3] = { test: 'Insert Test', status: 'pass', message: 'Insert successful' };
      setResults([...tests]);

      // Test 5: Test update
      tests.push({ test: 'Update Test', status: 'pending', message: 'Testing module access update...' });
      setResults([...tests]);

      const { error: updateError } = await supabase
        .from('user_module_access')
        .update({ has_access: false })
        .eq('user_id', user.id)
        .eq('module_name', 'global_dashboard');

      if (updateError) {
        tests[4] = { test: 'Update Test', status: 'fail', message: 'Update failed', details: updateError };
        setResults([...tests]);
        return;
      }

      tests[4] = { test: 'Update Test', status: 'pass', message: 'Update successful' };
      setResults([...tests]);

      // Test 6: Test delete
      tests.push({ test: 'Delete Test', status: 'pending', message: 'Testing module access delete...' });
      setResults([...tests]);

      const { error: deleteError } = await supabase
        .from('user_module_access')
        .delete()
        .eq('user_id', user.id)
        .eq('module_name', 'global_dashboard');

      if (deleteError) {
        tests[5] = { test: 'Delete Test', status: 'fail', message: 'Delete failed', details: deleteError };
        setResults([...tests]);
        return;
      }

      tests[5] = { test: 'Delete Test', status: 'pass', message: 'Delete successful' };
      setResults([...tests]);

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
        <AlertCircle className="h-5 w-5 text-blue-600" />
        Diagnostic des Permissions Administrateur
      </h3>
      
      <button
        onClick={runDiagnostic}
        disabled={running}
        className="mb-4 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
      >
        {running ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" />
            Diagnostic en cours...
          </>
        ) : (
          'Lancer le Diagnostic'
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
                    <summary className="text-xs text-gray-500 cursor-pointer">Détails techniques</summary>
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
    </div>
  );
}
