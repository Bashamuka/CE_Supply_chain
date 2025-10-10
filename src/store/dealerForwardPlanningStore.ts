import { create } from 'zustand';
import { supabase } from '../lib/supabase';
import { DealerForwardPlanning, Message } from '../types';

interface DealerForwardPlanningStore {
  records: DealerForwardPlanning[];
  messages: Message[];
  isLoading: boolean;
  error: string | null;
  uploadProgress: number;

  fetchRecords: () => Promise<void>;
  uploadRecords: (records: Omit<DealerForwardPlanning, 'id' | 'uploaded_by' | 'upload_date' | 'created_at' | 'updated_at'>[], onProgress?: (current: number, total: number) => void) => Promise<void>;
  updateRecord: (id: string, updates: Partial<DealerForwardPlanning>) => Promise<void>;
  deleteRecord: (id: string) => Promise<void>;
  deleteAllRecords: () => Promise<void>;
  addMessage: (message: Omit<Message, 'id' | 'timestamp'>) => void;
  resetChat: () => void;
}

export const useDealerForwardPlanningStore = create<DealerForwardPlanningStore>((set, get) => ({
  records: [],
  messages: [],
  isLoading: false,
  error: null,
  uploadProgress: 0,

  fetchRecords: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data, error } = await supabase
        .from('dealer_forward_planning')
        .select('*')
        .order('upload_date', { ascending: false });

      if (error) throw error;
      set({ records: data || [], isLoading: false });
    } catch (error) {
      set({ error: (error as Error).message, isLoading: false });
    }
  },

  uploadRecords: async (records, onProgress) => {
    set({ isLoading: true, error: null, uploadProgress: 0 });
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('User not authenticated');

      let insertedCount = 0;
      let updatedCount = 0;

      for (let i = 0; i < records.length; i++) {
        const record = records[i];
        const { data, error } = await supabase.rpc('upsert_dealer_forward_planning', {
          p_part_number: record.part_number,
          p_model: record.model || null,
          p_forecast_quantity: record.forecast_quantity,
          p_business_case_notes: record.business_case_notes || null,
          p_uploaded_by: user.id
        });

        if (error) {
          console.error('Error upserting record:', error);
          throw error;
        }

        const { data: existingCheck } = await supabase
          .from('dealer_forward_planning')
          .select('created_at, updated_at')
          .eq('id', data)
          .single();

        if (existingCheck && existingCheck.created_at !== existingCheck.updated_at) {
          updatedCount++;
        } else {
          insertedCount++;
        }

        const progress = i + 1;
        set({ uploadProgress: progress });
        if (onProgress) {
          onProgress(progress, records.length);
        }
      }

      get().addMessage({
        content: `Upload completed: ${insertedCount} new record(s) added, ${updatedCount} existing record(s) updated (quantities merged).`,
        role: 'assistant'
      });

      await get().fetchRecords();
      set({ isLoading: false, uploadProgress: 0 });
    } catch (error) {
      const errorMessage = (error as Error).message;
      set({ error: errorMessage, isLoading: false, uploadProgress: 0 });
      get().addMessage({
        content: `Error uploading records: ${errorMessage}`,
        role: 'assistant'
      });
    }
  },

  updateRecord: async (id, updates) => {
    set({ isLoading: true, error: null });
    try {
      const { error } = await supabase
        .from('dealer_forward_planning')
        .update(updates)
        .eq('id', id);

      if (error) throw error;

      get().addMessage({
        content: 'Record updated successfully.',
        role: 'assistant'
      });

      await get().fetchRecords();
      set({ isLoading: false });
    } catch (error) {
      const errorMessage = (error as Error).message;
      set({ error: errorMessage, isLoading: false });
      get().addMessage({
        content: `Error updating record: ${errorMessage}`,
        role: 'assistant'
      });
    }
  },

  deleteRecord: async (id) => {
    set({ isLoading: true, error: null });
    try {
      const { error } = await supabase
        .from('dealer_forward_planning')
        .delete()
        .eq('id', id);

      if (error) throw error;

      get().addMessage({
        content: 'Record deleted successfully.',
        role: 'assistant'
      });

      await get().fetchRecords();
      set({ isLoading: false });
    } catch (error) {
      const errorMessage = (error as Error).message;
      set({ error: errorMessage, isLoading: false });
      get().addMessage({
        content: `Error deleting record: ${errorMessage}`,
        role: 'assistant'
      });
    }
  },

  deleteAllRecords: async () => {
    set({ isLoading: true, error: null });
    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error('User not authenticated');

      const { error } = await supabase
        .from('dealer_forward_planning')
        .delete()
        .eq('uploaded_by', user.id);

      if (error) throw error;

      get().addMessage({
        content: 'All your records have been deleted.',
        role: 'assistant'
      });

      await get().fetchRecords();
      set({ isLoading: false });
    } catch (error) {
      const errorMessage = (error as Error).message;
      set({ error: errorMessage, isLoading: false });
      get().addMessage({
        content: `Error deleting records: ${errorMessage}`,
        role: 'assistant'
      });
    }
  },

  addMessage: (message) =>
    set((state) => ({
      messages: [
        ...state.messages,
        {
          ...message,
          id: crypto.randomUUID(),
          timestamp: new Date().toISOString(),
        },
      ],
    })),

  resetChat: () => set({ messages: [], isLoading: false, error: null }),
}));
