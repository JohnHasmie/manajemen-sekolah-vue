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

const authUser = { value: null as { name?: string } | null };
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ logout, get user() { return authUser.value; } }),
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push, back: vi.fn() }) }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

async function mountView(Component: unknown) {
  setActivePinia(createPinia());
  const w = mount(Component as never, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          // Real templates for the two keys under test — with empty
          // messages vue-i18n echoes the KEY and never interpolates, so
          // `{name}` would be unobservable and the assertion vacuous.
          messages: {
            id: {
              tutoring2: {
                parent: { profile: { subtitle: 'Wali · {name}' } },
                common: { roleParent: 'Wali' },
              },
            },
          },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        // Renders `meta`, because that is where the header puts the
        // signed-in user's name — a `true` stub swallows it and the
        // assertion below would pass against nothing.
        BrandPageHeader: {
          props: ['role', 'kicker', 'title', 'meta'],
          template: '<div data-testid="hdr">{{ title }} {{ meta }}</div>',
        },
        NavIcon: true,
        InitialsAvatar: true,
      },
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
    authUser.value = null;
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

describe('wali profile — whose name is on it', () => {
  beforeEach(() => {
    authUser.value = null;
  });

  it('shows the SIGNED-IN wali, not a hardcoded name', async () => {
    // The header was `const placeholderName = 'Bpk Anwar'`, so every
    // wali in every tenant was greeted by the same stranger.
    authUser.value = { name: 'Ibu Sari Rahmawati' };

    const w = await mountView(ParentProfile);

    expect(w.html()).toContain('Ibu Sari Rahmawati');
    expect(w.html()).not.toContain('Bpk Anwar');
  });

  it('falls back to the role label when the account has no name', async () => {
    // Not a person, and not a dangling "Wali · " either.
    authUser.value = { name: '   ' };

    const w = await mountView(ParentProfile);

    expect(w.html()).not.toContain('Bpk Anwar');
    // Reads "Wali · Wali" rather than a dangling "Wali · " — no name is
    // better than half a sentence, and far better than someone else's.
    expect(w.get('[data-testid="hdr"]').text()).toContain('Wali · Wali');
  });
});
