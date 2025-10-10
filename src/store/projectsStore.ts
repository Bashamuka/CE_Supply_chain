import { create } from 'zustand';
import { supabase } from '../lib/supabase';
import {
  Project,
  ProjectMachine,
  ProjectMachinePart,
  ProjectMachineOrderNumber,
  ProjectSupplierOrder,
  ProjectBranch,
  ProjectAnalytics,
  MachineAnalytics
} from '../types';

interface ProjectsState {
  projects: Project[];
  currentProject: Project | null;
  machines: ProjectMachine[];
  machineOrderNumbers: ProjectMachineOrderNumber[];
  machineParts: ProjectMachinePart[];
  supplierOrders: ProjectSupplierOrder[];
  branches: ProjectBranch[];
  analytics: ProjectAnalytics | null;
  isLoading: boolean;
  error: string | null;

  fetchProjects: () => Promise<void>;
  fetchProjectById: (id: string) => Promise<void>;
  createProject: (project: Omit<Project, 'id' | 'created_at' | 'updated_at'>) => Promise<Project | null>;
  updateProject: (id: string, updates: Partial<Project>) => Promise<void>;
  deleteProject: (id: string) => Promise<void>;

  fetchMachines: (projectId: string) => Promise<void>;
  createMachine: (machine: Omit<ProjectMachine, 'id' | 'created_at' | 'updated_at'>) => Promise<ProjectMachine | null>;
  updateMachine: (id: string, updates: Partial<ProjectMachine>) => Promise<void>;
  deleteMachine: (id: string) => Promise<void>;

  fetchMachineOrderNumbers: (machineId: string) => Promise<void>;
  createMachineOrderNumber: (orderNumber: Omit<ProjectMachineOrderNumber, 'id' | 'created_at'>) => Promise<ProjectMachineOrderNumber | null>;
  deleteMachineOrderNumber: (id: string) => Promise<void>;

  fetchMachineParts: (machineId: string) => Promise<void>;
  createMachinePart: (part: Omit<ProjectMachinePart, 'id' | 'created_at' | 'updated_at'>) => Promise<ProjectMachinePart | null>;
  updateMachinePart: (id: string, updates: Partial<ProjectMachinePart>) => Promise<void>;
  deleteMachinePart: (id: string) => Promise<void>;

  fetchSupplierOrders: (projectId: string) => Promise<void>;
  createSupplierOrder: (order: Omit<ProjectSupplierOrder, 'id' | 'created_at' | 'updated_at'>) => Promise<ProjectSupplierOrder | null>;
  deleteSupplierOrder: (id: string) => Promise<void>;

  fetchBranches: (projectId: string) => Promise<void>;
  createBranch: (branch: Omit<ProjectBranch, 'id' | 'created_at'>) => Promise<ProjectBranch | null>;
  deleteBranch: (id: string) => Promise<void>;

  calculateProjectAnalytics: (projectId: string) => Promise<void>;
  refreshAnalyticsViews: () => Promise<void>;

  reset: () => void;
}

