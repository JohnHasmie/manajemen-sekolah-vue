/**
 * useSubscription — global subscription-status composable.
 *
 * Drives:
 *   - The "Berlangganan" chip in the AppShell topbar (visible only when
 *     the active tenant is NOT on an active paid subscription).
 *   - Any other surface that needs to know if the current tenant is
 *     still in demo/expired state.
 *
 * Shared module-level state so mounting the shell + the subscribe page
 * simultaneously never fires two round-trips. `refresh()` re-fetches
 * on demand (e.g. after a successful subscribe).
 */
import { computed, ref } from 'vue';
import { SubscriptionBillingService } from '@/services/billing.service';
import { useAuthStore } from '@/stores/auth';
import type { MySubscription } from '@/types/subscription-billing';

const subscription = ref<MySubscription | null>(null);
const loading = ref(false);
let inflight: Promise<void> | null = null;

async function fetchOnce(): Promise<void> {
  if (inflight) return inflight;
  loading.value = true;
  inflight = (async () => {
    try {
      subscription.value = await SubscriptionBillingService.getMySubscription();
    } catch {
      // Fail-open: treat as no subscription so the chip stays visible
      // and the user can subscribe. Never break the shell over this.
      subscription.value = {
        has_subscription: false,
        is_active: false,
        status: 'demo',
        period: null,
        expires_at: null,
        tenant_id: null,
        is_demo: false,
      };
    } finally {
      loading.value = false;
      inflight = null;
    }
  })();
  return inflight;
}

export function useSubscription() {
  const auth = useAuthStore();

  /**
   * True when the topbar chip should be visible — the user is signed
   * in as a tenant ADMIN AND their tenant has no active paid
   * subscription. Wali/guru/staf never see it: only the school admin
   * (kepala sekolah / owner) has the standing to activate a paid
   * subscription; a parent seeing a "Berlangganan" CTA on a school
   * they don't own is confusing UX and offers them nothing they can
   * act on. Super admins never see it either (they operate on the
   * platform, not a tenant subscription).
   */
  const shouldPromptSubscribe = computed<boolean>(() => {
    if (!auth.isAuthenticated) return false;
    if (auth.isSuperAdmin) return false;
    if (auth.activeRole !== 'admin') return false;
    const sub = subscription.value;
    // Before the fetch resolves, keep the chip hidden — we don't want
    // to flash it on for authenticated-and-already-paying users. It
    // will appear once the /me/subscription call resolves.
    if (!sub) return false;
    return !sub.is_active;
  });

  /**
   * True when the active tenant is a demo school. Demo-only surfaces
   * (e.g. the "Reset data demo" settings tile) gate on this so they
   * never render for a real, paying tenant. Stays false until the
   * fetch resolves, so we never flash a demo-only control onto a real
   * tenant during load.
   */
  const isDemo = computed<boolean>(() => subscription.value?.is_demo === true);

  /**
   * No-op the fetch entirely when the caller isn't a tenant admin.
   * Wali/guru/staf sessions never render the chip, so hitting
   * `/me/subscription` for them is pure waste. Super admins likewise
   * don't have a tenant subscription to fetch.
   */
  async function ensureLoaded(): Promise<void> {
    if (!auth.isAuthenticated) return;
    if (auth.isSuperAdmin) return;
    if (auth.activeRole !== 'admin') return;
    await fetchOnce();
  }

  return {
    subscription,
    loading,
    shouldPromptSubscribe,
    isDemo,
    ensureLoaded,
    refresh: () => {
      inflight = null;
      subscription.value = null;
      return ensureLoaded();
    },
  };
}
