import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { AlertCircle, CheckCircle, Loader2, RefreshCw } from 'lucide-react';

export function SupabaseConnectionDiagnostic() {
  const [isRunning, setIsRunning] = useState(false);
  const [results, setResults] = useState<Array<{
    test: string;
    status: 'success' | 'error' | 'warning';
    message: string;
    details?: any;
  }>>([]);

  const runDiagnostic = async () => {
    setIsRunning(true);
    setResults([]);
    
    const testResults: Array<{
      test: string;
      status: 'success' | 'error' | 'warning';
      message: string;
      details?: any;
    }> = [];

    // Test 1: Environment Variables
    try {
      const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
      const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
      
      if (!supabaseUrl || !supabaseKey) {
        testResults.push({
          test: 'Environment Variables',
          status: 'error',
          message: 'Missing Supabase environment variables',
          details: { url: !!supabaseUrl, key: !!supabaseKey }
        });
      } else {
        testResults.push({
          test: 'Environment Variables',
          status: 'success',
          message: 'Environment variables are properly configured',
          details: { url: supabaseUrl.substring(0, 30) + '...', key: supabaseKey.substring(0, 20) + '...' }
        });
      }
    } catch (error) {
      testResults.push({
        test: 'Environment Variables',
        status: 'error',
        message: 'Error checking environment variables',
        details: error
      });
    }

    // Test 2: Supabase Client Initialization
    try {
      if (supabase) {
        testResults.push({
          test: 'Supabase Client',
          status: 'success',
          message: 'Supabase client initialized successfully'
        });
      } else {
        testResults.push({
          test: 'Supabase Client',
          status: 'error',
          message: 'Supabase client failed to initialize'
        });
      }
    } catch (error) {
      testResults.push({
        test: 'Supabase Client',
        status: 'error',
        message: 'Error initializing Supabase client',
        details: error
      });
    }

    // Test 3: Network Connectivity
    try {
      const response = await fetch('https://nvuohqfsgeulivaihxeh.supabase.co', {
        method: 'HEAD',
        mode: 'no-cors'
      });
      testResults.push({
        test: 'Network Connectivity',
        status: 'success',
        message: 'Supabase server is reachable'
      });
    } catch (error) {
      testResults.push({
        test: 'Network Connectivity',
        status: 'error',
        message: 'Cannot reach Supabase server',
        details: error
      });
    }

    // Test 4: Authentication Service
    try {
      const { data, error } = await supabase.auth.getSession();
      if (error) {
        testResults.push({
          test: 'Authentication Service',
          status: 'warning',
          message: 'Authentication service accessible but no active session',
          details: error.message
        });
      } else {
        testResults.push({
          test: 'Authentication Service',
          status: 'success',
          message: 'Authentication service is working',
          details: data.session ? 'Active session found' : 'No active session'
        });
      }
    } catch (error) {
      testResults.push({
        test: 'Authentication Service',
        status: 'error',
        message: 'Authentication service error',
        details: error
      });
    }

    // Test 5: Database Connection
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('count')
        .limit(1);
      
      if (error) {
        testResults.push({
          test: 'Database Connection',
          status: 'error',
          message: 'Database connection failed',
          details: error.message
        });
      } else {
        testResults.push({
          test: 'Database Connection',
          status: 'success',
          message: 'Database connection successful'
        });
      }
    } catch (error) {
      testResults.push({
        test: 'Database Connection',
        status: 'error',
        message: 'Database connection error',
        details: error
      });
    }

    // Test 6: Test Login with Sample Credentials
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: 'test@example.com',
        password: 'testpassword'
      });
      
      if (error && error.message.includes('Invalid login credentials')) {
        testResults.push({
          test: 'Login Service',
          status: 'success',
          message: 'Login service is working (test credentials rejected as expected)'
        });
      } else if (error) {
        testResults.push({
          test: 'Login Service',
          status: 'warning',
          message: 'Login service error',
          details: error.message
        });
      } else {
        testResults.push({
          test: 'Login Service',
          status: 'warning',
          message: 'Unexpected: test credentials were accepted'
        });
      }
    } catch (error) {
      testResults.push({
        test: 'Login Service',
        status: 'error',
        message: 'Login service error',
        details: error
      });
    }

    setResults(testResults);
    setIsRunning(false);
  };

  const getStatusIcon = (status: 'success' | 'error' | 'warning') => {
    switch (status) {
      case 'success':
        return <CheckCircle className="h-5 w-5 text-green-500" />;
      case 'error':
        return <AlertCircle className="h-5 w-5 text-red-500" />;
      case 'warning':
        return <AlertCircle className="h-5 w-5 text-yellow-500" />;
    }
  };

  const getStatusColor = (status: 'success' | 'error' | 'warning') => {
    switch (status) {
      case 'success':
        return 'bg-green-50 border-green-200';
      case 'error':
        return 'bg-red-50 border-red-200';
      case 'warning':
        return 'bg-yellow-50 border-yellow-200';
    }
  };

  return (
    <div className="bg-white rounded-lg shadow-lg p-6 max-w-4xl mx-auto">
      <div className="flex items-center gap-3 mb-6">
        <RefreshCw className="h-6 w-6 text-blue-600" />
        <h2 className="text-xl font-semibold text-gray-900">Supabase Connection Diagnostic</h2>
      </div>

      <div className="mb-6">
        <p className="text-gray-600 mb-4">
          This diagnostic tool will test your Supabase connection and identify any issues preventing login.
        </p>
        <button
          onClick={runDiagnostic}
          disabled={isRunning}
          className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isRunning ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Running Diagnostic...
            </>
          ) : (
            <>
              <RefreshCw className="h-4 w-4" />
              Run Diagnostic
            </>
          )}
        </button>
      </div>

      {results.length > 0 && (
        <div className="space-y-4">
          <h3 className="text-lg font-semibold text-gray-900">Diagnostic Results</h3>
          {results.map((result, index) => (
            <div
              key={index}
              className={`p-4 rounded-lg border ${getStatusColor(result.status)}`}
            >
              <div className="flex items-start gap-3">
                {getStatusIcon(result.status)}
                <div className="flex-1">
                  <h4 className="font-medium text-gray-900">{result.test}</h4>
                  <p className="text-sm text-gray-600 mt-1">{result.message}</p>
                  {result.details && (
                    <details className="mt-2">
                      <summary className="text-xs text-gray-500 cursor-pointer hover:text-gray-700">
                        Show Details
                      </summary>
                      <pre className="text-xs text-gray-500 mt-2 bg-gray-100 p-2 rounded overflow-x-auto">
                        {JSON.stringify(result.details, null, 2)}
                      </pre>
                    </details>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {results.length > 0 && (
        <div className="mt-6 p-4 bg-gray-50 rounded-lg">
          <h4 className="font-medium text-gray-900 mb-2">Next Steps</h4>
          <ul className="text-sm text-gray-600 space-y-1">
            <li>• If any tests failed, check the troubleshooting guide</li>
            <li>• Verify your .env file contains the correct Supabase credentials</li>
            <li>• Ensure your internet connection is stable</li>
            <li>• Check if your Supabase project is active and not paused</li>
            <li>• Verify your user account exists and is confirmed</li>
          </ul>
        </div>
      )}
    </div>
  );
}