export const useProjectsStore = create<ProjectsState>((set, get) => ({
  projects: [],
  currentProject: null,
  machines: [],
  machineOrderNumbers: [],
  machineParts: [],
  supplierOrders: [],
  branches: [],
  analytics: null,
  isLoading: false,
  error: null,

  fetchProjects: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('projects')
        .select('*')
        .order('created_at', { ascending: false });

      if (error) throw error;
      set({ projects: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  fetchProjectById: async (id: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('projects')
        .select('*')
        .eq('id', id)
        .single();

      if (error) throw error;
      set({ currentProject: data, isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  createProject: async (project) => {
    set({ isLoading: true, error: null });
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('User not authenticated');

      const { data, error } = await supabase
        .from('projects')
        .insert([{ ...project, created_by: user.id }])
        .select()
        .single();

      if (error) throw error;
      set({ isLoading: false });
      await get().fetchProjects();
      return data;
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
      return null;
    }
  },

  updateProject: async (id, updates) => {
    set({ isLoading: true, error: null });
    try {
      const { error } = await supabase
        .from('projects')
        .update(updates)
        .eq('id', id);

      if (error) throw error;
      set({ isLoading: false });
      await get().fetchProjects();
      if (get().currentProject?.id === id) {
        await get().fetchProjectById(id);
      }
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  deleteProject: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const { error } = await supabase
        .from('projects')
        .delete()
        .eq('id', id);

      if (error) throw error;
      set({ isLoading: false });
      await get().fetchProjects();
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  fetchMachines: async (projectId: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_machines')
        .select('*')
        .eq('project_id', projectId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      set({ machines: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  createMachine: async (machine) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_machines')
        .insert([machine])
        .select()
        .single();

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      set({ isLoading: false });
      await get().fetchMachines(machine.project_id);
      return data;
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
      return null;
    }
  },

  updateMachine: async (id, updates) => {
    set({ isLoading: true, error: null });
    try {
      const { error } = await supabase
        .from('project_machines')
        .update(updates)
        .eq('id', id);

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      const machine = get().machines.find(m => m.id === id);
      if (machine) {
        await get().fetchMachines(machine.project_id);
      }
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  deleteMachine: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const machine = get().machines.find(m => m.id === id);
      const { error } = await supabase
        .from('project_machines')
        .delete()
        .eq('id', id);

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      if (machine) {
        await get().fetchMachines(machine.project_id);
      }
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  fetchMachineOrderNumbers: async (machineId: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_machine_order_numbers')
        .select('*')
        .eq('machine_id', machineId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      set({ machineOrderNumbers: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  createMachineOrderNumber: async (orderNumber) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_machine_order_numbers')
        .insert([orderNumber])
        .select()
        .single();

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      set({ isLoading: false });
      await get().fetchMachineOrderNumbers(orderNumber.machine_id);
      return data;
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
      return null;
    }
  },

  deleteMachineOrderNumber: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const orderNumber = get().machineOrderNumbers.find(o => o.id === id);
      const { error } = await supabase
        .from('project_machine_order_numbers')
        .delete()
        .eq('id', id);

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      if (orderNumber) {
        await get().fetchMachineOrderNumbers(orderNumber.machine_id);
      }
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  fetchMachineParts: async (machineId: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_machine_parts')
        .select('*')
        .eq('machine_id', machineId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      set({ machineParts: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  createMachinePart: async (part) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_machine_parts')
        .insert([part])
        .select()
        .single();

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      set({ isLoading: false });
      await get().fetchMachineParts(part.machine_id);
      return data;
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
      return null;
    }
  },

  updateMachinePart: async (id, updates) => {
    set({ isLoading: true, error: null });
    try {
      const { error } = await supabase
        .from('project_machine_parts')
        .update(updates)
        .eq('id', id);

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      const part = get().machineParts.find(p => p.id === id);
      if (part) {
        await get().fetchMachineParts(part.machine_id);
      }
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  deleteMachinePart: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const part = get().machineParts.find(p => p.id === id);
      const { error } = await supabase
        .from('project_machine_parts')
        .delete()
        .eq('id', id);

      if (error) throw error;

      await supabase.rpc('refresh_project_analytics_views');

      if (part) {
        await get().fetchMachineParts(part.machine_id);
      }
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  fetchSupplierOrders: async (projectId: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_supplier_orders')
        .select('*')
        .eq('project_id', projectId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      set({ supplierOrders: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  createSupplierOrder: async (order) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_supplier_orders')
        .insert([order])
        .select()
        .single();

      if (error) throw error;
      set({ isLoading: false });
      await get().fetchSupplierOrders(order.project_id);
      return data;
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
      return null;
    }
  },

  deleteSupplierOrder: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const order = get().supplierOrders.find(o => o.id === id);
      const { error } = await supabase
        .from('project_supplier_orders')
        .delete()
        .eq('id', id);

      if (error) throw error;

      if (order) {
        await get().fetchSupplierOrders(order.project_id);
      }
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  fetchBranches: async (projectId: string) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_branches')
        .select('*')
        .eq('project_id', projectId)
        .order('created_at', { ascending: true });

      if (error) throw error;
      set({ branches: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  createBranch: async (branch) => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('project_branches')
        .insert([branch])
        .select()
        .single();

      if (error) throw error;
      set({ isLoading: false });
      await get().fetchBranches(branch.project_id);
      return data;
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
      return null;
    }
  },

  deleteBranch: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const branch = get().branches.find(b => b.id === id);
      const { error } = await supabase
        .from('project_branches')
        .delete()
        .eq('id', id);

      if (error) throw error;

      if (branch) {
        await get().fetchBranches(branch.project_id);
      }
      set({ isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  refreshAnalyticsViews: async () => {
    try {
      const { error } = await supabase
        .rpc('refresh_project_analytics_views', {});
      if (error) {
        console.error('RPC Error:', error);
        throw error;
      }
    } catch (error) {
      console.error('Error refreshing analytics views:', error);
      throw error;
    }
  },

  calculateProjectAnalytics: async (projectId: string) => {
    set({ isLoading: true, error: null });
    try {
      const state = get();

      await state.fetchMachines(projectId);
      const machines = state.machines;

      const { data: analyticsData, error: analyticsError } = await supabase
        .from('mv_project_analytics_complete')
        .select('*')
        .eq('project_id', projectId);

      if (analyticsError) throw analyticsError;

      const machineAnalytics: MachineAnalytics[] = [];
      const machinesMap = new Map<string, MachineAnalytics>();

      for (const machine of machines) {
        const machineParts = analyticsData?.filter(d => d.machine_id === machine.id) || [];

        const partsDetails = machineParts.map(p => ({
          part_number: p.part_number,
          description: p.description || '',
          quantity_required: Number(p.quantity_required) || 0,
          quantity_available: Number(p.quantity_available) || 0,
          quantity_used: Number(p.quantity_used) || 0,
          quantity_in_transit: Number(p.quantity_in_transit) || 0,
          quantity_invoiced: Number(p.quantity_invoiced) || 0,
          quantity_missing: Number(p.quantity_missing) || 0,
          latest_eta: p.latest_eta || undefined
        }));

        // Calculate percentages part by part, capping each at 100%
        let totalAvailabilityPercent = 0;
        let totalUsagePercent = 0;
        let totalTransitPercent = 0;
        let totalInvoicedPercent = 0;
        let totalMissingPercent = 0;

        for (const part of partsDetails) {
          if (part.quantity_required > 0) {
            // Cap each metric at 100% of what's required for this part
            totalAvailabilityPercent += Math.min(100, (part.quantity_available / part.quantity_required) * 100);
            totalUsagePercent += Math.min(100, (part.quantity_used / part.quantity_required) * 100);
            totalTransitPercent += Math.min(100, (part.quantity_in_transit / part.quantity_required) * 100);
            totalInvoicedPercent += Math.min(100, (part.quantity_invoiced / part.quantity_required) * 100);
            totalMissingPercent += Math.min(100, (part.quantity_missing / part.quantity_required) * 100);
          }
        }

        // Average the percentages across all parts
        const numParts = partsDetails.length;
        const machineAnalytic: MachineAnalytics = {
          machine_id: machine.id,
          machine_name: machine.name,
          total_parts: numParts,
          availability_percentage: numParts > 0 ? totalAvailabilityPercent / numParts : 0,
          usage_percentage: numParts > 0 ? totalUsagePercent / numParts : 0,
          transit_percentage: numParts > 0 ? totalTransitPercent / numParts : 0,
          invoiced_percentage: numParts > 0 ? totalInvoicedPercent / numParts : 0,
          missing_percentage: numParts > 0 ? totalMissingPercent / numParts : 0,
          parts_details: partsDetails
        };

        machineAnalytics.push(machineAnalytic);
        machinesMap.set(machine.id, machineAnalytic);
      }

      // Calculate global percentages using part-by-part approach
      const globalPartsMap = new Map<string, {
        quantity_required: number;
        quantity_available: number;
        quantity_used: number;
        quantity_in_transit: number;
        quantity_invoiced: number;
        quantity_missing: number;
      }>();

      // Build global parts map (sum across all machines)
      for (const machine of machineAnalytics) {
        for (const part of machine.parts_details) {
          const existing = globalPartsMap.get(part.part_number);
          if (existing) {
            existing.quantity_required += part.quantity_required;
            existing.quantity_used += part.quantity_used;
          } else {
            globalPartsMap.set(part.part_number, {
              quantity_required: part.quantity_required,
              quantity_available: part.quantity_available,
              quantity_used: part.quantity_used,
              quantity_in_transit: part.quantity_in_transit,
              quantity_invoiced: part.quantity_invoiced,
              quantity_missing: 0
            });
          }
        }
      }

      // Calculate missing quantities
      for (const [partNumber, quantities] of globalPartsMap.entries()) {
        quantities.quantity_missing = Math.max(0,
          quantities.quantity_required -
          quantities.quantity_available -
          quantities.quantity_used -
          quantities.quantity_in_transit -
          quantities.quantity_invoiced
        );
      }

      // Calculate overall percentages part-by-part, capping at 100% per part
      let overallAvailabilityPercent = 0;
      let overallUsagePercent = 0;
      let overallTransitPercent = 0;
      let overallInvoicedPercent = 0;
      let overallMissingPercent = 0;

      for (const [partNumber, quantities] of globalPartsMap.entries()) {
        if (quantities.quantity_required > 0) {
          // Cap each part's contribution at 100%
          overallAvailabilityPercent += Math.min(100, (quantities.quantity_available / quantities.quantity_required) * 100);
          overallUsagePercent += Math.min(100, (quantities.quantity_used / quantities.quantity_required) * 100);
          overallTransitPercent += Math.min(100, (quantities.quantity_in_transit / quantities.quantity_required) * 100);
          overallInvoicedPercent += Math.min(100, (quantities.quantity_invoiced / quantities.quantity_required) * 100);
          overallMissingPercent += Math.min(100, (quantities.quantity_missing / quantities.quantity_required) * 100);
        }
      }

      // Average across all unique parts in the project
      const totalUniqueParts = globalPartsMap.size;

      const project = state.currentProject;
      const analytics: ProjectAnalytics = {
        project_id: projectId,
        project_name: project?.name || '',
        total_machines: machines.length,
        overall_availability: totalUniqueParts > 0 ? overallAvailabilityPercent / totalUniqueParts : 0,
        overall_usage: totalUniqueParts > 0 ? overallUsagePercent / totalUniqueParts : 0,
        overall_transit: totalUniqueParts > 0 ? overallTransitPercent / totalUniqueParts : 0,
        overall_invoiced: totalUniqueParts > 0 ? overallInvoicedPercent / totalUniqueParts : 0,
        overall_missing: totalUniqueParts > 0 ? overallMissingPercent / totalUniqueParts : 0,
        machines: machineAnalytics
      };

      set({ analytics, isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  reset: () => {
    set({
      projects: [],
      currentProject: null,
      machines: [],
      machineParts: [],
      supplierOrders: [],
      branches: [],
      analytics: null,
      isLoading: false,
      error: null
    });
  }
}));
