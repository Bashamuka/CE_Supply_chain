import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeft, Plus, CreditCard as Edit2, Trash2, Eye, Calendar, Loader2, Settings } from 'lucide-react';
import { useProjectsStore } from '../store/projectsStore';
import { useUserStore } from '../store/userStore';
import { useAdminStore } from '../store/adminStore';
import { Project } from '../types';

export function ProjectsInterface() {
  const user = useUserStore((state) => state.user);
  const {
    projects,
    isLoading,
    error,
    fetchProjects,
    createProject,
    updateProject,
    deleteProject
  } = useProjectsStore();

  const { fetchUserProjectAccess } = useAdminStore();

  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [editingProject, setEditingProject] = useState<Project | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    status: 'active' as 'active' | 'completed' | 'on_hold',
    start_date: '',
    end_date: ''
  });
  const [accessibleProjects, setAccessibleProjects] = useState<Project[]>([]);
  const [loadingAccess, setLoadingAccess] = useState(true);

  useEffect(() => {
    fetchProjects();
  }, [fetchProjects]);

  useEffect(() => {
    const filterProjects = async () => {
      if (!user) {
        setAccessibleProjects([]);
        setLoadingAccess(false);
        return;
      }

      if (user.role === 'admin') {
        setAccessibleProjects(projects);
        setLoadingAccess(false);
        return;
      }

      try {
        const userAccess = await fetchUserProjectAccess(user.id);
        const accessibleIds = new Set(userAccess.map(a => a.project_id));
        setAccessibleProjects(projects.filter(p => accessibleIds.has(p.id)));
      } catch (error) {
        console.error('Error filtering projects:', error);
        setAccessibleProjects([]);
      } finally {
        setLoadingAccess(false);
      }
    };

    setLoadingAccess(true);
    filterProjects();
  }, [user, projects, fetchUserProjectAccess]);

  const isAdmin = user?.role === 'admin';

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    const result = await createProject(formData);
    if (result) {
      setShowCreateModal(false);
      setFormData({
        name: '',
        description: '',
        status: 'active',
        start_date: '',
        end_date: ''
      });
    }
  };

  const handleEdit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingProject) return;

    await updateProject(editingProject.id, formData);
    setShowEditModal(false);
    setEditingProject(null);
    setFormData({
      name: '',
      description: '',
      status: 'active',
      start_date: '',
      end_date: ''
    });
  };

  const handleDelete = async (id: string) => {
    if (window.confirm('Are you sure you want to delete this project? This action is irreversible.')) {
      await deleteProject(id);
    }
  };

  const openEditModal = (project: Project) => {
    setEditingProject(project);
    setFormData({
      name: project.name,
      description: project.description || '',
      status: project.status,
      start_date: project.start_date || '',
      end_date: project.end_date || ''
    });
    setShowEditModal(true);
  };

  const getStatusBadge = (status: string) => {
    const styles = {
      active: 'bg-green-100 text-green-800',
      completed: 'bg-blue-100 text-blue-800',
      on_hold: 'bg-yellow-100 text-yellow-800'
    };
    const labels = {
      active: 'Active',
      completed: 'Completed',
      on_hold: 'On Hold'
    };
    return (
      <span className={`px-2 py-1 rounded-full text-xs font-medium ${styles[status as keyof typeof styles]}`}>
        {labels[status as keyof typeof labels]}
      </span>
    );
  };

  const formatDate = (dateString: string | undefined) => {
    if (!dateString) return '-';
    const date = new Date(dateString);
    return date.toLocaleDateString('fr-FR');
  };

  return (
    <div className="min-h-screen bg-gray-50 p-6">
      <div className="max-w-7xl mx-auto">
        <div className="mb-6">
          <Link
            to="/dashboard"
            className="inline-flex items-center gap-2 text-gray-600 hover:text-gray-900 transition-colors mb-4"
          >
            <ArrowLeft className="h-5 w-5" />
            Back to Dashboard
          </Link>

          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Project Management</h1>
              <p className="text-gray-600 mt-2">Create and track your machine projects</p>
            </div>
            <div className="flex gap-3">
              <Link
                to="/project-calculation-settings"
                className="flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
              >
                <Settings className="h-5 w-5" />
                Calculation Settings
              </Link>
              {isAdmin && (
                <button
                  onClick={() => setShowCreateModal(true)}
                  className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors"
                >
                  <Plus className="h-5 w-5" />
                  New Project
                </button>
              )}
            </div>
          </div>
        </div>

        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-red-800">{error}</p>
          </div>
        )}

        {/* Calculation Methods Information */}
        <div className="mb-6 bg-gradient-to-r from-purple-50 to-indigo-50 rounded-lg p-6 border border-purple-200">
          <div className="flex items-center gap-3 mb-4">
            <Settings className="h-6 w-6 text-purple-600" />
            <h2 className="text-lg font-semibold text-gray-900">Calculation Methods</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="bg-white rounded-lg p-4 border border-gray-200">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-3 h-3 bg-green-500 rounded-full"></div>
                <h3 className="font-semibold text-gray-900">OR-Based Calculation</h3>
              </div>
              <p className="text-sm text-gray-600 mb-2">
                Uses Operational Requests (ORs) to calculate used quantities.
              </p>
              <ul className="text-xs text-gray-500 space-y-1">
                <li>• Based on orders table (qte_livree)</li>
                <li>• Machine-specific calculation</li>
                <li>• Traditional method</li>
              </ul>
            </div>
            <div className="bg-white rounded-lg p-4 border border-gray-200">
              <div className="flex items-center gap-2 mb-2">
                <div className="w-3 h-3 bg-purple-500 rounded-full"></div>
                <h3 className="font-semibold text-gray-900">OTC-Based Calculation</h3>
              </div>
              <p className="text-sm text-gray-600 mb-2">
                Uses Delivery Notes (BLs) from OTC module to calculate used quantities.
              </p>
              <ul className="text-xs text-gray-500 space-y-1">
                <li>• Based on otc_orders table (qte_livree)</li>
                <li>• Project-level cumulative calculation</li>
                <li>• No duplication across machines</li>
              </ul>
            </div>
          </div>
          <div className="mt-4 text-center">
            <Link
              to="/project-calculation-settings"
              className="inline-flex items-center gap-2 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors text-sm"
            >
              <Settings className="h-4 w-4" />
              Configure Calculation Methods
            </Link>
          </div>
        </div>

        {isLoading || loadingAccess ? (
          <div className="flex justify-center items-center h-64">
            <Loader2 className="h-8 w-8 animate-spin text-gray-400" />
          </div>
        ) : accessibleProjects.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-lg shadow">
            <p className="text-gray-500">
              {projects.length === 0 ? 'No projects found' : 'You have no access to any projects'}
            </p>
            {isAdmin && projects.length === 0 && (
              <button
                onClick={() => setShowCreateModal(true)}
                className="mt-4 text-green-600 hover:text-green-700 font-medium"
              >
                Create your first project
              </button>
            )}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {accessibleProjects.map((project) => (
              <div key={project.id} className="bg-white rounded-lg shadow hover:shadow-lg transition-shadow">
                <div className="p-6">
                  <div className="flex justify-between items-start mb-4">
                    <h3 className="text-xl font-semibold text-gray-900">{project.name}</h3>
                    {getStatusBadge(project.status)}
                  </div>

                  {project.description && (
                    <p className="text-gray-600 text-sm mb-4 line-clamp-2">{project.description}</p>
                  )}

                  <div className="space-y-2 mb-4">
                    {project.start_date && (
                      <div className="flex items-center gap-2 text-sm text-gray-500">
                        <Calendar className="h-4 w-4" />
                        <span>Start: {formatDate(project.start_date)}</span>
                      </div>
                    )}
                    {project.end_date && (
                      <div className="flex items-center gap-2 text-sm text-gray-500">
                        <Calendar className="h-4 w-4" />
                        <span>End: {formatDate(project.end_date)}</span>
                      </div>
                    )}
                  </div>

                  <div className="flex gap-2">
                    <Link
                      to={`/projects/${project.id}`}
                      className="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                    >
                      <Eye className="h-4 w-4" />
                      View
                    </Link>
                    {isAdmin && (
                      <>
                        <button
                          onClick={() => openEditModal(project)}
                          className="px-3 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                        >
                          <Edit2 className="h-4 w-4 text-gray-600" />
                        </button>
                        <button
                          onClick={() => handleDelete(project.id)}
                          className="px-3 py-2 border border-red-300 rounded-lg hover:bg-red-50 transition-colors"
                        >
                          <Trash2 className="h-4 w-4 text-red-600" />
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {(showCreateModal || showEditModal) && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-lg max-w-2xl w-full max-h-[90vh] overflow-y-auto">
              <div className="p-6">
                <h2 className="text-2xl font-bold text-gray-900 mb-6">
                  {showCreateModal ? 'Create New Project' : 'Edit Project'}
                </h2>

                <form onSubmit={showCreateModal ? handleCreate : handleEdit} className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Project Name *
                    </label>
                    <input
                      type="text"
                      required
                      value={formData.name}
                      onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      placeholder="Ex: PCR MUMI Project"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Description
                    </label>
                    <textarea
                      value={formData.description}
                      onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      rows={3}
                      placeholder="Project description"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">
                      Status
                    </label>
                    <select
                      value={formData.status}
                      onChange={(e) => setFormData({ ...formData, status: e.target.value as any })}
                      className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                    >
                      <option value="active">Active</option>
                      <option value="completed">Completed</option>
                      <option value="on_hold">On Hold</option>
                    </select>
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Start Date
                      </label>
                      <input
                        type="date"
                        value={formData.start_date}
                        onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      />
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        End Date
                      </label>
                      <input
                        type="date"
                        value={formData.end_date}
                        onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
                        className="w-full px-3 py-2 border rounded-lg focus:ring-2 focus:ring-blue-500 outline-none"
                      />
                    </div>
                  </div>

                  <div className="flex gap-3 pt-4">
                    <button
                      type="submit"
                      disabled={isLoading}
                      className="flex-1 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                    >
                      {isLoading ? (
                        <Loader2 className="h-5 w-5 animate-spin mx-auto" />
                      ) : showCreateModal ? (
                        'Create'
                      ) : (
                        'Save'
                      )}
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setShowCreateModal(false);
                        setShowEditModal(false);
                        setEditingProject(null);
                        setFormData({
                          name: '',
                          description: '',
                          status: 'active',
                          start_date: '',
                          end_date: ''
                        });
                      }}
                      className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
