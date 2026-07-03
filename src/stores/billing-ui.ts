import { defineStore } from 'pinia';
import type { SeatHardCapError } from '@/types/subscription-billing';

/**
 * Cross-cutting UI state for the billing/seat-cap surfaces.
 *
 * Populated by the http.ts 402 interceptor whenever a create / import
 * request trips the hard cap. A single modal in App.vue watches this
 * store and pops when non-null, offering the top-up CTA. Cleared by
 * the modal (dismiss or navigate).
 */
export const useBillingUiStore = defineStore('billing-ui', {
  state: () => ({
    hardCapError: null as SeatHardCapError | null,
  }),
  actions: {
    reportHardCap(payload: SeatHardCapError) {
      this.hardCapError = payload;
    },
    dismiss() {
      this.hardCapError = null;
    },
  },
});
