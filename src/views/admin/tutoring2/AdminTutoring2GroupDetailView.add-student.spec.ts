/**
 * Vitest spec for the "Tambah siswa" wiring on
 * AdminTutoring2GroupDetailView.
 *
 * The view's own header records that this page's predecessor shipped a
 * "+ Siswa" button with NO click handler — dead chrome, dropped rather
 * than re-shipped inert when the page was rebuilt. This file is what
 * keeps the replacement from regressing into the same thing:
 *
 *   • the button must OPEN something (a dead CTA passes no test that
 *     asserts the sheet mounted);
 *   • it must be ABSENT — not disabled — for an admin without
 *     `tutoring.enrollment.manage`, the key `EnrollmentController::store`
 *     authorizes. A present-and-failing button is the defect this repo
 *     keeps hitting;
 *   • a successful add must refresh the roster EXACTLY ONCE. The sheet
 *     emits `saved` and then `close`; wiring a reload onto both — or
 *     leaving `useDataRefresh`'s own watchers to double it, the trap
 *     `useDataRefresh` already owns for academic-year + locale — costs
 *     two round trips of five parallel requests each. Counting the
 *     service calls is the only way to see that from outside.
 */
// @ts-nocheck — mount stubs are structurally typed, not worth pinning
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2GroupDetailView from './AdminTutoring2GroupDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { ActivitiesService } from '@/services/tutoring2/activities';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    getGroup: vi.fn(),
    getGroupRoster: vi.fn(),
    listSessions: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/activities', () => ({
  ActivitiesService: { listByGroup: vi.fn() },
}));

vi.mock('@/services/tutoring2/leaderboard', () => ({
  TutoringLeaderboardService: { getGroup: vi.fn() },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { groupId: 'gr-1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {
    /* noop in tests */
  },
}));

/**
 * Ability the "Tambah siswa" CTA is gated on. Mutable so the "hidden
 * without the grant" case can flip it per test — the same shape
 * AdminTutoring2GroupsView.spec.ts uses.
 */
let grantedAbilities: string[] = ['tutoring.enrollment.manage'];

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (ability: string) => grantedAbilities.includes(ability),
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

const GROUP = {
  id: 'gr-1',
  program_id: 'pr-1',
  program_name: 'Intensif UTBK',
  name: 'UTBK Pagi A',
  kind: 'group',
  capacity: 12,
  status: 'active',
  seated_count: 3,
};

