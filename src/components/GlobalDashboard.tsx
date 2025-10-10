import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  Package2,
  TrendingUp,
  AlertCircle,
  CheckCircle,
  Clock,
  Warehouse,
  FolderKanban,
  FileSpreadsheet,
  ArrowRight,
  RefreshCw,
  LogOut,
  Loader2,
  Package,
  ShoppingCart,
  Database
} from 'lucide-react';
import { useUserStore } from '../store/userStore';
import { supabase } from '../lib/supabase';

interface GlobalStats {
  etaTracking: {
    totalParts: number;
    pendingOrders: number;
    deliveredParts: number;
    delayedEtas: number;
  };
  stockAvailability: {
    totalPartNumbers: number;
    totalQuantity: number;
    lowStock: number;
    outOfStock: number;
  };
  orders: {
    totalOrders: number;
    activeConstructors: number;
    totalOrdered: number;
    totalDelivered: number;
    deliveryRate: number;
  };
  projects: {
    totalProjects: number;
    activeProjects: number;
    totalMachines: number;
    overallProgress: number;
  };
  dealerPlanning: {
    totalForecast: number;
    uniqueParts: number;
  };
}

export function GlobalDashboard() {
  const { user, logout } = useUserStore((state) => ({ user: state.user, logout: state.logout }));
  const [stats, setStats] = useState<GlobalStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadGlobalStats();
  }, []);

  const loadGlobalStats = async () => {
    try {
      setLoading(true);
      setError(null);

      const [
        etaCount,
        etaData,
        stockData,
        ordersData,
        projectsCount,
        projectMachinesCount,
        dealerPlanningData
      ] = await Promise.all([
        supabase.from('parts').select('*', { count: 'exact', head: true }),
        supabase.from('parts').select('status, eta'),
        supabase.from('stock_dispo').select('qté_gdc, qté_jdc, qté_cat_network, qté_succ_10, qté_succ_20, qté_succ_11, qté_succ_12, qté_succ_13, qté_succ_14, qté_succ_19, qté_succ_21, qté_succ_22, qté_succ_24, qté_succ_30, qté_succ_40, qté_succ_50, qté_succ_60, qté_succ_70, qté_succ_80, qté_succ_90'),
        supabase.from('orders').select('constructeur, qte_commandee, qte_livree'),
        supabase.from('projects').select('status', { count: 'exact', head: true }),
        supabase.from('project_machines').select('*', { count: 'exact', head: true }),
        supabase.from('dealer_forward_planning').select('part_number, forecast_quantity')
      ]);

      if (etaCount.error || etaData.error || stockData.error || ordersData.error || projectsCount.error || projectMachinesCount.error || dealerPlanningData.error) {
        throw new Error('Failed to fetch data from database');
      }

      const today = new Date();
      today.setHours(0, 0, 0, 0);

      const pendingParts = etaData.data?.filter(p => p.status !== 'Delivered' && p.status !== 'Closed') || [];
      const deliveredParts = etaData.data?.filter(p => p.status === 'Delivered' || p.status === 'Closed') || [];

      const delayedEtas = pendingParts.filter(part => {
        if (!part.eta) return false;
        const etaParts = part.eta.split('/');
        if (etaParts.length !== 3) return false;
        const etaDate = new Date(`${etaParts[2]}-${etaParts[1]}-${etaParts[0]}`);
        return etaDate < today;
      }).length;

      let totalStockQuantity = 0;
      let lowStockCount = 0;
      let outOfStockCount = 0;

      stockData.data?.forEach(stock => {
        const partTotal = (stock.qté_gdc || 0) + (stock.qté_jdc || 0) + (stock.qté_cat_network || 0) +
          (stock.qté_succ_10 || 0) + (stock.qté_succ_20 || 0) + (stock.qté_succ_11 || 0) +
          (stock.qté_succ_12 || 0) + (stock.qté_succ_13 || 0) + (stock.qté_succ_14 || 0) +
          (stock.qté_succ_19 || 0) + (stock.qté_succ_21 || 0) + (stock.qté_succ_22 || 0) +
          (stock.qté_succ_24 || 0) + (stock.qté_succ_30 || 0) + (stock.qté_succ_40 || 0) +
          (stock.qté_succ_50 || 0) + (stock.qté_succ_60 || 0) + (stock.qté_succ_70 || 0) +
          (stock.qté_succ_80 || 0) + (stock.qté_succ_90 || 0);

        totalStockQuantity += partTotal;

        if (partTotal === 0) outOfStockCount++;
        else if (partTotal <= 5) lowStockCount++;
      });

      const uniqueConstructors = new Set(ordersData.data?.map(o => o.constructeur)).size;
      const totalOrdered = ordersData.data?.reduce((sum, o) => sum + (o.qte_commandee || 0), 0) || 0;
      const totalDelivered = ordersData.data?.reduce((sum, o) => sum + (o.qte_livree || 0), 0) || 0;
      const deliveryRate = totalOrdered > 0 ? (totalDelivered / totalOrdered) * 100 : 0;

      const totalForecast = dealerPlanningData.data?.reduce((sum, d) => sum + (d.forecast_quantity || 0), 0) || 0;
      const uniqueParts = new Set(dealerPlanningData.data?.map(d => d.part_number)).size;

      const allProjects = await supabase.from('projects').select('status');
      const activeProjects = allProjects.data?.filter(p => p.status === 'active').length || 0;

      setStats({
        etaTracking: {
          totalParts: etaCount.count || 0,
          pendingOrders: pendingParts.length,
          deliveredParts: deliveredParts.length,
          delayedEtas: delayedEtas
        },
        stockAvailability: {
          totalPartNumbers: stockData.data?.length || 0,
          totalQuantity: totalStockQuantity,
          lowStock: lowStockCount,
          outOfStock: outOfStockCount
        },
        orders: {
          totalOrders: ordersData.data?.length || 0,
          activeConstructors: uniqueConstructors,
          totalOrdered: totalOrdered,
          totalDelivered: totalDelivered,
          deliveryRate: deliveryRate
        },
        projects: {
          totalProjects: projectsCount.count || 0,
          activeProjects: activeProjects,
          totalMachines: projectMachinesCount.count || 0,
          overallProgress: 0
        },
        dealerPlanning: {
          totalForecast: totalForecast,
          uniqueParts: uniqueParts
        }
      });
    } catch (err) {
      console.error('Error loading global stats:', err);
      setError('Failed to load dashboard statistics');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="h-12 w-12 animate-spin text-blue-600 mx-auto mb-4" />
          <p className="text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="text-center">
          <AlertCircle className="h-12 w-12 text-red-600 mx-auto mb-4" />
          <p className="text-red-600 mb-4">{error}</p>
          <button
            onClick={loadGlobalStats}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      <div className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4">
              <div className="bg-gradient-to-r from-gray-900 to-gray-700 p-3 rounded-xl">
                <Package2 className="h-8 w-8 text-yellow-400" />
              </div>
              <div>
                <h1 className="text-2xl font-bold text-gray-900">Global Dashboard</h1>
                <p className="text-sm text-gray-600">Overview of all system metrics</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={loadGlobalStats}
                className="flex items-center gap-2 px-4 py-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <RefreshCw className="h-4 w-4" />
                Refresh
              </button>
              <Link
                to="/dashboard"
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                View Modules
                <ArrowRight className="h-4 w-4" />
              </Link>
              <button
                onClick={logout}
                className="flex items-center gap-2 px-4 py-2 text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg transition-colors"
              >
                <LogOut className="h-4 w-4" />
                Sign out
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-blue-500">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-blue-100 rounded-lg p-3">
                <Clock className="h-6 w-6 text-blue-600" />
              </div>
              <span className="text-2xl font-bold text-gray-900">{stats?.etaTracking.totalParts}</span>
            </div>
            <h3 className="text-sm font-semibold text-gray-600 mb-2">ETA Tracking</h3>
            <div className="space-y-1 text-xs text-gray-500">
              <div className="flex justify-between">
                <span>Pending:</span>
                <span className="font-medium text-yellow-600">{stats?.etaTracking.pendingOrders}</span>
              </div>
              <div className="flex justify-between">
                <span>Delivered:</span>
                <span className="font-medium text-green-600">{stats?.etaTracking.deliveredParts}</span>
              </div>
              <div className="flex justify-between">
                <span>Delayed:</span>
                <span className="font-medium text-red-600">{stats?.etaTracking.delayedEtas}</span>
              </div>
            </div>
            <Link
              to="/eta-tracking"
              className="mt-4 flex items-center justify-center gap-2 text-sm text-blue-600 hover:text-blue-700 font-medium"
            >
              View Details <ArrowRight className="h-4 w-4" />
            </Link>
          </div>

          <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-green-500">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-green-100 rounded-lg p-3">
                <Warehouse className="h-6 w-6 text-green-600" />
              </div>
              <span className="text-2xl font-bold text-gray-900">{stats?.stockAvailability.totalPartNumbers}</span>
            </div>
            <h3 className="text-sm font-semibold text-gray-600 mb-2">Stock Availability</h3>
            <div className="space-y-1 text-xs text-gray-500">
              <div className="flex justify-between">
                <span>Total Qty:</span>
                <span className="font-medium text-gray-900">{stats?.stockAvailability.totalQuantity.toLocaleString()}</span>
              </div>
              <div className="flex justify-between">
                <span>Low Stock:</span>
                <span className="font-medium text-yellow-600">{stats?.stockAvailability.lowStock}</span>
              </div>
              <div className="flex justify-between">
                <span>Out of Stock:</span>
                <span className="font-medium text-red-600">{stats?.stockAvailability.outOfStock}</span>
              </div>
            </div>
            <Link
              to="/availabilities"
              className="mt-4 flex items-center justify-center gap-2 text-sm text-green-600 hover:text-green-700 font-medium"
            >
              View Details <ArrowRight className="h-4 w-4" />
            </Link>
          </div>

          <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-orange-500">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-orange-100 rounded-lg p-3">
                <Package className="h-6 w-6 text-orange-600" />
              </div>
              <span className="text-2xl font-bold text-gray-900">{stats?.orders.totalOrders}</span>
            </div>
            <h3 className="text-sm font-semibold text-gray-600 mb-2">Orders Movement</h3>
            <div className="space-y-1 text-xs text-gray-500">
              <div className="flex justify-between">
                <span>Constructors:</span>
                <span className="font-medium text-gray-900">{stats?.orders.activeConstructors}</span>
              </div>
              <div className="flex justify-between">
                <span>Ordered:</span>
                <span className="font-medium text-blue-600">{stats?.orders.totalOrdered.toLocaleString()}</span>
              </div>
              <div className="flex justify-between">
                <span>Delivery Rate:</span>
                <span className="font-medium text-green-600">{stats?.orders.deliveryRate.toFixed(1)}%</span>
              </div>
            </div>
            <Link
              to="/orders"
              className="mt-4 flex items-center justify-center gap-2 text-sm text-orange-600 hover:text-orange-700 font-medium"
            >
              View Details <ArrowRight className="h-4 w-4" />
            </Link>
          </div>

          <div className="bg-white rounded-xl shadow-lg p-6 border-l-4 border-purple-500">
            <div className="flex items-center justify-between mb-4">
              <div className="bg-purple-100 rounded-lg p-3">
                <FolderKanban className="h-6 w-6 text-purple-600" />
              </div>
              <span className="text-2xl font-bold text-gray-900">{stats?.projects.totalProjects}</span>
            </div>
            <h3 className="text-sm font-semibold text-gray-600 mb-2">Projects</h3>
            <div className="space-y-1 text-xs text-gray-500">
              <div className="flex justify-between">
                <span>Active:</span>
                <span className="font-medium text-green-600">{stats?.projects.activeProjects}</span>
              </div>
              <div className="flex justify-between">
                <span>Machines:</span>
                <span className="font-medium text-gray-900">{stats?.projects.totalMachines}</span>
              </div>
            </div>
            <Link
              to="/projects"
              className="mt-4 flex items-center justify-center gap-2 text-sm text-purple-600 hover:text-purple-700 font-medium"
            >
              View Details <ArrowRight className="h-4 w-4" />
            </Link>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <div className="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl shadow-lg p-6 text-white">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-white/20 rounded-lg p-3">
                <TrendingUp className="h-8 w-8" />
              </div>
              <div>
                <h3 className="text-xl font-bold">System Performance</h3>
                <p className="text-blue-100 text-sm">Overall health indicators</p>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-white/10 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-2">
                  <CheckCircle className="h-5 w-5 text-green-300" />
                  <span className="text-sm font-medium">Delivery Rate</span>
                </div>
                <p className="text-3xl font-bold">{stats?.orders.deliveryRate.toFixed(1)}%</p>
              </div>
              <div className="bg-white/10 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-2">
                  <AlertCircle className="h-5 w-5 text-yellow-300" />
                  <span className="text-sm font-medium">Delayed ETAs</span>
                </div>
                <p className="text-3xl font-bold">{stats?.etaTracking.delayedEtas}</p>
              </div>
            </div>
          </div>

          <div className="bg-gradient-to-br from-teal-500 to-teal-600 rounded-xl shadow-lg p-6 text-white">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-white/20 rounded-lg p-3">
                <FileSpreadsheet className="h-8 w-8" />
              </div>
              <div>
                <h3 className="text-xl font-bold">Dealer Forward Planning</h3>
                <p className="text-teal-100 text-sm">Forecasting overview</p>
              </div>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="bg-white/10 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-2">
                  <Database className="h-5 w-5 text-teal-200" />
                  <span className="text-sm font-medium">Unique Parts</span>
                </div>
                <p className="text-3xl font-bold">{stats?.dealerPlanning.uniqueParts}</p>
              </div>
              <div className="bg-white/10 rounded-lg p-4">
                <div className="flex items-center gap-2 mb-2">
                  <ShoppingCart className="h-5 w-5 text-teal-200" />
                  <span className="text-sm font-medium">Total Forecast</span>
                </div>
                <p className="text-3xl font-bold">{stats?.dealerPlanning.totalForecast.toLocaleString()}</p>
              </div>
            </div>
            <Link
              to="/dealer-forward-planning"
              className="mt-4 flex items-center justify-center gap-2 px-4 py-2 bg-white/20 hover:bg-white/30 rounded-lg transition-colors"
            >
              Manage Planning <ArrowRight className="h-5 w-5" />
            </Link>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <Link
            to="/eta-tracking"
            className="group bg-white rounded-xl shadow-lg p-6 hover:shadow-xl transition-all duration-300 hover:-translate-y-1"
          >
            <div className="flex items-center justify-between mb-4">
              <div className="bg-blue-100 rounded-lg p-3 group-hover:bg-blue-200 transition-colors">
                <Clock className="h-6 w-6 text-blue-600" />
              </div>
              <ArrowRight className="h-5 w-5 text-gray-400 group-hover:text-blue-600 transition-colors" />
            </div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">ETA Tracking</h3>
            <p className="text-sm text-gray-600">Monitor order statuses and delivery dates</p>
          </Link>

          <Link
            to="/availabilities"
            className="group bg-white rounded-xl shadow-lg p-6 hover:shadow-xl transition-all duration-300 hover:-translate-y-1"
          >
            <div className="flex items-center justify-between mb-4">
              <div className="bg-green-100 rounded-lg p-3 group-hover:bg-green-200 transition-colors">
                <Warehouse className="h-6 w-6 text-green-600" />
              </div>
              <ArrowRight className="h-5 w-5 text-gray-400 group-hover:text-green-600 transition-colors" />
            </div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">Stock Availability</h3>
            <p className="text-sm text-gray-600">Check stock levels across all locations</p>
          </Link>

          <Link
            to="/projects"
            className="group bg-white rounded-xl shadow-lg p-6 hover:shadow-xl transition-all duration-300 hover:-translate-y-1"
          >
            <div className="flex items-center justify-between mb-4">
              <div className="bg-purple-100 rounded-lg p-3 group-hover:bg-purple-200 transition-colors">
                <FolderKanban className="h-6 w-6 text-purple-600" />
              </div>
              <ArrowRight className="h-5 w-5 text-gray-400 group-hover:text-purple-600 transition-colors" />
            </div>
            <h3 className="text-lg font-bold text-gray-900 mb-2">Project Management</h3>
            <p className="text-sm text-gray-600">Track machines and parts availability</p>
          </Link>
        </div>
      </div>
    </div>
  );
}
