import React from 'react';
import { useEffect, useState } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Loader2 } from 'lucide-react';
import { Dashboard } from './components/Dashboard';
import { GlobalDashboard } from './components/GlobalDashboard';
import { EtaTrackingInterface } from './components/EtaTrackingInterface';
import { StockAvailabilityInterface } from './components/StockAvailabilityInterface';
import { PartsEquivalenceInterface } from './components/PartsEquivalenceInterface';
import { OrdersInterface } from './components/OrdersInterface';
import { ProjectsInterface } from './components/ProjectsInterface';
import { ProjectDetailsInterface } from './components/ProjectDetailsInterface';
import { ProjectAnalyticsView } from './components/ProjectAnalyticsView';
import { ProjectComparativeDashboard } from './components/ProjectComparativeDashboard';
import { DealerForwardPlanningInterface } from './components/DealerForwardPlanningInterface';
import AdminInterface from './components/AdminInterface';
import ProtectedModule from './components/ProtectedModule';
import { UserGuide } from './components/UserGuide';
import { LoginForm } from './components/LoginForm';
import RotatingMessages from './components/RotatingMessages';
import { BackgroundGallery } from './components/BackgroundGallery';
import { useUserStore } from './store/userStore';
import { supabase } from './lib/supabase';

function App() {
  const { user, logout } = useUserStore((state) => ({ user: state.user, logout: state.logout }));
  const [loadingSession, setLoadingSession] = useState(true);

  useEffect(() => {
    // Check initial session
    const checkSession = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session) {
          logout();
        }
      } catch (error) {
        console.error('Error checking session:', error);
        logout();
      } finally {
        setLoadingSession(false);
      }
    };

    checkSession();

    // Listen for auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === 'SIGNED_OUT' || !session) {
        logout();
      }
      setLoadingSession(false);
    });

    return () => {
      subscription.unsubscribe();
    };
  }, [logout]);

  // Show loading spinner while checking session
  if (loadingSession) {
    return (
      <div className="min-h-screen bg-[#1A1A1A] flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-white" />
      </div>
    );
  }

  return (
    <Router>
      {!user ? (
        <Routes>
          <Route path="*" element={
            <div className="min-h-screen relative">
              {/* Blurred background layer */}
              <div
                className="absolute inset-0 bg-cover bg-center bg-no-repeat filter blur-sm"
                style={{
                  backgroundImage: "url('./Generated Image September 17, 2025 - 4_54PM.png')"
                }}
              >
                {/* Semi-transparent overlay */}
                <div className="absolute inset-0 bg-black opacity-50"></div>
              </div>

              {/* Centered login + rotating messages */}
              <div className="relative z-10 min-h-screen flex items-center justify-center p-4 sm:p-8">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6 w-full max-w-4xl">
                  <div className="bg-white p-4 sm:p-6 rounded-3xl shadow-2xl">
                    <LoginForm />
                  </div>
                  <div className="bg-[#1A1A1A] text-white p-6 sm:p-8 rounded-3xl shadow-2xl flex items-center">
                    <RotatingMessages />
                  </div>
                </div>
              </div>
            </div>
          } />
        </Routes>
      ) : (
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/admin" element={<AdminInterface />} />
          <Route path="/global-dashboard" element={
            <ProtectedModule moduleName="global_dashboard" moduleLabel="Global Dashboard">
              <GlobalDashboard />
            </ProtectedModule>
          } />
          <Route path="/eta-tracking" element={
            <ProtectedModule moduleName="eta_tracking" moduleLabel="ETA Tracking">
              <EtaTrackingInterface onSendMessage={() => {}} loading={false} />
            </ProtectedModule>
          } />
          <Route path="/availabilities" element={
            <ProtectedModule moduleName="stock_availability" moduleLabel="Stock Availability">
              <StockAvailabilityInterface />
            </ProtectedModule>
          } />
          <Route path="/parts-equivalence" element={
            <ProtectedModule moduleName="parts_equivalence" moduleLabel="Parts Equivalence">
              <PartsEquivalenceInterface />
            </ProtectedModule>
          } />
          <Route path="/orders" element={
            <ProtectedModule moduleName="orders" moduleLabel="Orders Management">
              <OrdersInterface />
            </ProtectedModule>
          } />
          <Route path="/projects" element={
            <ProtectedModule moduleName="projects" moduleLabel="Projects Management">
              <ProjectsInterface />
            </ProtectedModule>
          } />
          <Route path="/projects/:projectId" element={
            <ProtectedModule moduleName="projects" moduleLabel="Projects Management">
              <ProjectDetailsInterface />
            </ProtectedModule>
          } />
          <Route path="/projects/:projectId/analytics" element={
            <ProtectedModule moduleName="projects" moduleLabel="Projects Management">
              <ProjectAnalyticsView />
            </ProtectedModule>
          } />
          <Route path="/projects/:projectId/dashboard" element={
            <ProtectedModule moduleName="projects" moduleLabel="Projects Management">
              <ProjectComparativeDashboard />
            </ProtectedModule>
          } />
          <Route path="/dealer-forward-planning" element={
            <ProtectedModule moduleName="dealer_forward_planning" moduleLabel="Dealer Forward Planning">
              <DealerForwardPlanningInterface />
            </ProtectedModule>
          } />
          <Route path="/user-guide" element={<UserGuide />} />
        </Routes>
      )}
    </Router>
  );
}

export default App;