const ROSTER = [
  {
    id: 'en-1',
    student_id: 'st-1',
    student_name: 'Andi Wijaya',
    program_id: 'pr-1',
    learning_group_id: 'gr-1',
    billing_mode: 'prepaid',
    status: 'active',
  },
];

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    missingWarn: false,
    fallbackWarn: false,
    messages: {
      id: {
        tutoring2: {
          common: {
            loading: 'Memuat…',
            back: 'Kembali',
            student: 'Siswa',
            billingMode: 'Mode tagihan',
            remainingQuota: 'Sisa kuota',
            status: 'Status',
            noRoom: 'Tanpa ruang',
          },
          status: { active: 'Aktif', trial: 'Trial' },
          admin: {
            groupDetail: {
              kicker: 'Kelompok',
              notFound: 'Tidak ditemukan',
              notFoundDesc: '—',
              tutorPrefix: 'Tutor {name}',
              noTutor: 'Belum ada tutor',
              kpiStudents: 'Siswa',
              kpiCapacitySuffix: 'dari {capacity}',
              kpiSessions: 'Sesi',
              kpiSessionsDoneSuffix: '{count} selesai',
              kpiTasks: 'Tugas',
              kpiRanked: 'Peringkat',
              tab_students: 'Peserta',
              tab_sessions: 'Sesi',
              tab_tasks: 'Tugas',
              tab_leaderboard: 'Peringkat',
              emptyStudents: 'Belum ada peserta.',
              emptySessions: '—',
              emptyTasks: '—',
              emptyLeaderboard: '—',
              addStudentCta: '+ Tambah siswa',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  BrandPageHeader: { template: '<div><slot /></div>' },
  KpiStripCards: true,
  StatusBadge: true,
  NavIcon: true,
  AsyncView: {
    props: ['state'],
    template: '<div data-testid="async"><slot /></div>',
  },
  // Stubbed so the wiring is what is under test, not the form. Emits
  // are forwarded, so the spec can fire `saved` the way the real sheet
  // does after a successful POST.
  AdminTutoring2GroupAddStudentSheet: {
    props: ['group', 'roster'],
    emits: ['close', 'saved'],
    template: '<div data-testid="add-student-sheet"></div>',
  },
};

async function mountView(held = ['tutoring.enrollment.manage']) {
  grantedAbilities = held;
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2GroupDetailView, {
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const cta = (w) => w.find('[data-testid="group-detail-add-student"]');
const sheet = (w) => w.findComponent('[data-testid="add-student-sheet"]');

beforeEach(() => {
  vi.clearAllMocks();
  TutoringBimbelService.getGroup.mockResolvedValue(GROUP);
  TutoringBimbelService.getGroupRoster.mockResolvedValue({ items: ROSTER, pagination: undefined });
  TutoringBimbelService.listSessions.mockResolvedValue({ items: [], pagination: undefined });
  ActivitiesService.listByGroup.mockResolvedValue({ items: [], pagination: undefined });
  TutoringLeaderboardService.getGroup.mockResolvedValue({ items: [], generated_at: '' });
});

describe('AdminTutoring2GroupDetailView · "Tambah siswa" CTA', () => {
  it('renders the CTA for an admin holding tutoring.enrollment.manage', async () => {
    const w = await mountView();
    expect(cta(w).exists()).toBe(true);
  });

  it('opens the sheet — the button has a destination, unlike its dead predecessor', async () => {
    const w = await mountView();

    expect(sheet(w).exists()).toBe(false);
    await cta(w).trigger('click');
    await flushPromises();

    expect(sheet(w).exists()).toBe(true);
  });

  it('hands the sheet the group and the roster it already holds', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    expect(sheet(w).props('group')).toMatchObject({ id: 'gr-1', program_id: 'pr-1' });
    // Passed, not re-fetched — the exclusion rule reads it.
    expect(sheet(w).props('roster')).toHaveLength(1);
  });

  it('is ABSENT, not disabled, without the ability', async () => {
    const w = await mountView(['tutoring.group.view']);

    expect(cta(w).exists()).toBe(false);
    // And nothing else offers the surface either.
    expect(sheet(w).exists()).toBe(false);
  });

  it('does not mount the sheet if the ability is lost while it is open', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();
    expect(sheet(w).exists()).toBe(true);

    grantedAbilities = [];
    await w.vm.$forceUpdate();
    await flushPromises();

    expect(sheet(w).exists()).toBe(false);
  });
});

describe('AdminTutoring2GroupDetailView · refresh after add', () => {
  it('refreshes the participant list EXACTLY ONCE on saved', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    // One call from the initial mount, and nothing since.
    expect(TutoringBimbelService.getGroupRoster).toHaveBeenCalledTimes(1);

    sheet(w).vm.$emit('saved', { id: 'en-new' });
    await flushPromises();

    // Exactly one MORE — not two, which is what wiring a reload onto
    // `close` as well as `saved` would produce.
    expect(TutoringBimbelService.getGroupRoster).toHaveBeenCalledTimes(2);
  });

  it('stays at one refresh when the sheet closes right after saving', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    // The real sheet emits `saved` then `close`, in that order.
    sheet(w).vm.$emit('saved', { id: 'en-new' });
    sheet(w).vm.$emit('close');
    await flushPromises();

    expect(TutoringBimbelService.getGroupRoster).toHaveBeenCalledTimes(2);
    expect(sheet(w).exists()).toBe(false);
  });

  it('does not refresh when the sheet is merely cancelled', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    sheet(w).vm.$emit('close');
    await flushPromises();

    expect(TutoringBimbelService.getGroupRoster).toHaveBeenCalledTimes(1);
  });
});
