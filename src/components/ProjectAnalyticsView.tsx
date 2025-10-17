import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ArrowLeft, Download, Loader2, AlertTriangle, CheckCircle, Clock, Package, RefreshCw } from 'lucide-react';
import { useProjectsStore } from '../store/projectsStore';
import { supabase } from '../lib/supabase';
import * as XLSX from 'xlsx';

const formatEtaDate = (etaString: string): string => {
  if (!etaString) return '-';

  // Handle different date formats
  const trimmedEta = etaString.trim();
  
  // Format: DD/MM/YYYY
  if (trimmedEta.includes('/')) {
    const parts = trimmedEta.split('/');
    if (parts.length === 3) {
      const day = parts[0].padStart(2, '0');
      const month = parts[1].padStart(2, '0');
      const year = parts[2];
      
      const date = new Date(`${year}-${month}-${day}`);
      if (!isNaN(date.getTime())) {
        return `${day}-${month}-${year}`;
      }
    }
  }
  
  // Format: YYYY-MM-DD
  if (trimmedEta.includes('-') && trimmedEta.length >= 8) {
    const date = new Date(trimmedEta);
    if (!isNaN(date.getTime())) {
      const day = date.getDate().toString().padStart(2, '0');
      const month = (date.getMonth() + 1).toString().padStart(2, '0');
      const year = date.getFullYear().toString();
      return `${day}-${month}-${year}`;
    }
  }
  
  // Format: DD-MM-YYYY
  if (trimmedEta.includes('-') && trimmedEta.length >= 8) {
    const parts = trimmedEta.split('-');
    if (parts.length === 3 && parts[0].length <= 2) {
      const day = parts[0].padStart(2, '0');
      const month = parts[1].padStart(2, '0');
      const year = parts[2];
      
      const date = new Date(`${year}-${month}-${day}`);
      if (!isNaN(date.getTime())) {
        return `${day}-${month}-${year}`;
      }
    }
  }
  
  // If we can't parse it, return the original string (might be a valid format we don't recognize)
  return trimmedEta;
};

