import { create } from 'zustand';
import { UserStore } from '../types';
import { useEtaTrackingStore } from './etaTrackingStore';
import { useStockAvailabilityStore } from './stockAvailabilityStore';
import { usePartsEquivalenceStore } from './partsEquivalenceStore';

export const useUserStore = create<UserStore>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
  logout: () => {
    // Réinitialiser l'historique de recherche de tous les modules
    useEtaTrackingStore.getState().resetChat();
    useStockAvailabilityStore.getState().resetChat();
    usePartsEquivalenceStore.getState().resetChat();
    
    // Réinitialiser l'utilisateur
    set({ user: null });
  },
}));