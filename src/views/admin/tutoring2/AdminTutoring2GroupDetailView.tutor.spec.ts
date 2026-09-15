/**
 * Vitest spec for the "Ubah tutor" wiring on
 * AdminTutoring2GroupDetailView.
 *
 * The view's own header records that its predecessor shipped an "Ubah"
 * button with NO click handler — dead chrome, dropped rather than
 * re-shipped inert when the page was rebuilt. This file is what keeps
 * its replacement from becoming the same thing:
 *
 *   • the button must OPEN something, and be handed the group it is
 *     about (the sheet seeds its picker from `tutor_id` and PUTs to
 *     `id`, so a sheet without the group could do neither);
 *   • it must be ABSENT — not disabled — for an admin without
 *     `tutoring.group.manage`, the key `LearningGroupController::update`
 *     authorizes. That is a DIFFERENT key from the
 *     `tutoring.enrollment.manage` behind "Tambah siswa" and from the
 *     `tutoring.group.view` that lets the page be read at all, so
 *     holding one says nothing about the others;
 *   • a successful assignment must refresh EXACTLY ONCE, and it must
 *     refresh rather than patch: the header meta reads `tutor_name`,
 *     which `LearningGroupResource` only emits when the relation is
 *     loaded — and `UpdateLearningGroupAction` returns `$group->fresh()`,
 *     which has no relations loaded. Only `getGroup` (whose controller
 *     eager-loads `tutor:id,name`) can put the new tutor's NAME in the
 *     header; taking the PUT's body at face value would leave the page
 *     reading "Belum ada tutor" about a group that just got one.
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

/** Mutable so the without-the-grant case can flip it per test. */
let grantedAbilities: string[] = ['tutoring.group.manage'];

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
  tutor_id: 'tu-1',
  tutor_name: 'Rina Kartika',
};

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
          status: { active: 'Aktif' },
          admin: {
            groupDetail: {
              kicker: 'Kelompok',
              notFound: 'Tidak ditemukan',
              notFoundDesc: '—',
              tutorPrefix: 'Tutor: {name}',
              noTutor: 'Belum ada tutor',
              kpiStudents: 'Peserta',
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
              editTutorCta: 'Ubah tutor',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  // `meta` is rendered here (the sibling spec's stub drops it) because
  // the tutor's NAME lives in that string — it is the only place on
  // the page that shows who teaches the group, so asserting the
  // refresh landed means asserting on this.
  BrandPageHeader: {
    props: ['role', 'kicker', 'title', 'meta'],
    template:
      '<div><span data-testid="header-meta">{{ meta }}</span><slot /></div>',
  },
  KpiStripCards: true,
  StatusBadge: true,
  NavIcon: true,
  AsyncView: {
    props: ['state'],
    template: '<div data-testid="async"><slot /></div>',
  },
  AdminTutoring2GroupAddStudentSheet: {
    props: ['group', 'roster'],
    emits: ['close', 'saved'],
    template: '<div data-testid="add-student-sheet"></div>',
  },
  // Stubbed so the WIRING is what is under test, not the form — the
  // form's own payload is covered by
  // AdminTutoring2GroupTutorSheet.spec.ts. Emits are forwarded so the
  // spec can fire `saved` the way the real sheet does after a PUT.
  AdminTutoring2GroupTutorSheet: {
    props: ['group'],
    emits: ['close', 'saved'],
    template: '<div data-testid="tutor-sheet"></div>',
  },
};

async function mountView(held = ['tutoring.group.manage']) {
  grantedAbilities = held;
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2GroupDetailView, {
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const cta = (w) => w.find('[data-testid="group-detail-edit-tutor"]');
const sheet = (w) => w.findComponent('[data-testid="tutor-sheet"]');

beforeEach(() => {
  vi.clearAllMocks();
  TutoringBimbelService.getGroup.mockResolvedValue(GROUP);
  TutoringBimbelService.getGroupRoster.mockResolvedValue({ items: [], pagination: undefined });
  TutoringBimbelService.listSessions.mockResolvedValue({ items: [], pagination: undefined });
  ActivitiesService.listByGroup.mockResolvedValue({ items: [], pagination: undefined });
  TutoringLeaderboardService.getGroup.mockResolvedValue({ items: [], generated_at: '' });
});

describe('AdminTutoring2GroupDetailView · "Ubah tutor" CTA', () => {
  it('renders the CTA for an admin holding tutoring.group.manage', async () => {
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

  it('hands the sheet the group it already holds', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    expect(sheet(w).props('group')).toMatchObject({
      id: 'gr-1',
      tutor_id: 'tu-1',
      tutor_name: 'Rina Kartika',
    });
  });

  it('is ABSENT, not disabled, without the ability', async () => {
    const w = await mountView(['tutoring.group.view', 'tutoring.enrollment.manage']);

    expect(cta(w).exists()).toBe(false);
    expect(sheet(w).exists()).toBe(false);
  });

  it('does not borrow the enrollment grant — the two keys are independent', async () => {
    const w = await mountView(['tutoring.enrollment.manage']);

    expect(cta(w).exists()).toBe(false);
    // The sibling CTA, which DOES hold its key, still renders — proving
    // the gate above is about `tutoring.group.manage` and not about the
    // page being ability-less.
    expect(w.find('[data-testid="group-detail-add-student"]').exists()).toBe(true);
  });
});

describe('AdminTutoring2GroupDetailView · refresh after assigning', () => {
  it('refetches the group EXACTLY ONCE on saved, so the header shows the new tutor name', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.getGroup).toHaveBeenCalledTimes(1);

    TutoringBimbelService.getGroup.mockResolvedValue({
      ...GROUP,
      tutor_id: 'tu-2',
      tutor_name: 'Bayu Pratama',
    });
    sheet(w).vm.$emit('saved', { ...GROUP, tutor_id: 'tu-2' });
    await flushPromises();

    expect(TutoringBimbelService.getGroup).toHaveBeenCalledTimes(2);
    expect(w.find('[data-testid="header-meta"]').text()).toContain('Bayu Pratama');
  });

  it('stays at one refresh when the sheet closes right after saving', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    sheet(w).vm.$emit('saved', { ...GROUP, tutor_id: 'tu-2' });
    sheet(w).vm.$emit('close');
    await flushPromises();

    expect(TutoringBimbelService.getGroup).toHaveBeenCalledTimes(2);
    expect(sheet(w).exists()).toBe(false);
  });

  it('does not refresh when the sheet is merely cancelled', async () => {
    const w = await mountView();
    await cta(w).trigger('click');
    await flushPromises();

    sheet(w).vm.$emit('close');
    await flushPromises();

    expect(TutoringBimbelService.getGroup).toHaveBeenCalledTimes(1);
  });
});