export function ProjectAnalyticsView() {
  const { projectId } = useParams<{ projectId: string }>();
  const {
    currentProject,
    analytics,
    isLoading,
    error,
    fetchProjectById,
    calculateProjectAnalytics,
    refreshAnalyticsViews
  } = useProjectsStore();

  const [isRefreshing, setIsRefreshing] = useState(false);
  const [selectedMachineId, setSelectedMachineId] = useState<string | null>(null);
  const [refreshMessage, setRefreshMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  useEffect(() => {
    const loadAnalytics = async () => {
      if (projectId) {
        fetchProjectById(projectId);
        try {
          await refreshAnalyticsViews();
        } catch (error) {
          console.error('Failed to refresh views on load:', error);
        }
        await calculateProjectAnalytics(projectId);
      }
    };
    loadAnalytics();
  }, [projectId, fetchProjectById, calculateProjectAnalytics, refreshAnalyticsViews]);

  // Effet pour détecter les nouvelles machines et forcer le rafraîchissement
  useEffect(() => {
    const checkForNewMachines = async () => {
      if (projectId && analytics) {
        // Vérifier si le nombre de machines a changé
        const { data: currentMachines, error } = await supabase
          .from('project_machines')
          .select('id, name, created_at')
          .eq('project_id', projectId)
          .order('created_at', { ascending: true });

        if (error) {
          console.error('Error checking machines:', error);
          return;
        }

        const currentMachineCount = currentMachines?.length || 0;
        const analyticsMachineCount = analytics.machines.length;

        // Si le nombre de machines a changé, rafraîchir les analytics
        if (currentMachineCount !== analyticsMachineCount) {
          console.log(`Machine count changed: ${analyticsMachineCount} -> ${currentMachineCount}. Refreshing analytics...`);
          try {
            await refreshAnalyticsViews();
            await calculateProjectAnalytics(projectId);
          } catch (error) {
            console.error('Failed to refresh analytics for new machines:', error);
          }
        }
      }
    };

    // Vérifier toutes les 5 secondes si de nouvelles machines ont été ajoutées
    const interval = setInterval(checkForNewMachines, 5000);
    
    return () => clearInterval(interval);
  }, [projectId, analytics, refreshAnalyticsViews, calculateProjectAnalytics]);

  useEffect(() => {
    if (analytics && analytics.machines.length > 0 && !selectedMachineId) {
      setSelectedMachineId(analytics.machines[0].machine_id);
    }
  }, [analytics, selectedMachineId]);

  useEffect(() => {
    if (refreshMessage) {
      const timer = setTimeout(() => setRefreshMessage(null), 5000);
      return () => clearTimeout(timer);
    }
  }, [refreshMessage]);

  const handleRefreshData = async () => {
    if (!projectId) return;
    setIsRefreshing(true);
    setRefreshMessage(null);
    try {
      await refreshAnalyticsViews();
      await calculateProjectAnalytics(projectId);
      setRefreshMessage({ type: 'success', text: 'Data refreshed successfully!' });
    } catch (error) {
      console.error('Refresh error:', error);
      // Only show error if we don't have any analytics data
      if (!analytics) {
        setRefreshMessage({ type: 'error', text: 'Failed to refresh data. Please try again.' });
      } else {
        // If we have data, just show a warning that refresh failed but data is still available
        setRefreshMessage({ type: 'error', text: 'Refresh failed, but showing cached data.' });
      }
    } finally {
      setIsRefreshing(false);
    }
  };

  const exportToExcel = () => {
    if (!analytics) return;

    const workbook = XLSX.utils.book_new();

    const catYellow = 'FFCD00';
    const catBlack = '000000';
    const white = 'FFFFFF';
    const lightGray = 'F5F5F5';

    const summaryData = [
      ['Project Analysis Report'],
      [''],
      ['Project Name', analytics.project_name],
      ['Total Machines', analytics.total_machines],
      ['Export Date', new Date().toLocaleDateString()],
      [''],
      ['Global Statistics', ''],
      ['Metric', 'Percentage'],
      ['Overall Availability', analytics.overall_availability.toFixed(2)],
      ['Overall Usage', analytics.overall_usage.toFixed(2)],
      ['Overall In Backorders', analytics.overall_transit.toFixed(2)],
      ['Overall In Transit', analytics.overall_invoiced.toFixed(2)],
      ['Overall Missing', analytics.overall_missing.toFixed(2)]
    ];

    const summarySheet = XLSX.utils.aoa_to_sheet(summaryData);

    summarySheet['!cols'] = [{ wch: 25 }, { wch: 20 }];

    summarySheet['A1'].s = {
      font: { bold: true, sz: 16, color: { rgb: white } },
      fill: { fgColor: { rgb: catBlack } },
      alignment: { horizontal: 'center', vertical: 'center' }
    };
    if (summarySheet['B1']) {
      summarySheet['B1'].s = {
        fill: { fgColor: { rgb: catBlack } }
      };
    }

    ['A7', 'B7'].forEach(cell => {
      if (summarySheet[cell]) {
        summarySheet[cell].s = {
          font: { bold: true, sz: 12, color: { rgb: catBlack } },
          fill: { fgColor: { rgb: catYellow } },
          alignment: { horizontal: 'center', vertical: 'center' }
        };
      }
    });

    ['A8', 'B8'].forEach(cell => {
      if (summarySheet[cell]) {
        summarySheet[cell].s = {
          font: { bold: true, color: { rgb: white } },
          fill: { fgColor: { rgb: catBlack } },
          alignment: { horizontal: 'center', vertical: 'center' }
        };
      }
    });

    if (!summarySheet['!merges']) summarySheet['!merges'] = [];
    summarySheet['!merges'].push({ s: { r: 0, c: 0 }, e: { r: 0, c: 1 } });
    summarySheet['!merges'].push({ s: { r: 6, c: 0 }, e: { r: 6, c: 1 } });

    XLSX.utils.book_append_sheet(workbook, summarySheet, 'Summary');

    analytics.machines.forEach((machine) => {
      const machineData = [
        ['Machine Information'],
        [''],
        ['Machine Name', machine.machine_name],
        ['Total Parts', machine.total_parts],
        [''],
        ['Performance Metrics', ''],
        ['Metric', 'Percentage'],
        ['Availability', machine.availability_percentage.toFixed(2)],
        ['Usage', machine.usage_percentage.toFixed(2)],
        ['In Backorders', machine.transit_percentage.toFixed(2)],
        ['In Transit', machine.invoiced_percentage.toFixed(2)],
        ['Missing', machine.missing_percentage.toFixed(2)],
        [''],
        ['Parts Details'],
        ['Part Number', 'Description', 'Qty Required', 'Qty Available', 'Qty Used', 'Qty Backorders', 'Qty In Transit', 'Qty Missing', 'Latest ETA']
      ];

      machine.parts_details.forEach(part => {
        machineData.push([
          part.part_number,
          part.description || '-',
          part.quantity_required,
          part.quantity_available,
          part.quantity_used,
          part.quantity_in_transit,
          part.quantity_invoiced,
          part.quantity_missing,
          formatEtaDate(part.latest_eta || '')
        ]);
      });

      const machineSheet = XLSX.utils.aoa_to_sheet(machineData);

      machineSheet['!cols'] = [
        { wch: 18 },
        { wch: 35 },
        { wch: 13 },
        { wch: 13 },
        { wch: 13 },
        { wch: 15 },
        { wch: 15 },
        { wch: 13 },
        { wch: 15 }
      ];

      machineSheet['A1'].s = {
        font: { bold: true, sz: 14, color: { rgb: white } },
        fill: { fgColor: { rgb: catBlack } },
        alignment: { horizontal: 'center', vertical: 'center' }
      };
      if (machineSheet['B1']) {
        machineSheet['B1'].s = {
          fill: { fgColor: { rgb: catBlack } }
        };
      }

      ['A6', 'B6'].forEach(cell => {
        if (machineSheet[cell]) {
          machineSheet[cell].s = {
            font: { bold: true, sz: 12, color: { rgb: catBlack } },
            fill: { fgColor: { rgb: catYellow } },
            alignment: { horizontal: 'center', vertical: 'center' }
          };
        }
      });

      ['A7', 'B7'].forEach(cell => {
        if (machineSheet[cell]) {
          machineSheet[cell].s = {
            font: { bold: true, color: { rgb: white } },
            fill: { fgColor: { rgb: catBlack } },
            alignment: { horizontal: 'center', vertical: 'center' }
          };
        }
      });

      machineSheet['A14'].s = {
        font: { bold: true, sz: 12, color: { rgb: catBlack } },
        fill: { fgColor: { rgb: catYellow } },
        alignment: { horizontal: 'center', vertical: 'center' }
      };
      for (let i = 1; i < 9; i++) {
        const cell = XLSX.utils.encode_cell({ r: 13, c: i });
        if (machineSheet[cell]) {
          machineSheet[cell].s = {
            fill: { fgColor: { rgb: catYellow } }
          };
        }
      }

      ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'].forEach(col => {
        const cell = col + '15';
        if (machineSheet[cell]) {
          machineSheet[cell].s = {
            font: { bold: true, color: { rgb: white } },
            fill: { fgColor: { rgb: catBlack } },
            alignment: { horizontal: 'center', vertical: 'center' }
          };
        }
      });

      for (let i = 15; i < 15 + machine.parts_details.length; i++) {
        ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'].forEach((col, idx) => {
          const cell = col + (i + 1);
          if (machineSheet[cell]) {
            machineSheet[cell].s = {
              fill: { fgColor: { rgb: i % 2 === 0 ? white : lightGray } },
              alignment: { horizontal: idx === 1 ? 'left' : 'center', vertical: 'center' }
            };
          }
        });
      }

      if (!machineSheet['!merges']) machineSheet['!merges'] = [];
      machineSheet['!merges'].push({ s: { r: 0, c: 0 }, e: { r: 0, c: 1 } });
      machineSheet['!merges'].push({ s: { r: 5, c: 0 }, e: { r: 5, c: 1 } });
      machineSheet['!merges'].push({ s: { r: 13, c: 0 }, e: { r: 13, c: 8 } });

      let sheetName = machine.machine_name.replace(/[:\\\/\?\*\[\]]/g, '-').substring(0, 31);
      XLSX.utils.book_append_sheet(workbook, machineSheet, sheetName);
    });

    XLSX.writeFile(workbook, `analyse-projet-${analytics.project_name}-${new Date().toISOString().split('T')[0]}.xlsx`);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <Loader2 className="h-12 w-12 animate-spin text-blue-600 mx-auto mb-4" />
          <p className="text-gray-600">Calculating analytics...</p>
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
          <p className="text-gray-500 mb-4">No analytics data available</p>
          <Link to={`/projects/${projectId}`} className="text-blue-600 hover:text-blue-700">
            Back to Project
          </Link>
        </div>
      </div>
    );
  }

  if (analytics.machines.length === 0) {
    return (
      <div className="min-h-screen bg-gray-50 p-6">
        <div className="max-w-7xl mx-auto">
          <Link
            to={`/projects/${projectId}`}
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors mb-4"
          >
            <ArrowLeft className="h-5 w-5" />
            Back to Project
          </Link>
          <div className="bg-white rounded-lg shadow p-12 text-center">
            <Package className="h-16 w-16 mx-auto mb-4 text-gray-400" />
            <h2 className="text-2xl font-bold text-gray-900 mb-2">No Machines Found</h2>
            <p className="text-gray-600 mb-6">
              This project doesn't have any machines yet. Add machines to view analytics.
            </p>
            <Link
              to={`/projects/${projectId}`}
              className="inline-flex items-center gap-2 px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
            >
              Go to Project Details
            </Link>
          </div>
        </div>
      </div>
    );
  }

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
              <h1 className="text-3xl font-bold text-gray-900">Project Analytics</h1>
              <p className="text-gray-600 mt-2">{currentProject.name}</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={handleRefreshData}
                disabled={isRefreshing}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:bg-blue-400 disabled:cursor-not-allowed"
              >
                <RefreshCw className={`h-5 w-5 ${isRefreshing ? 'animate-spin' : ''}`} />
                {isRefreshing ? 'Refreshing...' : 'Refresh Data'}
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

          {refreshMessage && (
            <div className={`mt-4 p-4 rounded-lg ${
              refreshMessage.type === 'success'
                ? 'bg-green-50 border border-green-200 text-green-800'
                : 'bg-red-50 border border-red-200 text-red-800'
            }`}>
              <div className="flex items-center gap-2">
                {refreshMessage.type === 'success' ? (
                  <CheckCircle className="h-5 w-5" />
                ) : (
                  <AlertTriangle className="h-5 w-5" />
                )}
                <span className="font-medium">{refreshMessage.text}</span>
              </div>
            </div>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-6 mb-8">
          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-green-100 rounded-lg">
                <CheckCircle className="h-6 w-6 text-green-600" />
              </div>
              <div>
                <p className="text-sm text-gray-600">Availability</p>
                <p className="text-2xl font-bold text-gray-900">
                  {analytics.overall_availability.toFixed(1)}%
                </p>
              </div>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
              <div
                className="bg-green-600 h-2 rounded-full transition-all"
                style={{ width: `${Math.min(analytics.overall_availability, 100)}%` }}
              />
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-blue-100 rounded-lg">
                <Package className="h-6 w-6 text-blue-600" />
              </div>
              <div>
                <p className="text-sm text-gray-600">Used</p>
                <p className="text-2xl font-bold text-gray-900">
                  {analytics.overall_usage.toFixed(1)}%
                </p>
              </div>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
              <div
                className="bg-blue-600 h-2 rounded-full transition-all"
                style={{ width: `${Math.min(analytics.overall_usage, 100)}%` }}
              />
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-yellow-100 rounded-lg">
                <Clock className="h-6 w-6 text-yellow-600" />
              </div>
              <div>
                <p className="text-sm text-gray-600">In backorders</p>
                <p className="text-2xl font-bold text-gray-900">
                  {analytics.overall_transit.toFixed(1)}%
                </p>
              </div>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
              <div
                className="bg-yellow-600 h-2 rounded-full transition-all"
                style={{ width: `${Math.min(analytics.overall_transit, 100)}%` }}
              />
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-purple-100 rounded-lg">
                <Package className="h-6 w-6 text-purple-600" />
              </div>
              <div>
                <p className="text-sm text-gray-600">In transit</p>
                <p className="text-2xl font-bold text-gray-900">
                  {analytics.overall_invoiced.toFixed(1)}%
                </p>
              </div>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
              <div
                className="bg-purple-600 h-2 rounded-full transition-all"
                style={{ width: `${Math.min(analytics.overall_invoiced, 100)}%` }}
              />
            </div>
          </div>

          <div className="bg-white rounded-lg shadow p-6">
            <div className="flex items-center gap-3 mb-2">
              <div className="p-2 bg-red-100 rounded-lg">
                <AlertTriangle className="h-6 w-6 text-red-600" />
              </div>
              <div>
                <p className="text-sm text-gray-600">Missing</p>
                <p className="text-2xl font-bold text-gray-900">
                  {analytics.overall_missing.toFixed(1)}%
                </p>
              </div>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-3">
              <div
                className="bg-red-600 h-2 rounded-full transition-all"
                style={{ width: `${Math.min(analytics.overall_missing, 100)}%` }}
              />
            </div>
          </div>
        </div>

        <div className="bg-white rounded-lg shadow p-6 mb-6">
          <label htmlFor="machine-select" className="block text-sm font-medium text-gray-700 mb-2">
            Select a Machine
          </label>
          <select
            id="machine-select"
            value={selectedMachineId || ''}
            onChange={(e) => setSelectedMachineId(e.target.value)}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
          >
            {analytics.machines.map((machine) => (
              <option key={machine.machine_id} value={machine.machine_id}>
                {machine.machine_name} ({machine.total_parts} parts)
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-6">
          {analytics.machines.filter(m => m.machine_id === selectedMachineId).map((machine) => (
            <div key={machine.machine_id} className="bg-white rounded-lg shadow">
              <div className="p-6 border-b">
                <div className="flex justify-between items-start mb-4">
                  <h2 className="text-xl font-bold text-gray-900">{machine.machine_name}</h2>
                  <span className="px-3 py-1 bg-gray-100 rounded-full text-sm font-medium text-gray-700">
                    {machine.total_parts} parts
                  </span>
                </div>

                <div className="grid grid-cols-5 gap-4">
                  <div>
                    <p className="text-sm text-gray-600">Availability</p>
                    <p className="text-lg font-semibold text-green-600">
                      {machine.availability_percentage.toFixed(1)}%
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Used</p>
                    <p className="text-lg font-semibold text-blue-600">
                      {machine.usage_percentage.toFixed(1)}%
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">In backorders</p>
                    <p className="text-lg font-semibold text-yellow-600">
                      {machine.transit_percentage.toFixed(1)}%
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">In transit</p>
                    <p className="text-lg font-semibold text-purple-600">
                      {machine.invoiced_percentage.toFixed(1)}%
                    </p>
                  </div>
                  <div>
                    <p className="text-sm text-gray-600">Missing</p>
                    <p className="text-lg font-semibold text-red-600">
                      {machine.missing_percentage.toFixed(1)}%
                    </p>
                  </div>
                </div>
              </div>

              <div className="p-6">
                <h3 className="font-semibold text-gray-900 mb-4">Parts Details</h3>

                {machine.parts_details.some(p => p.quantity_missing > 0) && (
                  <div className="mb-4 bg-red-50 border border-red-200 rounded-lg p-4">
                    <div className="flex items-start gap-3">
                      <AlertTriangle className="h-5 w-5 text-red-600 mt-0.5" />
                      <div>
                        <h4 className="font-semibold text-red-900 mb-1">Alerts - Missing Parts</h4>
                        <p className="text-sm text-red-800">
                          <strong>{machine.machine_name}:</strong>{' '}
                          {machine.parts_details.reduce((sum, p) => sum + p.quantity_missing, 0)} part(s) missing
                        </p>
                        <p className="mt-2 text-sm text-red-700">
                          These parts are neither in stock nor on order. Please contact the project team.
                        </p>
                      </div>
                    </div>
                  </div>
                )}

                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="bg-gray-50">
                      <tr>
                        <th className="px-4 py-3 text-left font-medium text-gray-700">Number</th>
                        <th className="px-4 py-3 text-left font-medium text-gray-700">Description</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">Required</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">Available</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">Used</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">Backorders</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">In transit</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">Missing</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">Latest ETA</th>
                        <th className="px-4 py-3 text-center font-medium text-gray-700">Status</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y">
                      {machine.parts_details.map((part, index) => {
                        const isMissing = part.quantity_missing > 0;
                        const isComplete = part.quantity_used >= part.quantity_required;
                        const isAvailable = !isMissing && !isComplete && part.quantity_available > 0;

                        return (
                          <tr key={index} className={isMissing ? 'bg-red-50' : 'hover:bg-gray-50'}>
                            <td className="px-4 py-3 font-medium">{part.part_number}</td>
                            <td className="px-4 py-3 text-gray-600">{part.description || '-'}</td>
                            <td className="px-4 py-3 text-center">{part.quantity_required}</td>
                            <td className="px-4 py-3 text-center text-green-600 font-medium">
                              {part.quantity_available}
                            </td>
                            <td className="px-4 py-3 text-center text-blue-600 font-medium">
                              {part.quantity_used}
                            </td>
                            <td className="px-4 py-3 text-center text-yellow-600 font-medium">
                              {part.quantity_in_transit}
                            </td>
                            <td className="px-4 py-3 text-center text-purple-600 font-medium">
                              {part.quantity_invoiced}
                            </td>
                            <td className="px-4 py-3 text-center text-red-600 font-medium">
                              {part.quantity_missing}
                            </td>
                            <td className="px-4 py-3 text-center">
                              {(() => {
                                const eta = formatEtaDate(part.latest_eta || '');
                                const shouldHaveEta = part.quantity_in_transit > 0 || part.quantity_missing > 0;
                                
                                if (eta === '-' && shouldHaveEta) {
                                  return (
                                    <span className="text-red-600 font-medium" title="ETA missing for part in transit/backorder">
                                      ⚠️ Missing
                                    </span>
                                  );
                                }
                                
                                return (
                                  <span className={eta === '-' ? 'text-gray-500' : 'text-gray-700'}>
                                    {eta}
                                  </span>
                                );
                              })()}
                            </td>
                            <td className="px-4 py-3 text-center">
                              {isMissing ? (
                                <span className="inline-flex items-center gap-1 px-2 py-1 bg-red-100 text-red-800 rounded-full text-xs font-medium">
                                  <AlertTriangle className="h-3 w-3" />
                                  Missing
                                </span>
                              ) : isComplete ? (
                                <span className="inline-flex items-center gap-1 px-2 py-1 bg-green-100 text-green-800 rounded-full text-xs font-medium">
                                  <CheckCircle className="h-3 w-3" />
                                  Complete
                                </span>
                              ) : isAvailable ? (
                                <span className="inline-flex items-center gap-1 px-2 py-1 bg-blue-100 text-blue-800 rounded-full text-xs font-medium">
                                  <Package className="h-3 w-3" />
                                  Available
                                </span>
                              ) : (
                                <span className="inline-flex items-center gap-1 px-2 py-1 bg-yellow-100 text-yellow-800 rounded-full text-xs font-medium">
                                  <Clock className="h-3 w-3" />
                                  In Progress
                                </span>
                              )}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}