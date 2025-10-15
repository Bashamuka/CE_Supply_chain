import { create } from 'zustand';
import { supabase } from '../lib/supabase';
import type { UserProfile, UserModuleAccess, UserProjectAccess, ModuleName } from '../types';

interface AdminStore {
  users: UserProfile[];
  moduleAccess: UserModuleAccess[];
  projectAccess: UserProjectAccess[];
  loading: boolean;
  error: string | null;

  fetchUsers: () => Promise<void>;
  fetchUserModuleAccess: (userId: string) => Promise<UserModuleAccess[]>;
  fetchUserProjectAccess: (userId: string) => Promise<UserProjectAccess[]>;

  createUser: (email: string, password: string, role: 'admin' | 'employee' | 'consultant') => Promise<void>;
  updateUserRole: (userId: string, role: 'admin' | 'employee' | 'consultant') => Promise<void>;
  deleteUser: (userId: string) => Promise<void>;

  setModuleAccess: (userId: string, moduleName: ModuleName, hasAccess: boolean) => Promise<void>;
  setProjectAccess: (userId: string, projectId: string, hasAccess: boolean) => Promise<void>;

  checkModuleAccess: (userId: string, moduleName: ModuleName) => Promise<boolean>;
  checkProjectAccess: (userId: string, projectId: string) => Promise<boolean>;
}

export const useAdminStore = create<AdminStore>((set, get) => ({
  users: [],
  moduleAccess: [],
  projectAccess: [],
  loading: false,
  error: null,

  fetchUsers: async () => {
    set({ loading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('profiles')
        .select('*')
        .order('email');

      if (error) throw error;
      set({ users: data || [] });
    } catch (error: any) {
      set({ error: error.message });
      console.error('Error fetching users:', error);
    } finally {
      set({ loading: false });
    }
  },

  fetchUserModuleAccess: async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('user_module_access')
        .select('*')
        .eq('user_id', userId);

      if (error) throw error;
      return data || [];
    } catch (error: any) {
      console.error('Error fetching module access:', error);
      return [];
    }
  },

  fetchUserProjectAccess: async (userId: string) => {
    try {
      const { data, error } = await supabase
        .from('user_project_access')
        .select('*')
        .eq('user_id', userId);

      if (error) throw error;
      return data || [];
    } catch (error: any) {
      console.error('Error fetching project access:', error);
      return [];
    }
  },

  createUser: async (email: string, password: string, role: 'admin' | 'employee' | 'consultant') => {
    set({ loading: true, error: null });
    try {
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email,
        password,
      });

      if (authError) throw authError;

      if (authData.user) {
        const { error: profileError } = await supabase
          .from('profiles')
          .update({ role })
          .eq('id', authData.user.id);

        if (profileError) throw profileError;

        await get().fetchUsers();
      }
    } catch (error: any) {
      set({ error: error.message });
      console.error('Error creating user:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  updateUserRole: async (userId: string, role: 'admin' | 'employee' | 'consultant') => {
    set({ loading: true, error: null });
    try {
      const { error } = await supabase
        .from('profiles')
        .update({ role })
        .eq('id', userId);

      if (error) throw error;
      await get().fetchUsers();
    } catch (error: any) {
      set({ error: error.message });
      console.error('Error updating user role:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  deleteUser: async (userId: string) => {
    set({ loading: true, error: null });
    try {
      const { error } = await supabase.auth.admin.deleteUser(userId);

      if (error) throw error;
      await get().fetchUsers();
    } catch (error: any) {
      set({ error: error.message });
      console.error('Error deleting user:', error);
      throw error;
    } finally {
      set({ loading: false });
    }
  },

  setModuleAccess: async (userId: string, moduleName: ModuleName, hasAccess: boolean) => {
    try {
      console.log(`Setting module access: userId=${userId}, module=${moduleName}, access=${hasAccess}`);
      
      const { error } = await supabase
        .from('user_module_access')
        .upsert({
          user_id: userId,
          module_name: moduleName,
          has_access: hasAccess,
        }, {
          onConflict: 'user_id,module_name'
        });

      if (error) {
        console.error('Supabase error setting module access:', error);
        console.error('Error details:', {
          code: error.code,
          message: error.message,
          details: error.details,
          hint: error.hint
        });
        
        // Provide more specific error messages
        if (error.code === '42501') {
          throw new Error('Permission refusée: Vérifiez que vous êtes connecté en tant qu\'administrateur');
        } else if (error.code === '23514') {
          throw new Error(`Module '${moduleName}' non autorisé. Veuillez contacter l'administrateur système.`);
        } else if (error.code === '23503') {
          throw new Error('Utilisateur non trouvé dans la base de données');
        } else if (error.code === '23505') {
          throw new Error('Cette permission existe déjà');
        } else {
          throw new Error(`Erreur de base de données (${error.code}): ${error.message || 'Erreur inconnue'}`);
        }
      }
      
      console.log(`Module access set successfully for ${moduleName}`);
    } catch (error: any) {
      console.error('Error setting module access:', error);
      throw error;
    }
  },

  setProjectAccess: async (userId: string, projectId: string, hasAccess: boolean) => {
    try {
      if (hasAccess) {
        const { error } = await supabase
          .from('user_project_access')
          .insert({
            user_id: userId,
            project_id: projectId,
          });

        if (error && error.code !== '23505') throw error;
      } else {
        const { error } = await supabase
          .from('user_project_access')
          .delete()
          .eq('user_id', userId)
          .eq('project_id', projectId);

        if (error) throw error;
      }
    } catch (error: any) {
      console.error('Error setting project access:', error);
      throw error;
    }
  },

  checkModuleAccess: async (userId: string, moduleName: ModuleName) => {
    try {
      const { data, error } = await supabase
        .rpc('check_user_module_access', {
          p_user_id: userId,
          p_module_name: moduleName
        });

      if (error) throw error;
      return data || false;
    } catch (error: any) {
      console.error('Error checking module access:', error);
      return false;
    }
  },

  checkProjectAccess: async (userId: string, projectId: string) => {
    try {
      const { data, error } = await supabase
        .rpc('check_user_project_access', {
          p_user_id: userId,
          p_project_id: projectId
        });

      if (error) throw error;
      return data || false;
    } catch (error: any) {
      console.error('Error checking project access:', error);
      return false;
    }
  },
}));