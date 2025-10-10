import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ArrowLeft, Download, Loader2, AlertTriangle, CheckCircle, Clock, Package, RefreshCw, TrendingUp, TrendingDown, Calendar } from 'lucide-react';
import { useProjectsStore } from '../store/projectsStore';
import * as XLSX from 'xlsx';

export function ProjectComparativeDashboard() {
  const { projectId } = useParams<{ projectId: string }>();
  const {
    currentProject,
    machines,
    analytics,
    isLoading,
    error,
    fetchProjectById,
    fetchMachines,
    calculateProjectAnalytics,
    refreshAnalyticsViews
  } = useProjectsStore();

  const [isRefreshing, setIsRefreshing] = useState(false);
  const [selectedMetric, setSelectedMetric] = useState<'availability' | 'usage' | 'transit' | 'invoiced' | 'missing'>('availability');
  const [filterStatus, setFilterStatus] = useState<'all' | 'on_time' | 'delayed'>('all');

  useEffect(() => {
    if (projectId) {
      fetchProjectById(projectId);
      fetchMachines(projectId);
      calculateProjectAnalytics(projectId);
    }
  }, [projectId, fetchProjectById, fetchMachines, calculateProjectAnalytics]);

  const handleRefreshData = async () => {
    if (!projectId) return;
    setIsRefreshing(true);
    try {
      await refreshAnalyticsViews();
      await calculateProjectAnalytics(projectId);
    } finally {
      setIsRefreshing(false);
    }
  };

  const calculateDelayInDays = (machine: typeof machines[0]) => {
    if (!machine.end_date) return 0;
    const endDate = new Date(machine.end_date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    endDate.setHours(0, 0, 0, 0);

    if (endDate >= today) return 0;

    const diffTime = today.getTime() - endDate.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays;
  };

  const getMachineStatus = (machine: typeof machines[0]) => {
    const delay = calculateDelayInDays(machine);
    return delay > 0 ? 'delayed' : 'on_time';
  };

  const filteredMachines = machines.filter(machine => {
    if (filterStatus === 'all') return true;
    return getMachineStatus(machine) === filterStatus;
  });

  const exportToExcel = () => {
    if (!analytics || !machines) return;

    const workbook = XLSX.utils.book_new();

    const summaryData = [
      ['Comparative Dashboard - Project', currentProject?.name || ''],
      ['Export date', new Date().toLocaleDateString('en-US')],
      [''],
      ['Overview'],
      ['Total machines', analytics.total_machines],
      ['Machines on time', filteredMachines.filter(m => getMachineStatus(m) === 'on_time').length],
      ['Delayed machines', filteredMachines.filter(m => getMachineStatus(m) === 'delayed').length],
      [''],
      ['Global Statistics'],
      ['Overall Availability', `${analytics.overall_availability.toFixed(2)}%`],
      ['Overall Usage', `${analytics.overall_usage.toFixed(2)}%`],
      ['Overall In Transit', `${analytics.overall_transit.toFixed(2)}%`],
      ['Overall Invoiced', `${analytics.overall_invoiced.toFixed(2)}%`],
      ['Overall Missing', `${analytics.overall_missing.toFixed(2)}%`]
    ];

    const summarySheet = XLSX.utils.aoa_to_sheet(summaryData);
    XLSX.utils.book_append_sheet(workbook, summarySheet, 'Résumé');

    const comparisonData: any[][] = [
      ['Machine', 'End date', 'Status', 'Days delayed', 'Availability %', 'Usage %', 'In Transit %', 'Invoiced %', 'Missing %', 'Total parts']
    ];

    filteredMachines.forEach(machine => {
      const machineAnalytics = analytics.machines.find(m => m.machine_id === machine.id);
      const delay = calculateDelayInDays(machine);
      const status = delay > 0 ? 'Delayed' : 'On time';

      comparisonData.push([
        machine.name,
        machine.end_date ? new Date(machine.end_date).toLocaleDateString('fr-FR') : 'Non définie',
        status,
        delay,
        machineAnalytics ? machineAnalytics.availability_percentage.toFixed(2) : '0',
        machineAnalytics ? machineAnalytics.usage_percentage.toFixed(2) : '0',
        machineAnalytics ? machineAnalytics.transit_percentage.toFixed(2) : '0',
        machineAnalytics ? machineAnalytics.invoiced_percentage.toFixed(2) : '0',
        machineAnalytics ? machineAnalytics.missing_percentage.toFixed(2) : '0',
        machineAnalytics ? machineAnalytics.total_parts : 0
      ]);
    });

    const comparisonSheet = XLSX.utils.aoa_to_sheet(comparisonData);
    XLSX.utils.book_append_sheet(workbook, comparisonSheet, 'Machine Comparison');

    XLSX.writeFile(workbook, `comparative-dashboard-${currentProject?.name}-${new Date().toISOString().split('T')[0]}.xlsx`);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="h-12 w-12 animate-spin text-blue-600 mx-auto mb-4" />
          <p className="text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <AlertTriangle className="h-12 w-12 text-red-600 mx-auto mb-4" />
          <p className="text-red-800 mb-4">{error}</p>
          <Link to={`/projects/${projectId}`} className="text-blue-600 hover:text-blue-700">
            Back to Project
          </Link>
        </div>
      </div>
    );
  }

  if (!analytics || !currentProject) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <p className="text-gray-500 mb-4">Aucune donnée disponible</p>
          <Link to={`/projects/${projectId}`} className="text-blue-600 hover:text-blue-700">
            Back to Project
          </Link>
        </div>
      </div>
    );
  }

  const onTimeMachines = filteredMachines.filter(m => getMachineStatus(m) === 'on_time').length;
  const delayedMachines = filteredMachines.filter(m => getMachineStatus(m) === 'delayed').length;
  const onTimePercentage = filteredMachines.length > 0 ? (onTimeMachines / filteredMachines.length) * 100 : 0;

  const mostAdvancedMachine = analytics.machines.reduce((prev, current) =>
    (current.usage_percentage > prev.usage_percentage) ? current : prev
  , analytics.machines[0]);

  const mostDelayedMachineData = filteredMachines.reduce((prev, current) => {
    const prevDelay = calculateDelayInDays(prev);
    const currentDelay = calculateDelayInDays(current);
    return currentDelay > prevDelay ? current : prev;
  }, filteredMachines[0]);

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        <div className="mb-6">
          <Link
            to={`/projects/${projectId}`}
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors mb-4"
          >
            <ArrowLeft className="h-5 w-5" />
            Back to Project
          </Link>

          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Comparative Dashboard</h1>
              <p className="text-gray-600 mt-2">{currentProject.name}</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={handleRefreshData}
                disabled={isRefreshing}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:bg-blue-400 disabled:cursor-not-allowed"
              >
                <RefreshCw className={`h-5 w-5 ${isRefreshing ? 'animate-spin' : ''}`} />
                {isRefreshing ? 'Refreshing...' : 'Refresh'}
              </button>
              <button
                onClick={exportToExcel}
                className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
              >
                <Download className="h-5 w-5" />
                Export Excel
              </button>
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-2">
              <p className="text-sm font-medium text-gray-600">Total Machines</p>
              <Package className="h-5 w-5 text-gray-400" />
            </div>
            <p className="text-3xl font-bold text-gray-900">{analytics.total_machines}</p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-2">
              <p className="text-sm font-medium text-gray-600">Machines On Time</p>
              <CheckCircle className="h-5 w-5 text-green-600" />
            </div>
            <p className="text-3xl font-bold text-green-600">{onTimeMachines}</p>
            <p className="text-xs text-gray-500 mt-1">{onTimePercentage.toFixed(1)}% du total</p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-2">
              <p className="text-sm font-medium text-gray-600">Delayed Machines</p>
              <AlertTriangle className="h-5 w-5 text-red-600" />
            </div>
            <p className="text-3xl font-bold text-red-600">{delayedMachines}</p>
            <p className="text-xs text-gray-500 mt-1">{(100 - onTimePercentage).toFixed(1)}% du total</p>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center justify-between mb-2">
              <p className="text-sm font-medium text-gray-600">Global Impact</p>
              <TrendingUp className="h-5 w-5 text-blue-600" />
            </div>
            <p className="text-3xl font-bold text-gray-900">
              {analytics.overall_usage.toFixed(1)}%
            </p>
            <p className="text-xs text-gray-500 mt-1">Average Progress</p>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Most Advanced Machine</h3>
            <div className="flex items-center justify-between mb-3">
              <div>
                <p className="font-medium text-gray-900">{mostAdvancedMachine.machine_name}</p>
                <p className="text-sm text-gray-500">{mostAdvancedMachine.total_parts} parts</p>
              </div>
              <TrendingUp className="h-8 w-8 text-green-600" />
            </div>
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Usage</span>
                <span className="font-semibold text-green-600">{mostAdvancedMachine.usage_percentage.toFixed(1)}%</span>
              </div>
              <div className="w-full bg-gray-200 rounded-full h-2">
                <div
                  className="bg-green-600 h-2 rounded-full transition-all"
                  style={{ width: `${Math.min(mostAdvancedMachine.usage_percentage, 100)}%` }}
                />
              </div>
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">Most Delayed Machine</h3>
            <div className="flex items-center justify-between mb-3">
              <div>
                <p className="font-medium text-gray-900">{mostDelayedMachineData?.name || 'N/A'}</p>
                <p className="text-sm text-gray-500">
                  {mostDelayedMachineData?.end_date
                    ? `Deadline: ${new Date(mostDelayedMachineData.end_date).toLocaleDateString('en-US')}`
                    : 'No date defined'
                  }
                </p>
              </div>
              <TrendingDown className="h-8 w-8 text-red-600" />
            </div>
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Delay</span>
                <span className="font-semibold text-red-600">
                  {calculateDelayInDays(mostDelayedMachineData)} day(s)
                </span>
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6 mb-8">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Project Global Statistics</h3>
          <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
            <div>
              <p className="text-sm text-gray-600 mb-1">Availability</p>
              <p className="text-2xl font-bold text-green-600">{analytics.overall_availability.toFixed(1)}%</p>
              <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                <div
                  className="bg-green-600 h-2 rounded-full transition-all"
                  style={{ width: `${Math.min(analytics.overall_availability, 100)}%` }}
                />
              </div>
            </div>
            <div>
              <p className="text-sm text-gray-600 mb-1">Used</p>
              <p className="text-2xl font-bold text-blue-600">{analytics.overall_usage.toFixed(1)}%</p>
              <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                <div
                  className="bg-blue-600 h-2 rounded-full transition-all"
                  style={{ width: `${Math.min(analytics.overall_usage, 100)}%` }}
                />
              </div>
            </div>
            <div>
              <p className="text-sm text-gray-600 mb-1">En transit</p>
              <p className="text-2xl font-bold text-yellow-600">{analytics.overall_transit.toFixed(1)}%</p>
              <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                <div
                  className="bg-yellow-600 h-2 rounded-full transition-all"
                  style={{ width: `${Math.min(analytics.overall_transit, 100)}%` }}
                />
              </div>
            </div>
            <div>
              <p className="text-sm text-gray-600 mb-1">Invoiced</p>
              <p className="text-2xl font-bold text-purple-600">{analytics.overall_invoiced.toFixed(1)}%</p>
              <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                <div
                  className="bg-purple-600 h-2 rounded-full transition-all"
                  style={{ width: `${Math.min(analytics.overall_invoiced, 100)}%` }}
                />
              </div>
            </div>
            <div>
              <p className="text-sm text-gray-600 mb-1">Missing</p>
              <p className="text-2xl font-bold text-red-600">{analytics.overall_missing.toFixed(1)}%</p>
              <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
                <div
                  className="bg-red-600 h-2 rounded-full transition-all"
                  style={{ width: `${Math.min(analytics.overall_missing, 100)}%` }}
                />
              </div>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6 mb-8">
          <div className="flex items-center justify-between mb-6">
            <h3 className="text-lg font-semibold text-gray-900">Machine Comparison</h3>
            <div className="flex gap-3">
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value as any)}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="all">All machines</option>
                <option value="on_time">On time only</option>
                <option value="delayed">Delayed only</option>
              </select>
              <select
                value={selectedMetric}
                onChange={(e) => setSelectedMetric(e.target.value as any)}
                className="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="availability">Availability</option>
                <option value="usage">Usage</option>
                <option value="transit">In Transit</option>
                <option value="invoiced">Invoiced</option>
                <option value="missing">Missing</option>
              </select>
            </div>
          </div>

          <div className="space-y-4">
            {filteredMachines.map(machine => {
              const machineAnalytics = analytics.machines.find(m => m.machine_id === machine.id);
              if (!machineAnalytics) return null;

              const delay = calculateDelayInDays(machine);
              const isDelayed = delay > 0;

              let metricValue = 0;
              let metricColor = 'bg-blue-600';

              switch (selectedMetric) {
                case 'availability':
                  metricValue = machineAnalytics.availability_percentage;
                  metricColor = 'bg-green-600';
                  break;
                case 'usage':
                  metricValue = machineAnalytics.usage_percentage;
                  metricColor = 'bg-blue-600';
                  break;
                case 'transit':
                  metricValue = machineAnalytics.transit_percentage;
                  metricColor = 'bg-yellow-600';
                  break;
                case 'invoiced':
                  metricValue = machineAnalytics.invoiced_percentage;
                  metricColor = 'bg-purple-600';
                  break;
                case 'missing':
                  metricValue = machineAnalytics.missing_percentage;
                  metricColor = 'bg-red-600';
                  break;
              }

              return (
                <div key={machine.id} className={`border rounded-lg p-4 ${isDelayed ? 'border-red-300 bg-red-50' : 'border-gray-200'}`}>
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex-1">
                      <div className="flex items-center gap-3">
                        <h4 className="font-semibold text-gray-900">{machine.name}</h4>
                        {isDelayed ? (
                          <span className="inline-flex items-center gap-1 px-2 py-1 bg-red-100 text-red-800 rounded-full text-xs font-medium">
                            <AlertTriangle className="h-3 w-3" />
                            {delay} day(s) delay
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 px-2 py-1 bg-green-100 text-green-800 rounded-full text-xs font-medium">
                            <CheckCircle className="h-3 w-3" />
                            On Time
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-4 mt-1 text-sm text-gray-500">
                        <span>{machineAnalytics.total_parts} parts</span>
                        {machine.end_date && (
                          <span className="flex items-center gap-1">
                            <Calendar className="h-4 w-4" />
                            Deadline: {new Date(machine.end_date).toLocaleDateString('en-US')}
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="text-right">
                      <p className="text-2xl font-bold text-gray-900">{metricValue.toFixed(1)}%</p>
                      <p className="text-xs text-gray-500 capitalize">{selectedMetric}</p>
                    </div>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-3">
                    <div
                      className={`${metricColor} h-3 rounded-full transition-all`}
                      style={{ width: `${Math.min(metricValue, 100)}%` }}
                    />
                  </div>
                  <div className="grid grid-cols-4 gap-3 mt-3 pt-3 border-t">
                    <div className="text-center">
                      <p className="text-xs text-gray-600">Availability</p>
                      <p className="text-sm font-semibold text-green-600">
                        {machineAnalytics.availability_percentage.toFixed(1)}%
                      </p>
                    </div>
                    <div className="text-center">
                      <p className="text-xs text-gray-600">Used</p>
                      <p className="text-sm font-semibold text-blue-600">
                        {machineAnalytics.usage_percentage.toFixed(1)}%
                      </p>
                    </div>
                    <div className="text-center">
                      <p className="text-xs text-gray-600">En transit</p>
                      <p className="text-sm font-semibold text-yellow-600">
                        {machineAnalytics.transit_percentage.toFixed(1)}%
                      </p>
                    </div>
                    <div className="text-center">
                      <p className="text-xs text-gray-600">Missing</p>
                      <p className="text-sm font-semibold text-red-600">
                        {machineAnalytics.missing_percentage.toFixed(1)}%
                      </p>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}
