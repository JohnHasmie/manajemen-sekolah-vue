/**
 * Logout must actually log out.
 *
 * Both the wali and siswa profile screens shipped with Keluar bound to
 * `toast.info(...)` and nothing else. The user saw a confirmation and
 * stayed signed in — on a family phone or a bimbel front-desk tablet,
 * the next person had their account.
 *
 * A test that only checked "the button exists" would have passed the
 * whole time. These assert the session teardown, and that it happens
 * even when the server call fails, because that is the case where a
 * naive implementation silently leaves someone logged in.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentProfile from './ParentTutoring2ProfileView.vue';
import StudentProfile from '../../student/tutoring2/StudentTutoring2ProfileView.vue';

const logout = vi.fn();
const push = vi.fn();

vi.mock('@/stores/auth', () => ({ useAuthStore: () => ({ logout }) }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push, back: vi.fn() }) }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

async function mountView(Component: unknown) {
  setActivePinia(createPinia());
  const w = mount(Component as never, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages: { id: {} }, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: { BrandPageHeader: true, NavIcon: true, InitialsAvatar: true },
    },
  });
  await flushPromises();
  return w;
}

/** Keluar is the last card in the grid on both screens. */
async function tapLogout(w: Awaited<ReturnType<typeof mountView>>) {
  const cards = w.findAll('button, [role="button"]');
  await cards[cards.length - 1].trigger('click');
  await flushPromises();
}

describe.each([
  ['wali', ParentProfile],
  ['siswa', StudentProfile],
])('%s profile — Keluar', (_role, Component) => {
  beforeEach(() => {
    logout.mockReset().mockResolvedValue(undefined);
    push.mockReset();
  });

  it('ends the session and returns to login', async () => {
    const w = await mountView(Component);
    await tapLogout(w);

    expect(logout).toHaveBeenCalledTimes(1);
    expect(push).toHaveBeenCalledWith({ name: 'login' });
  });

  it('still leaves and redirects when the server call fails', async () => {
    // An expired token 401s on the way out. Treating that as a failure
    // would strand someone signed in on a device they meant to leave.
    logout.mockRejectedValue(new Error('401'));

    const w = await mountView(Component);
    await tapLogout(w);

    expect(logout).toHaveBeenCalledTimes(1);
    expect(push).toHaveBeenCalledWith({ name: 'login' });
  });
});
