import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../lib/supabase';
import { useUserStore } from '../store/userStore';
import { AlertCircle, Package2, Loader2, Mail, Lock, Eye, EyeOff, Radar, ArrowRight } from 'lucide-react';

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
    <div className="w-full">
      <div className="text-center mb-3">
        <div className="relative inline-flex items-center justify-center w-16 h-16 sm:w-20 sm:h-20 mb-4 group">
          <div className="absolute inset-0 bg-gradient-to-r from-[#1A1A1A] to-[#333333] rounded-2xl transform rotate-3 transition-transform group-hover:rotate-6"></div>
          <div className="absolute inset-0 bg-gradient-to-r from-[#1A1A1A] to-[#333333] rounded-2xl">
            <div className="absolute inset-0 bg-gradient-to-r from-[#FFCD11] to-[#FFE066] opacity-0 group-hover:opacity-20 transition-opacity"></div>
          </div>
          <div className="relative transform transition-transform group-hover:scale-110">
            <div className="relative w-8 h-8 sm:w-10 sm:h-10">
              <div className="absolute inset-0 flex items-center justify-center">
                <Package2 className="h-6 w-6 sm:h-8 sm:w-8 text-[#FFCD11]" />
              </div>
              <div className="absolute inset-0 flex items-center justify-center animate-ping opacity-75">
                <Radar className="h-8 w-8 sm:h-10 sm:w-10 text-[#FFCD11] opacity-20" />
              </div>
              <div className="absolute -right-1 -bottom-1">
                <ArrowRight className="h-3 w-3 sm:h-4 sm:w-4 text-[#FFCD11]" />
              </div>
            </div>
          </div>
        </div>
        <h1 className="text-3xl sm:text-4xl font-bold text-[#1A1A1A] mb-2 tracking-tight">
          CE-Parts Supply Chain Hub
        </h1>
        <p className="text-[#666666] text-sm">Powered by Congo Equipment®</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-3 py-4 px-6 rounded-2xl">
        {error && (
          <div className="bg-red-50 border-l-4 border-red-500 p-3 rounded-xl animate-fadeIn">
            <div className="flex items-center">
              <AlertCircle className="h-5 w-5 sm:h-6 sm:w-6 text-red-500 flex-shrink-0" />
              <p className="ml-3 text-base text-red-700">{error}</p>
            </div>
          </div>
        )}

        <div className="space-y-2">
          <label htmlFor="email" className="block text-base font-medium text-[#1A1A1A]">
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
              className="w-full pl-10 sm:pl-12 pr-4 py-3 rounded-xl border border-gray-300 
                       focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11] 
                       transition-all duration-200 bg-white shadow-sm
                       placeholder:text-gray-400 text-base"
              placeholder="name@congo-equipment.com"
              disabled={loading}
              autoComplete="email"
              aria-label="Email address"
            />
          </div>
        </div>

        <div className="space-y-2">
          <label htmlFor="password" className="block text-base font-medium text-[#1A1A1A]">
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
              className="w-full pl-10 sm:pl-12 pr-12 sm:pr-14 py-3 rounded-xl border border-gray-300 
                       focus:ring-2 focus:ring-[#FFCD11] focus:border-[#FFCD11] 
                       transition-all duration-200 bg-white shadow-sm
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
                       text-gray-400 hover:text-gray-600 transition-colors
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

        <button
          type="submit"
          disabled={loading}
          className="w-full bg-gradient-to-r from-[#1A1A1A] to-[#333333] text-white 
                   py-3 px-4 rounded-xl font-medium text-base
                   hover:from-[#333333] hover:to-[#1A1A1A] 
                   focus:outline-none focus:ring-2 focus:ring-[#FFCD11] focus:ring-offset-2
                   disabled:opacity-50 disabled:cursor-not-allowed 
                   transition-all duration-300
                   flex items-center justify-center space-x-2
                   transform hover:-translate-y-0.5 active:translate-y-0
                   shadow-lg hover:shadow-xl"
          aria-label={loading ? "Logging in" : "Log in"}
        >
          {loading ? (
            <>
              <Loader2 className="h-5 w-5 sm:h-6 sm:w-6 animate-spin" />
              <span>Logging in...</span>
            </>
          ) : (
            <span>Log in</span>
          )}
        </button>
      </form>

      <div className="mt-6 text-center">
        <p className="text-sm text-gray-600 mb-2">
          Besoin de créer un compte ?
        </p>
        <Link
          to="/register"
          className="text-sm font-medium text-[#1A1A1A] hover:text-[#FFCD11] transition-colors"
        >
          Créer un nouveau compte →
        </Link>
      </div>

      <p className="mt-4 text-center text-xs sm:text-sm text-gray-500">
        By logging in, you agree to our{' '}
        <a href="#" className="text-[#1A1A1A] hover:text-[#FFCD11] transition-colors">
          terms of use
        </a>
      </p>
    </div>
  );
}