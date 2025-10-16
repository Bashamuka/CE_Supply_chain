import React, { useState } from 'react';
import { supabase } from '../lib/supabase';
import { useUserStore } from '../store/userStore';
import { AlertCircle, Loader2, Mail, Lock, Eye, EyeOff } from 'lucide-react';

export function LoginForm() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);
  const setUser = useUserStore((state) => state.setUser);

  const validateForm = () => {
    if (!email.trim()) {
      setError('Please enter your email address.');
      return false;
    }
    if (!password.trim()) {
      setError('Please enter your password.');
      return false;
    }
    if (!email.trim().includes('@')) {
      setError('Please enter a valid email address.');
      return false;
    }
    return true;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!validateForm()) {
      return;
    }

    setLoading(true);

    try {
      const trimmedEmail = email.trim().toLowerCase();
      const trimmedPassword = password.trim();

      const { data, error: authError } = await supabase.auth.signInWithPassword({
        email: trimmedEmail,
        password: trimmedPassword,
      });

      if (authError) {
        console.error('Authentication error:', {
          code: authError.status,
          message: authError.message,
          details: authError
        });

        switch (authError.message) {
          case 'Invalid login credentials':
          case 'Invalid email or password':
            throw new Error('Incorrect email or password. Please check your credentials.');
          case 'Email not confirmed':
            throw new Error('Please confirm your email before logging in.');
          case 'Rate limiter error':
            throw new Error('Too many login attempts. Please try again in a few minutes.');
          default:
            throw new Error('An error occurred during login. Please try again.');
        }
      }

      if (!data?.user) {
        console.error('Error: No user returned after successful authentication');
        throw new Error('Unable to retrieve user information.');
      }

      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', data.user.id)
        .single();

      if (profileError) {
        console.error('Error retrieving profile:', {
          code: profileError.code,
          message: profileError.message,
          details: profileError
        });
        throw new Error('Error retrieving user profile.');
      }

      if (!profile) {
        console.error('Error: User profile not found for ID:', data.user.id);
        throw new Error('User profile not found.');
      }

      setUser({
        id: data.user.id,
        email: data.user.email!,
        role: profile.role || 'employee',
      });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'An unexpected error occurred.';
      console.error('Login error:', {
        error,
        email: email.trim().toLowerCase(),
        timestamp: new Date().toISOString()
      });
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  const handleInputChange = () => {
    if (error) {
      setError(null);
    }
  };

  return (
    <div className="w-full h-full flex flex-col justify-center">
      {/* CE-Parts Logo */}
      <div className="mb-8">
        <div className="flex items-center gap-4">
          <div className="w-10 h-10 bg-[#FFCD11] rounded-lg flex items-center justify-center">
            <div className="w-6 h-6 bg-black rounded-sm"></div>
          </div>
          <span className="text-gray-900 text-2xl font-bold">CE-Parts Supply Chain Hub</span>
        </div>
      </div>

      {/* Welcome Text */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Welcome back</h1>
        <p className="text-gray-600">Sign in to your account</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-4">
        {error && (
          <div className="bg-red-50 border-l-4 border-red-500 p-3 rounded-xl animate-fadeIn">
            <div className="flex items-center">
              <AlertCircle className="h-5 w-5 sm:h-6 sm:w-6 text-red-500 flex-shrink-0" />
              <p className="ml-3 text-base text-red-700">{error}</p>
            </div>
          </div>
        )}


        <div className="space-y-2">
          <label htmlFor="email" className="block text-base font-medium text-gray-900">
            Email address
          </label>
          <div className="relative">
            <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 sm:h-6 sm:w-6 text-gray-400" />
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                handleInputChange();
              }}
              className="w-full pl-10 sm:pl-12 pr-4 py-3 rounded-lg border border-gray-300 
                       focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11] 
                       transition-all duration-200 bg-white text-gray-900 shadow-sm
                       placeholder:text-gray-400 text-base"
              placeholder="you@example.com"
              disabled={loading}
              autoComplete="email"
              aria-label="Email address"
            />
          </div>
        </div>

        <div className="space-y-2">
          <label htmlFor="password" className="block text-base font-medium text-gray-900">
            Password
          </label>
          <div className="relative">
            <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 sm:h-6 sm:w-6 text-gray-400" />
            <input
              id="password"
              type={showPassword ? "text" : "password"}
              required
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                handleInputChange();
              }}
              className="w-full pl-10 sm:pl-12 pr-12 sm:pr-14 py-3 rounded-lg border border-gray-300 
                       focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11] 
                       transition-all duration-200 bg-white text-gray-900 shadow-sm
                       placeholder:text-gray-400 text-base"
              placeholder="••••••••"
              disabled={loading}
              autoComplete="current-password"
              aria-label="Password"
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute right-3 top-1/2 transform -translate-y-1/2
                       text-gray-400 hover:text-gray-300 transition-colors
                       focus:outline-none"
              aria-label={showPassword ? "Hide password" : "Show password"}
            >
              {showPassword ? (
                <EyeOff className="h-5 w-5 sm:h-6 sm:w-6" />
              ) : (
                <Eye className="h-5 w-5 sm:h-6 sm:w-6" />
              )}
            </button>
          </div>
        </div>

        {/* Sign In Button */}
        <button
          type="submit"
          disabled={loading}
          className="w-full bg-[#FFCD11] hover:bg-[#FFE066] text-black 
                   py-3 px-4 rounded-lg font-bold text-base
                   focus:outline-none focus:ring-2 focus:ring-[#FFCD11] focus:ring-offset-2 focus:ring-offset-gray-900
                   disabled:opacity-50 disabled:cursor-not-allowed 
                   transition-all duration-300
                   flex items-center justify-center space-x-2"
          aria-label={loading ? "Logging in" : "Sign in"}
        >
          {loading ? (
            <>
              <Loader2 className="h-5 w-5 animate-spin" />
              <span>Signing in...</span>
            </>
          ) : (
            <span>Sign In</span>
          )}
        </button>
        </form>

        {/* Powered by Congo Equipment */}
        <div className="mt-6 text-center">
          <p className="text-gray-500 text-sm">Powered by Congo Equipment®</p>
        </div>
      </div>
    );
  }