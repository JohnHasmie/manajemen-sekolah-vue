/**
 * Vitest contract spec for AdminTutoring2TutorsView's "+ Undang tutor"
 * CTA.
 *
 * Written while auditing three prod reports of "tombol diklik tidak
 * terjadi apa-apa" on the bimbel admin. This button was suspected of
 * being the third one, on the theory that `openInvite` early-returns
 * when `canManage` is false. It does not reach the user that way: the
 * template also carries `v-if="canManage"`, so a caller without
 * `tutoring.tutor.manage` never sees the button at all — the two tests
 * below pin both halves of that, so neither can be dropped silently.
 *
 * The guard inside `openInvite` is therefore unreachable defence in
 * depth. It used to `return` in silence, which would have turned "the
 * day someone drops the v-if" into exactly the report being chased, so
 * it now explains itself. The last test pins that too.
 *
 * `hasAbility` resolves against the /me snapshot scoped by the active
 * role — never `roles[].permission_keys` — which the mock below mirrors.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2TutorsView from './AdminTutoring2TutorsView.vue';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn(), invite: vi.fn() },
}));

const routerPush = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push: routerPush }) }));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

/** Abilities the /me snapshot reports for the ACTIVE role. */
let grantedAbilities: string[] = ['tutoring.tutor.view', 'tutoring.tutor.manage'];

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({
    hasAbility: (ability: string) => grantedAbilities.includes(ability),
  }),
}));

const TUTORS = [
  { id: 'tu-1', user_id: 'us-1', name: 'Pak Rahmat', email: 'rahmat@example.com', is_active: true, active_group_count: 2 },
];

const NO_PERMISSION = 'Anda tidak punya izin untuk mengundang tutor.';

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', status: 'Status', name: 'Nama', group: 'Kelompok' },
          admin: {
            tutors: { inviteCta: 'Undang tutor' },
            tutorInvite: {
              title: 'Undang tutor',
              subtitle: 'Kirim undangan lewat email.',
              emailLabel: 'Email',
              nameLabel: 'Nama',
              nameHint: 'Opsional.',
              phoneLabel: 'Telepon',
              rateLabel: 'Tarif awal',
              submit: 'Kirim undangan',
              saving: 'Mengirim…',
              errorGeneric: 'Gagal mengundang tutor.',
              noPermission: NO_PERMISSION,
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2TutorsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: true,
        AppFilterChip: true,
        Toast: { props: ['message', 'tone'], template: '<div data-testid="toast">{{ message }}</div>' },
        AsyncView: {
          props: ['state'],
          template: '<div><slot :data="state?.data ?? []" /></div>',
        },
        // Modal teleports to body and would escape the wrapper.
        Modal: {
          props: ['title', 'subtitle', 'size', 'testid'],
          template: '<div :data-testid="testid || \'modal\'"><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

const ctaOf = (w) => w.find('[data-testid="tutors-invite-cta"]');
const modalOf = (w) => w.find('[data-testid="modal"]');

describe('AdminTutoring2TutorsView "+ Undang tutor" CTA', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantedAbilities = ['tutoring.tutor.view', 'tutoring.tutor.manage'];
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS, pagination: undefined });
  });

  it('opens the invite dialog for an admin who holds tutoring.tutor.manage', async () => {
    const w = await mountView();
    expect(ctaOf(w).exists()).toBe(true);
    expect(modalOf(w).exists()).toBe(false);

    await ctaOf(w).trigger('click');

    // This is the half the prod report was blamed on. It works: an
    // admin with the grant gets a dialog, not a dead click.
    expect(modalOf(w).exists()).toBe(true);
    expect(modalOf(w).find('input[type="email"]').exists()).toBe(true);
  });

  it('hides the CTA when the admin lacks tutoring.tutor.manage', async () => {
    grantedAbilities = ['tutoring.tutor.view'];

    const w = await mountView();

    // Hidden, not inert — so "renders but does nothing" is impossible
    // here regardless of what the ability resolves to.
    expect(ctaOf(w).exists()).toBe(false);
  });

  it('explains itself instead of returning in silence if the guard is ever reached', async () => {
    grantedAbilities = ['tutoring.tutor.view'];
    const w = await mountView();

    // Reach past the (correctly) hidden button to the handler itself,
    // standing in for a future template that drops the `v-if`.
    w.vm.openInvite();
    await flushPromises();

    expect(w.find('[data-testid="toast"]').text()).toBe(NO_PERMISSION);
    expect(modalOf(w).exists()).toBe(false);
  });
});
