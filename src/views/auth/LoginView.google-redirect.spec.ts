/**
 * LoginView — what the user actually SEES after a Google redirect.
 *
 * The store-level contract is pinned in
 * `src/stores/auth.google-redirect.spec.ts`; this file pins the other half
 * of the reported bug: that a failed Google hydration reaches the screen,
 * and that a successful one navigates off the login page.
 *
 * The failure case is deliberately set up with the error ALREADY in the
 * store before mount. That is the real ordering — App.vue's onMounted
 * publishes it while this view is still a pending lazy chunk — and it is
 * precisely the ordering a change-only watcher misses.
 */
// @ts-nocheck — repo convention for spec files
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { createPinia, setActivePinia } from 'pinia';

import LoginView from './LoginView.vue';
import { useAuthStore } from '@/stores/auth';
import { i18n } from '@/lib/i18n';

const replace = vi.fn();

vi.mock('vue-router', () => ({
  useRouter: () => ({ replace, push: vi.fn() }),
  useRoute: () => ({ query: {} }),
}));

vi.mock('@/services/auth.service', () => ({
  AuthService: {
    health: vi.fn().mockResolvedValue(true),
    listSchools: vi.fn().mockResolvedValue([]),
    listRoles: vi.fn().mockResolvedValue([]),
    logout: vi.fn(),
  },
}));

vi.mock('@/services/me.service', () => ({
  MeService: { fetch: vi.fn().mockResolvedValue(null) },
}));

function mountLoginView() {
  return shallowMount(LoginView, {
    global: {
      plugins: [i18n],
      // FormCard is pure chrome; render its slot so the assertions can see
      // WHICH step body the view dispatched to.
      stubs: { FormCard: { template: '<div><slot /></div>' } },
    },
  });
}

describe('LoginView after a Google redirect', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  it('shows the failure instead of a silent, unchanged login form', async () => {
    const auth = useAuthStore();
    auth.error = 'Gagal memuat profil pengguna setelah masuk Google.';

    const wrapper = mountLoginView();
    await nextTick();

    expect(wrapper.html()).toContain('Gagal memuat profil pengguna');
    // …and the form is still there to retry with.
    expect(auth.step).toBe('login');
    expect(wrapper.html()).toContain('login-form');
  });

  it('surfaces an error raised after the view is already mounted', async () => {
    const auth = useAuthStore();
    const wrapper = mountLoginView();
    await nextTick();
    expect(wrapper.html()).not.toContain('toast-stub');

    auth.error = 'Akun Google Anda ditolak.';
    await nextTick();

    expect(wrapper.html()).toContain('Akun Google Anda ditolak.');
  });

  it('navigates to the dashboard when hydration completes', async () => {
    const auth = useAuthStore();
    mountLoginView();
    await nextTick();

    auth.step = 'done';
    await nextTick();

    expect(replace).toHaveBeenCalledWith('/');
  });

  it('does not navigate while the user is still on the credentials form', async () => {
    mountLoginView();
    await nextTick();

    expect(replace).not.toHaveBeenCalledWith('/');
  });
});
