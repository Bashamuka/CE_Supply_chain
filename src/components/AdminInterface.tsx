import React, { useState, useEffect, useMemo } from 'react';
import { Users, Shield, Lock, UserPlus, Trash2, Edit2, Save, X, ArrowLeft, CheckCircle2, Search, AlertCircle } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAdminStore } from '../store/adminStore';
import { useProjectsStore } from '../store/projectsStore';
import { useUserStore } from '../store/userStore';
import { supabase } from '../lib/supabase';
import { AdminDiagnostic } from './AdminDiagnostic';
import type { UserProfile, ModuleName } from '../types';

const MODULES: { name: ModuleName; label: string }[] = [
  { name: 'global_dashboard', label: 'Global Dashboard' },
  { name: 'eta_tracking', label: 'ETA Tracking' },
  { name: 'stock_availability', label: 'Stock Availability' },
  { name: 'parts_equivalence', label: 'Parts Equivalence' },
  { name: 'orders', label: 'Orders Management' },
  { name: 'projects', label: 'Projects Management' },
  { name: 'dealer_forward_planning', label: 'Dealer Forward Planning' },
];

export default function AdminInterface() {
  const { user } = useUserStore();
  const {
    users,
    loading,
    error,
    fetchUsers,
    createUser,
    updateUserRole,
    deleteUser,
    fetchUserModuleAccess,
    fetchUserProjectAccess,
    setModuleAccess,
    setProjectAccess,
  } = useAdminStore();

  const { projects, fetchProjects } = useProjectsStore();

  const [selectedUser, setSelectedUser] = useState<UserProfile | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [userModuleAccess, setUserModuleAccess] = useState<Record<ModuleName, boolean>>({
    global_dashboard: false,
    eta_tracking: false,
    stock_availability: false,
    parts_equivalence: false,
    orders: false,
    projects: false,
    dealer_forward_planning: false,
  });
  const [originalModuleAccess, setOriginalModuleAccess] = useState<Record<ModuleName, boolean>>({
    global_dashboard: false,
    eta_tracking: false,
    stock_availability: false,
    parts_equivalence: false,
    orders: false,
    projects: false,
    dealer_forward_planning: false,
  });
  const [userProjectAccess, setUserProjectAccess] = useState<Set<string>>(new Set());
  const [originalProjectAccess, setOriginalProjectAccess] = useState<Set<string>>(new Set());
  const [hasUnsavedChanges, setHasUnsavedChanges] = useState(false);
  const [savingChanges, setSavingChanges] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);

  const [showCreateUser, setShowCreateUser] = useState(false);
  const [newUserEmail, setNewUserEmail] = useState('');
  const [newUserPassword, setNewUserPassword] = useState('');
  const [newUserRole, setNewUserRole] = useState<'admin' | 'employee' | 'consultant'>('employee');

  const [editingRole, setEditingRole] = useState<string | null>(null);
  const [editRole, setEditRole] = useState<'admin' | 'employee' | 'consultant'>('employee');

  const filteredUsers = useMemo(() => {
    if (!searchQuery.trim()) return users;
    const query = searchQuery.toLowerCase();
    return users.filter(u =>
      u.email.toLowerCase().includes(query) ||
      u.role.toLowerCase().includes(query)
    );
  }, [users, searchQuery]);

  useEffect(() => {
    fetchUsers();
    fetchProjects();
  }, []);

  useEffect(() => {
    if (selectedUser) {
      loadUserPermissions(selectedUser.id);
    }
  }, [selectedUser]);

  useEffect(() => {
    const moduleChanged = Object.keys(userModuleAccess).some(
      key => userModuleAccess[key as ModuleName] !== originalModuleAccess[key as ModuleName]
    );

    const projectChanged =
      userProjectAccess.size !== originalProjectAccess.size ||
      Array.from(userProjectAccess).some(id => !originalProjectAccess.has(id));

    setHasUnsavedChanges(moduleChanged || projectChanged);
  }, [userModuleAccess, userProjectAccess, originalModuleAccess, originalProjectAccess]);

  const loadUserPermissions = async (userId: string) => {
    const moduleAccessData = await fetchUserModuleAccess(userId);
    const projectAccessData = await fetchUserProjectAccess(userId);

    const moduleAccessMap: Record<ModuleName, boolean> = {
      global_dashboard: false,
      eta_tracking: false,
      stock_availability: false,
      parts_equivalence: false,
      orders: false,
      projects: false,
      dealer_forward_planning: false,
    };

    moduleAccessData.forEach(access => {
      moduleAccessMap[access.module_name] = access.has_access;
    });

    setUserModuleAccess(moduleAccessMap);
    setOriginalModuleAccess({ ...moduleAccessMap });

    const projectSet = new Set(projectAccessData.map(p => p.project_id));
    setUserProjectAccess(projectSet);
    setOriginalProjectAccess(new Set(projectSet));

    setHasUnsavedChanges(false);
  };

  const handleCreateUser = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await createUser(newUserEmail, newUserPassword, newUserRole);
      setShowCreateUser(false);
      setNewUserEmail('');
      setNewUserPassword('');
      setNewUserRole('employee');
    } catch (error) {
      console.error('Failed to create user');
    }
  };

  const handleUpdateRole = async (userId: string) => {
    try {
      await updateUserRole(userId, editRole);
      setEditingRole(null);
    } catch (error) {
      console.error('Failed to update role');
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (confirm('Êtes-vous sûr de vouloir supprimer cet utilisateur ?')) {
      try {
        await deleteUser(userId);
        if (selectedUser?.id === userId) {
          setSelectedUser(null);
        }
      } catch (error) {
        console.error('Failed to delete user');
      }
    }
  };

  const handleToggleModuleAccess = (moduleName: ModuleName) => {
    setUserModuleAccess(prev => ({ ...prev, [moduleName]: !prev[moduleName] }));
  };

  const handleToggleProjectAccess = (projectId: string) => {
    setUserProjectAccess(prev => {
      const newSet = new Set(prev);
      if (newSet.has(projectId)) {
        newSet.delete(projectId);
      } else {
        newSet.add(projectId);
      }
      return newSet;
    });
  };

  const handleSaveChanges = async () => {
    if (!selectedUser) return;

    setSavingChanges(true);
    setSaveSuccess(false);
    setSaveError(null);

    try {
      console.log('=== SAVING CHANGES ===');
      console.log('Selected user:', selectedUser?.email);
      console.log('Module access changes:', userModuleAccess);

      const modulePromises = Object.entries(userModuleAccess).map(([moduleName, hasAccess]) =>
        setModuleAccess(selectedUser.id, moduleName as ModuleName, hasAccess)
      );

      const addedProjects = Array.from(userProjectAccess).filter(id => !originalProjectAccess.has(id));
      const removedProjects = Array.from(originalProjectAccess).filter(id => !userProjectAccess.has(id));

      const projectPromises = [
        ...addedProjects.map(projectId => setProjectAccess(selectedUser.id, projectId, true)),
        ...removedProjects.map(projectId => setProjectAccess(selectedUser.id, projectId, false))
      ];

      await Promise.all([...modulePromises, ...projectPromises]);

      setOriginalModuleAccess({ ...userModuleAccess });
      setOriginalProjectAccess(new Set(userProjectAccess));
      setHasUnsavedChanges(false);
      setSaveSuccess(true);

      console.log('✅ All changes saved successfully');
      setTimeout(() => setSaveSuccess(false), 3000);
    } catch (error: any) {
      console.error('Failed to save changes:', error);
      let errorMessage = 'Erreur lors de la sauvegarde des modifications';
      
      if (error.message) {
        if (error.message.includes('Database error')) {
          errorMessage = `Erreur de base de données: ${error.message.replace('Database error: ', '')}`;
        } else if (error.message.includes('constraint')) {
          errorMessage = 'Erreur de contrainte de base de données. Veuillez vérifier que tous les modules sont correctement configurés.';
        } else {
          errorMessage = error.message;
        }
      }
      
      setSaveError(errorMessage);
      setTimeout(() => setSaveError(null), 5000);
    } finally {
      setSavingChanges(false);
    }
  };

  const handleCancelChanges = () => {
    setUserModuleAccess({ ...originalModuleAccess });
    setUserProjectAccess(new Set(originalProjectAccess));
    setHasUnsavedChanges(false);
  };

  const handleUserSelect = (userId: string) => {
    const selected = users.find(u => u.id === userId);
    if (selected) {
      setSelectedUser(selected);
      setSearchQuery('');
    }
  };

  if (user?.role !== 'admin') {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="text-center">
          <Lock className="w-16 h-16 text-red-500 mx-auto mb-4" />
          <h2 className="text-2xl font-bold text-gray-800 mb-2">Access Denied</h2>
          <p className="text-gray-600">
            You don't have the necessary permissions to access this section.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="h-screen flex flex-col bg-gray-50">
      <div className="bg-white border-b border-gray-200 p-6 shadow-sm">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-4">
            <Link
              to="/"
              className="flex items-center space-x-2 px-4 py-2 text-gray-600 hover:text-gray-800 hover:bg-gray-100 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-5 h-5" />
              <span>Back</span>
            </Link>
            <div className="flex items-center space-x-3">
              <Shield className="w-8 h-8 text-blue-600" />
              <div>
                <h1 className="text-2xl font-bold text-gray-800">Administration</h1>
                <p className="text-sm text-gray-600">User and permissions management</p>
              </div>
            </div>
          </div>
          <button
            onClick={() => setShowCreateUser(true)}
            className="flex items-center space-x-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            <UserPlus className="w-5 h-5" />
            <span>New User</span>
          </button>
        </div>
      </div>

      {/* Diagnostic Component */}
      <div className="px-6 py-4">
        <AdminDiagnostic />
      </div>

      {error && (
        <div className="bg-red-50 border-l-4 border-red-500 p-4 m-6">
          <p className="text-red-700">{error}</p>
        </div>
      )}

      <div className="flex-1 flex overflow-hidden">
        <div className="w-1/3 border-r border-gray-200 bg-white overflow-y-auto">
          <div className="p-4">
            <h2 className="text-lg font-semibold text-gray-800 mb-4 flex items-center">
              <Users className="w-5 h-5 mr-2" />
              Utilisateurs ({users.length})
            </h2>

            {/* Search Bar */}
            <div className="mb-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                <input
                  type="text"
                  placeholder="Rechercher un utilisateur..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
            </div>

            {/* User Dropdown */}
            <div className="mb-4">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Sélectionner un utilisateur
              </label>
              <select
                value={selectedUser?.id || ''}
                onChange={(e) => handleUserSelect(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-white"
              >
                <option value="">-- Choisir un utilisateur --</option>
                {users.map(u => (
                  <option key={u.id} value={u.id}>
                    {u.email} ({u.role})
                  </option>
                ))}
              </select>
            </div>

            {loading && users.length === 0 ? (
              <div className="text-center py-8 text-gray-500">Chargement...</div>
            ) : filteredUsers.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                <Search className="w-12 h-12 mx-auto mb-2 text-gray-400" />
                <p>Aucun utilisateur trouvé</p>
              </div>
            ) : (
              <div className="space-y-2">
                {filteredUsers.map(u => (
                  <div
                    key={u.id}
                    className={`p-4 rounded-lg border-2 cursor-pointer transition-all ${
                      selectedUser?.id === u.id
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300 bg-white'
                    }`}
                    onClick={() => setSelectedUser(u)}
                  >
                    <div className="flex items-start justify-between">
                      <div className="flex-1 min-w-0">
                        <p className="font-medium text-gray-800 truncate">{u.email}</p>
                        {editingRole === u.id ? (
                          <div className="flex items-center space-x-2 mt-2">
                            <select
                              value={editRole}
                              onChange={(e) => setEditRole(e.target.value as any)}
                              className="text-sm border border-gray-300 rounded px-2 py-1"
                              onClick={(e) => e.stopPropagation()}
                            >
                              <option value="admin">Admin</option>
                              <option value="employee">Employee</option>
                              <option value="consultant">Consultant</option>
                            </select>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleUpdateRole(u.id);
                              }}
                              className="p-1 text-green-600 hover:text-green-700"
                            >
                              <Save className="w-4 h-4" />
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setEditingRole(null);
                              }}
                              className="p-1 text-gray-600 hover:text-gray-700"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>
                        ) : (
                          <div className="flex items-center space-x-2 mt-1">
                            <span className={`text-xs px-2 py-1 rounded-full ${
                              u.role === 'admin' ? 'bg-purple-100 text-purple-700' :
                              u.role === 'consultant' ? 'bg-green-100 text-green-700' :
                              'bg-gray-100 text-gray-700'
                            }`}>
                              {u.role}
                            </span>
                          </div>
                        )}
                      </div>
                      <div className="flex items-center space-x-1 ml-2">
                        {editingRole !== u.id && u.id !== user?.id && (
                          <>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                setEditingRole(u.id);
                                setEditRole(u.role);
                              }}
                              className="p-1 text-blue-600 hover:text-blue-700"
                            >
                              <Edit2 className="w-4 h-4" />
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation();
                                handleDeleteUser(u.id);
                              }}
                              className="p-1 text-red-600 hover:text-red-700"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-6">
          {selectedUser ? (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h2 className="text-xl font-bold text-gray-800">
                  Permissions pour {selectedUser.email}
                </h2>
                <div className="flex items-center space-x-3">
                  {saveError && (
                    <div className="flex items-center space-x-2 text-red-600 bg-red-50 px-4 py-2 rounded-lg">
                      <AlertCircle className="w-5 h-5" />
                      <span className="text-sm font-medium">{saveError}</span>
                    </div>
                  )}
                  {saveSuccess && (
                    <div className="flex items-center space-x-2 text-green-600 bg-green-50 px-4 py-2 rounded-lg">
                      <CheckCircle2 className="w-5 h-5" />
                      <span className="font-medium">Modifications enregistrées</span>
                    </div>
                  )}
                  {hasUnsavedChanges && !saveSuccess && !saveError && (
                    <>
                      <button
                        onClick={handleCancelChanges}
                        disabled={savingChanges}
                        className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors disabled:opacity-50"
                      >
                        Annuler
                      </button>
                      <button
                        onClick={handleSaveChanges}
                        disabled={savingChanges}
                        className="flex items-center space-x-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors disabled:opacity-50"
                      >
                        <Save className="w-5 h-5" />
                        <span>{savingChanges ? 'Enregistrement...' : 'Enregistrer'}</span>
                      </button>
                    </>
                  )}
                </div>
              </div>

              <div className="bg-white rounded-lg border border-gray-200 p-6">
                <h3 className="text-lg font-semibold text-gray-800 mb-4">Accès aux Modules</h3>
                <div className="space-y-3">
                  {MODULES.map(module => (
                    <label
                      key={module.name}
                      className="flex items-center justify-between p-3 rounded-lg border border-gray-200 hover:bg-gray-50 cursor-pointer"
                    >
                      <span className="text-gray-700">{module.label}</span>
                      <input
                        type="checkbox"
                        checked={userModuleAccess[module.name]}
                        onChange={() => handleToggleModuleAccess(module.name)}
                        className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                      />
                    </label>
                  ))}
                </div>
              </div>

              {userModuleAccess.projects && (
                <div className="bg-white rounded-lg border border-gray-200 p-6">
                  <h3 className="text-lg font-semibold text-gray-800 mb-4">Accès aux Projets</h3>
                  {projects.length === 0 ? (
                    <p className="text-gray-500 text-center py-4">Aucun projet disponible</p>
                  ) : (
                    <div className="space-y-3">
                      {projects.map(project => (
                        <label
                          key={project.id}
                          className="flex items-center justify-between p-3 rounded-lg border border-gray-200 hover:bg-gray-50 cursor-pointer"
                        >
                          <div>
                            <p className="text-gray-700 font-medium">{project.name}</p>
                            {project.description && (
                              <p className="text-sm text-gray-500">{project.description}</p>
                            )}
                          </div>
                          <input
                            type="checkbox"
                            checked={userProjectAccess.has(project.id)}
                            onChange={() => handleToggleProjectAccess(project.id)}
                            className="w-5 h-5 text-blue-600 rounded focus:ring-2 focus:ring-blue-500"
                          />
                        </label>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </div>
          ) : (
            <div className="flex items-center justify-center h-full text-gray-500">
              <div className="text-center">
                <Users className="w-16 h-16 mx-auto mb-4 text-gray-400" />
                <p>Sélectionnez un utilisateur pour gérer ses permissions</p>
              </div>
            </div>
          )}
        </div>
      </div>

      {showCreateUser && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 w-full max-w-md">
            <h2 className="text-xl font-bold text-gray-800 mb-4">Créer un Utilisateur</h2>
            <form onSubmit={handleCreateUser} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email
                </label>
                <input
                  type="email"
                  value={newUserEmail}
                  onChange={(e) => setNewUserEmail(e.target.value)}
                  required
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Mot de passe
                </label>
                <input
                  type="password"
                  value={newUserPassword}
                  onChange={(e) => setNewUserPassword(e.target.value)}
                  required
                  minLength={6}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Rôle
                </label>
                <select
                  value={newUserRole}
                  onChange={(e) => setNewUserRole(e.target.value as any)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                >
                  <option value="employee">Employee</option>
                  <option value="consultant">Consultant</option>
                  <option value="admin">Admin</option>
                </select>
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowCreateUser(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  disabled={loading}
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50"
                >
                  {loading ? 'Création...' : 'Créer'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}