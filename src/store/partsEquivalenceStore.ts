import { create } from 'zustand';
import { Message } from '../types';

interface PartsEquivalenceStore {
  messages: Message[];
  isLoading: boolean;
  unmatchedTerms: string[];
  addMessage: (message: Omit<Message, 'id' | 'timestamp'>) => void;
  setIsLoading: (loading: boolean) => void;
  setUnmatchedTerms: (terms: string[]) => void;
  resetChat: () => void;
}

export const usePartsEquivalenceStore = create<PartsEquivalenceStore>((set) => ({
  messages: [],
  isLoading: false,
  unmatchedTerms: [],
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
  setIsLoading: (loading) => set({ isLoading: loading }),
  setUnmatchedTerms: (terms) => set({ unmatchedTerms: terms }),
  resetChat: () => set({ messages: [], isLoading: false, unmatchedTerms: [] }),
}));