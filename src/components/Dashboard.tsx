import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Package2, Database, GitBranch, ArrowRight, Clock, Warehouse, RefreshCw, LogOut, BookOpen, Package, FolderKanban, FileSpreadsheet, BarChart3, Shield, Lock, CheckCircle } from 'lucide-react';
import { useUserStore } from '../store/userStore';
import { useAdminStore } from '../store/adminStore';
import type { ModuleName } from '../types';

interface DashboardItem {
  title: string;
  description: string;
  icon: any;
  path: string;
  color: string;
  hoverColor: string;
  iconBg: string;
  iconColor: string;
  moduleName?: ModuleName;
}

export function Dashboard() {
  const { user, logout } = useUserStore((state) => ({ user: state.user, logout: state.logout }));
  const { checkModuleAccess } = useAdminStore();
  const navigate = useNavigate();
  const [moduleAccessMap, setModuleAccessMap] = useState<Record<string, boolean>>({});
  const [loadingAccess, setLoadingAccess] = useState(true);

  const dashboardItems: DashboardItem[] = [
    ...(user?.role === 'admin' ? [{
      title: 'Administration',
      description: 'Manage users, roles, and module permissions',
      icon: Shield,
      path: '/admin',
      color: 'from-red-500 to-red-600',
      hoverColor: 'hover:from-red-600 hover:to-red-700',
      iconBg: 'bg-red-100',
      iconColor: 'text-red-600'
    }] : []),
    {
      title: 'Global Dashboard',
      description: 'Overview of all system metrics and performance indicators',
      icon: BarChart3,
      path: '/global-dashboard',
      color: 'from-cyan-500 to-cyan-600',
      hoverColor: 'hover:from-cyan-600 hover:to-cyan-700',
      iconBg: 'bg-cyan-100',
      iconColor: 'text-cyan-600',
      moduleName: 'global_dashboard'
    },
    {
      title: 'ETA Tracking',
      description: 'Track order statuses, delivery dates, and part availability',
      icon: Clock,
      path: '/eta-tracking',
      color: 'from-blue-500 to-blue-600',
      hoverColor: 'hover:from-blue-600 hover:to-blue-700',
      iconBg: 'bg-blue-100',
      iconColor: 'text-blue-600',
      moduleName: 'eta_tracking'
    },
    {
      title: 'Availabilities CE & CAT',
      description: 'Check stock levels across all branches and locations',
      icon: Warehouse,
      path: '/availabilities',
      color: 'from-green-500 to-green-600',
      hoverColor: 'hover:from-green-600 hover:to-green-700',
      iconBg: 'bg-green-100',
      iconColor: 'text-green-600',
      moduleName: 'stock_availability'
    },
    {
      title: 'Parts Equivalence',
      description: 'Find equivalent parts and cross-references',
      icon: GitBranch,
      path: '/parts-equivalence',
      color: 'from-teal-500 to-teal-600',
      hoverColor: 'hover:from-teal-600 hover:to-teal-700',
      iconBg: 'bg-teal-100',
      iconColor: 'text-teal-600',
      moduleName: 'parts_equivalence'
    },
    {
      title: 'Orders Movement',
      description: 'Track order entries and deliveries with real-time updates',
      icon: Package,
      path: '/orders',
      color: 'from-orange-500 to-orange-600',
      hoverColor: 'hover:from-orange-600 hover:to-orange-700',
      iconBg: 'bg-orange-100',
      iconColor: 'text-orange-600',
      moduleName: 'orders'
    },
    {
      title: 'Project Management',
      description: 'Create and track machine projects with parts availability analysis',
      icon: FolderKanban,
      path: '/projects',
      color: 'from-purple-500 to-purple-600',
      hoverColor: 'hover:from-purple-600 hover:to-purple-700',
      iconBg: 'bg-purple-100',
      iconColor: 'text-purple-600',
      moduleName: 'projects'
    },
    {
      title: 'Dealer Forward Planning',
      description: 'Upload and manage parts forecasts for regional availability',
      icon: FileSpreadsheet,
      path: '/dealer-forward-planning',
      color: 'from-indigo-500 to-indigo-600',
      hoverColor: 'hover:from-indigo-600 hover:to-indigo-700',
      iconBg: 'bg-indigo-100',
      iconColor: 'text-indigo-600',
      moduleName: 'dealer_forward_planning'
    },
    {
      title: 'OTC - Order Tracking & Control',
      description: 'Comprehensive order management and tracking with detailed analytics',
      icon: Package,
      path: '/otc',
      color: 'from-pink-500 to-pink-600',
      hoverColor: 'hover:from-pink-600 hover:to-pink-700',
      iconBg: 'bg-pink-100',
      iconColor: 'text-pink-600',
      moduleName: 'otc'
    },
    {
      title: 'User Guide',
      description: 'Complete guide and documentation for using the application',
      icon: BookOpen,
      path: '/user-guide',
      color: 'from-gray-500 to-gray-600',
      hoverColor: 'hover:from-gray-600 hover:to-gray-700',
      iconBg: 'bg-gray-100',
      iconColor: 'text-gray-600'
    },
  ];

  useEffect(() => {
    const loadModuleAccess = async () => {
      if (!user) {
        setLoadingAccess(false);
        return;
      }

      if (user.role === 'admin') {
        const accessMap: Record<string, boolean> = {};
        dashboardItems.forEach(item => {
          if (item.moduleName) {
            accessMap[item.moduleName] = true;
          }
        });
        setModuleAccessMap(accessMap);
        setLoadingAccess(false);
        return;
      }

      const accessMap: Record<string, boolean> = {};
      const promises = dashboardItems
        .filter(item => item.moduleName)
        .map(async (item) => {
          if (item.moduleName) {
            const hasAccess = await checkModuleAccess(user.id, item.moduleName);
            accessMap[item.moduleName] = hasAccess;
          }
        });

      await Promise.all(promises);
      setModuleAccessMap(accessMap);
      setLoadingAccess(false);
    };

    loadModuleAccess();
  }, [user]);

  const hasAccess = (moduleName?: ModuleName) => {
    if (!moduleName) return true;
    if (user?.role === 'admin') return true;
    return moduleAccessMap[moduleName] === true;
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      {/* Header */}
      <div className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
          <div className="flex justify-end mb-4">
            <button
              onClick={logout}
              className="flex items-center gap-2 px-4 py-2 text-sm text-gray-600 hover:text-[#1A1A1A] hover:bg-gray-100 rounded-lg transition-colors duration-200"
              title="Sign out"
            >
              <LogOut className="h-4 w-4" />
              <span>Sign out</span>
            </button>
          </div>
          <div className="text-center">
            <div className="flex justify-center mb-6">
              <div className="relative">
                <div className="bg-gradient-to-r from-[#1A1A1A] to-[#333333] p-4 rounded-2xl">
                  <Package2 className="h-12 w-12 text-[#FFCD11]" />
                </div>
                <div className="absolute -top-1 -right-1">
                  <div className="bg-[#FFCD11] rounded-full p-1">
                    <RefreshCw className="h-4 w-4 text-[#1A1A1A]" />
                  </div>
                </div>
              </div>
            </div>
            <h1 className="text-3xl sm:text-4xl font-bold text-[#1A1A1A] mb-4">
              Welcome to CE-Parts Supply Chain Hub
            </h1>
            <p className="text-lg text-gray-600 mb-2">
              Hi <span className="font-semibold text-[#1A1A1A]">{user?.email}</span>, how can I help you today?
            </p>
            <p className="text-sm text-gray-500">
              Powered by Congo Equipment®
            </p>
          </div>
        </div>
      </div>

      {/* Dashboard Cards */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {dashboardItems.map((item, index) => {
            const IconComponent = item.icon;
            const itemHasAccess = hasAccess(item.moduleName);

            return (
              <Link
                key={index}
                to={item.path}
                className={`group relative bg-white rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-300 transform hover:-translate-y-2 overflow-hidden ${
                  !itemHasAccess ? 'opacity-75' : ''
                }`}
              >
                {/* Access Badge */}
                <div className="absolute top-4 right-4 z-10">
                  {item.moduleName && (
                    <>
                      {itemHasAccess ? (
                        <div className="bg-green-100 rounded-full p-2 shadow-md" title="Access granted">
                          <CheckCircle className="w-5 h-5 text-green-600" />
                        </div>
                      ) : (
                        <div className="bg-red-100 rounded-full p-2 shadow-md" title="Access denied">
                          <Lock className="w-5 h-5 text-red-600" />
                        </div>
                      )}
                    </>
                  )}
                </div>

                {/* Background Gradient */}
                <div className={`absolute inset-0 bg-gradient-to-br ${item.color} opacity-0 group-hover:opacity-5 transition-opacity duration-300`} />

                {/* Content */}
                <div className="relative p-8">
                  {/* Icon */}
                  <div className={`${item.iconBg} rounded-2xl p-4 w-fit mb-6 group-hover:scale-110 transition-transform duration-300`}>
                    <IconComponent className={`h-8 w-8 ${item.iconColor}`} />
                  </div>

                  {/* Title */}
                  <h3 className="text-xl font-bold text-[#1A1A1A] mb-3 group-hover:text-gray-800 transition-colors">
                    {item.title}
                  </h3>

                  {/* Description */}
                  <p className="text-gray-600 text-sm leading-relaxed mb-6">
                    {item.description}
                  </p>

                  {/* Action */}
                  <div className="flex items-center text-sm font-medium text-gray-500 group-hover:text-[#1A1A1A] transition-colors">
                    <span>{itemHasAccess ? 'Get started' : 'Limited access'}</span>
                    <ArrowRight className="h-4 w-4 ml-2 group-hover:translate-x-1 transition-transform duration-300" />
                  </div>
                </div>

                {/* Hover Border */}
                <div className={`absolute inset-0 rounded-2xl border-2 border-transparent bg-gradient-to-br ${item.color} opacity-0 group-hover:opacity-100 transition-opacity duration-300`}
                     style={{ mask: 'linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0)', maskComposite: 'xor' }} />
              </Link>
            );
          })}
        </div>

        {/* Stats Section */}
        <div className="mt-16 bg-white rounded-2xl shadow-lg p-8">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold text-[#1A1A1A] mb-2">System Overview</h2>
            <p className="text-gray-600">Quick access to your most important data</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div className="text-center">
              <div className="bg-blue-100 rounded-full p-4 w-fit mx-auto mb-4">
                <Database className="h-8 w-8 text-blue-600" />
              </div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-2">ETA Database</h3>
              <p className="text-gray-600 text-sm">Track orders and delivery schedules</p>
            </div>

            <div className="text-center">
              <div className="bg-green-100 rounded-full p-4 w-fit mx-auto mb-4">
                <Warehouse className="h-8 w-8 text-green-600" />
              </div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-2">Stock Management</h3>
              <p className="text-gray-600 text-sm">Monitor inventory across locations</p>
            </div>

            <div className="text-center">
              <div className="bg-teal-100 rounded-full p-4 w-fit mx-auto mb-4">
                <GitBranch className="h-8 w-8 text-teal-600" />
              </div>
              <h3 className="text-lg font-semibold text-[#1A1A1A] mb-2">Part Equivalence</h3>
              <p className="text-gray-600 text-sm">Find alternative and compatible parts</p>
            </div>
          </div>
        </div>
      </div>

    </div>
  );
}