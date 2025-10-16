import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  ArrowLeft, 
  Settings, 
  RefreshCw, 
  CheckCircle, 
  AlertTriangle,
  Package,
  FileText,
  Calculator,
  Database
} from 'lucide-react';
import { supabase } from '../lib/supabase';

interface Project {
  id: string;
  name: string;
  calculation_method: 'or_based' | 'otc_based';
  status: string;
  created_at: string;
  updated_at: string;
}

interface ProjectCalculationMethod {
  project_id: string;
  project_name: string;
  calculation_method: string;
  calculation_method_description: string;
  machine_count: number;
  created_at: string;
  updated_at: string;
}

export function ProjectCalculationSettings() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [projectMethods, setProjectMethods] = useState<ProjectCalculationMethod[]>([]);
  const [loading, setLoading] = useState(true);
  const [switching, setSwitching] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);

  // Fetch projects and their calculation methods
  const fetchProjects = async () => {
    try {
      setLoading(true);
      
      // Fetch projects
      const { data: projectsData, error: projectsError } = await supabase
        .from('projects')
        .select('id, name, calculation_method, status, created_at, updated_at')
        .order('name');

      if (projectsError) throw projectsError;

      // Fetch project calculation methods view
      const { data: methodsData, error: methodsError } = await supabase
        .from('v_project_calculation_methods')
        .select('*')
        .order('project_name');

      if (methodsError) throw methodsError;

      setProjects(projectsData || []);
      setProjectMethods(methodsData || []);
    } catch (error) {
      console.error('Error fetching projects:', error);
      setMessage({ type: 'error', text: 'Failed to load projects' });
    } finally {
      setLoading(false);
    }
  };

  // Switch project calculation method
  const switchCalculationMethod = async (projectId: string, method: 'or_based' | 'otc_based') => {
    try {
      setSwitching(projectId);
      setMessage(null);

      const { error } = await supabase.rpc('switch_project_calculation_method', {
        project_uuid: projectId,
        method: method
      });

      if (error) throw error;

      setMessage({ 
        type: 'success', 
        text: `Project calculation method switched to ${method === 'or_based' ? 'OR-based' : 'OTC-based'}` 
      });
      
      // Refresh data
      await fetchProjects();
    } catch (error) {
      console.error('Error switching calculation method:', error);
      setMessage({ 
        type: 'error', 
        text: `Failed to switch calculation method: ${error.message}` 
      });
    } finally {
      setSwitching(null);
    }
  };

  // Refresh analytics views
  const refreshAnalytics = async () => {
    try {
      setRefreshing(true);
      setMessage(null);

      const { error } = await supabase.rpc('refresh_project_analytics_views');

      if (error) throw error;

      setMessage({ 
        type: 'success', 
        text: 'Project analytics views refreshed successfully' 
      });
    } catch (error) {
      console.error('Error refreshing analytics:', error);
      setMessage({ 
        type: 'error', 
        text: `Failed to refresh analytics: ${error.message}` 
      });
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchProjects();
  }, []);

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white flex items-center justify-center">
        <div className="text-center">
          <RefreshCw className="w-8 h-8 animate-spin text-[#FFCD11] mx-auto mb-4" />
          <p className="text-gray-600">Loading project calculation settings...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-white">
      {/* Header */}
      <div className="bg-white shadow-sm border-b border-gray-200">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          {/* Back to Dashboard Link */}
          <div className="mb-4">
            <Link
              to="/"
              className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors"
            >
              <ArrowLeft className="h-5 w-5" />
              Back to Dashboard
            </Link>
          </div>
          
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-2xl font-bold text-[#1A1A1A] flex items-center gap-2">
                <Settings className="h-8 w-8 text-[#FFCD11]" />
                Project Calculation Settings
              </h1>
              <p className="text-gray-600 mt-1">Configure calculation methods for project analytics</p>
            </div>
            <div className="flex gap-3">
              <button
                onClick={refreshAnalytics}
                disabled={refreshing}
                className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              >
                <RefreshCw className={`h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} />
                {refreshing ? 'Refreshing...' : 'Refresh Analytics'}
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Message */}
      {message && (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className={`rounded-lg p-4 ${
            message.type === 'success' 
              ? 'bg-green-50 border border-green-200 text-green-800' 
              : 'bg-red-50 border border-red-200 text-red-800'
          }`}>
            <div className="flex items-center gap-2">
              {message.type === 'success' ? (
                <CheckCircle className="h-5 w-5" />
              ) : (
                <AlertTriangle className="h-5 w-5" />
              )}
              <span className="font-medium">{message.text}</span>
            </div>
          </div>
        </div>
      )}

      {/* Information Panel */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
          <h2 className="text-lg font-semibold text-[#1A1A1A] mb-4 flex items-center gap-2">
            <Calculator className="h-5 w-5 text-blue-600" />
            Calculation Methods
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <FileText className="h-5 w-5 text-green-600" />
                <h3 className="font-semibold text-gray-900">OR-Based Calculation</h3>
              </div>
              <p className="text-sm text-gray-600 mb-2">
                Uses Operational Requests (ORs) to calculate used quantities.
              </p>
              <ul className="text-xs text-gray-500 space-y-1">
                <li>• Based on qte_livree from orders table</li>
                <li>• Linked through project_machine_order_numbers</li>
                <li>• Machine-specific calculation</li>
                <li>• Current default method</li>
              </ul>
            </div>
            <div className="border border-gray-200 rounded-lg p-4">
              <div className="flex items-center gap-2 mb-2">
                <Package className="h-5 w-5 text-purple-600" />
                <h3 className="font-semibold text-gray-900">OTC-Based Calculation</h3>
              </div>
              <p className="text-sm text-gray-600 mb-2">
                Uses Delivery Notes (BLs) from OTC module to calculate used quantities.
              </p>
              <ul className="text-xs text-gray-500 space-y-1">
                <li>• Based on qte_livree from otc_orders table</li>
                <li>• Linked through project_supplier_orders</li>
                <li>• Project-level cumulative calculation</li>
                <li>• No duplication across machines</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Projects Table */}
        <div className="bg-white rounded-lg shadow-lg overflow-hidden">
          <div className="px-6 py-4 border-b border-gray-200">
            <h2 className="text-lg font-semibold text-[#1A1A1A] flex items-center gap-2">
              <Database className="h-5 w-5 text-gray-600" />
              Project Calculation Methods
            </h2>
          </div>
          
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Project
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Current Method
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Machines
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {projects.map((project) => {
                  const methodInfo = projectMethods.find(m => m.project_id === project.id);
                  return (
                    <tr key={project.id}>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-[#1A1A1A]">
                          {project.name}
                        </div>
                        <div className="text-sm text-gray-500">
                          ID: {project.id.slice(0, 8)}...
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="flex items-center gap-2">
                          {project.calculation_method === 'or_based' ? (
                            <FileText className="h-4 w-4 text-green-600" />
                          ) : (
                            <Package className="h-4 w-4 text-purple-600" />
                          )}
                          <span className={`text-sm font-medium ${
                            project.calculation_method === 'or_based' 
                              ? 'text-green-600' 
                              : 'text-purple-600'
                          }`}>
                            {project.calculation_method === 'or_based' ? 'OR-Based' : 'OTC-Based'}
                          </span>
                        </div>
                        <div className="text-xs text-gray-500">
                          {methodInfo?.calculation_method_description || 'Unknown'}
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">
                          {methodInfo?.machine_count || 0} machines
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                          project.status === 'active' 
                            ? 'bg-green-100 text-green-800'
                            : project.status === 'completed'
                            ? 'bg-blue-100 text-blue-800'
                            : 'bg-yellow-100 text-yellow-800'
                        }`}>
                          {project.status}
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <div className="flex justify-center gap-2">
                          {project.calculation_method === 'or_based' ? (
                            <button
                              onClick={() => switchCalculationMethod(project.id, 'otc_based')}
                              disabled={switching === project.id}
                              className="flex items-center gap-1 px-3 py-1 bg-purple-600 text-white rounded-md hover:bg-purple-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-xs"
                            >
                              {switching === project.id ? (
                                <RefreshCw className="h-3 w-3 animate-spin" />
                              ) : (
                                <Package className="h-3 w-3" />
                              )}
                              Switch to OTC
                            </button>
                          ) : (
                            <button
                              onClick={() => switchCalculationMethod(project.id, 'or_based')}
                              disabled={switching === project.id}
                              className="flex items-center gap-1 px-3 py-1 bg-green-600 text-white rounded-md hover:bg-green-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed text-xs"
                            >
                              {switching === project.id ? (
                                <RefreshCw className="h-3 w-3 animate-spin" />
                              ) : (
                                <FileText className="h-3 w-3" />
                              )}
                              Switch to OR
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          {projects.length === 0 && (
            <div className="text-center py-12">
              <Database className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No projects found</h3>
              <p className="text-gray-500">Create a project first to configure calculation methods.</p>
            </div>
          )}
        </div>

        {/* Summary */}
        <div className="mt-6 bg-white rounded-lg shadow-lg p-6">
          <h3 className="text-lg font-semibold text-[#1A1A1A] mb-4">Summary</h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="text-center">
              <div className="text-2xl font-bold text-[#1A1A1A]">{projects.length}</div>
              <div className="text-sm text-gray-600">Total Projects</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">
                {projects.filter(p => p.calculation_method === 'or_based').length}
              </div>
              <div className="text-sm text-gray-600">OR-Based</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">
                {projects.filter(p => p.calculation_method === 'otc_based').length}
              </div>
              <div className="text-sm text-gray-600">OTC-Based</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
