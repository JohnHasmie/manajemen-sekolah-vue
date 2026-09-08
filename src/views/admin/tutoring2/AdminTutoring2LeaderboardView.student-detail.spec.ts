/**
 * The Peringkat row drill-in, admin side (Luay, 2026-09 — "Pada website
 * belum menampilkan detail nilai siswa").
 *
 * Before this change BOTH row sets carried `hover:bg-slate-50` and no
 * `@click` at all: the row lit up under the cursor and then did nothing,
 * advertising an affordance it did not have. The tests below pin the
 * affordance and the gate together, because shipping one without the
 * other is how that mismatch came back:
 *
 *   • a tappable row navigates to THAT student's scores, carrying the
 *     name the board already rendered;
 *   • an ungated or id-less row is inert AND paints no hover/pointer.
 *
 * The gate is deliberately two conditions, copied from the Flutter
 * board's `_openStudent`: the reader must hold `tutoring.score.view`,
 * AND the row must carry a `student_id`. An empty id would build
 * `/students//scores` — a malformed URL that resolves to no route.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2LeaderboardView from './AdminTutoring2LeaderboardView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringLeaderboardService } from '@/services/tutoring2/leaderboard';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listGroups: vi.fn(),
    listPrograms: vi.fn(),
    listAssessments: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/leaderboard', () => ({
  TutoringLeaderboardService: { getGroup: vi.fn(), getProgram: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

const push = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push }) }));

/** Swapped per-test to move the ability gate. */
let heldAbilities: string[] = [];
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({
    hasAbility: (perm: string) => heldAbilities.includes(perm),
  }),
}));

const GROUPS = [{ id: 'gr-1', program_id: 'pr-1', name: 'UTBK Pagi A' }];
const PROGRAMS = [{ id: 'pr-1', name: 'Intensif UTBK' }];

/**
 * Ranks 1..3 land on the podium, 4..N in the tail table — so this
 * fixture exercises both row sets in one mount.
 *
 * `en-5` is the id-less row: BE-21 aggregates from `bimbel_enrollments`,
 * and a row whose student join came back empty carries `student_id: ''`.
 */
const ROWS = [
  { enrollment_id: 'en-1', student_id: 'st-1', student_name: 'Anaya Putri', student_number: 'BM-001', avg_score: 92.5, assessments_taken: 4, rank: 1 },
  { enrollment_id: 'en-2', student_id: 'st-2', student_name: 'Budi Santoso', student_number: 'BM-002', avg_score: 81, assessments_taken: 4, rank: 2 },
  { enrollment_id: 'en-3', student_id: 'st-3', student_name: 'Citra Dewi', student_number: 'BM-003', avg_score: 77, assessments_taken: 3, rank: 3 },
  { enrollment_id: 'en-4', student_id: 'st-4', student_name: 'Dimas Yoga', student_number: 'BM-004', avg_score: 70, assessments_taken: 3, rank: 4 },
  { enrollment_id: 'en-5', student_id: '', student_name: 'Tanpa Id', student_number: 'BM-005', avg_score: 65, assessments_taken: 2, rank: 5 },
];

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: {} },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2LeaderboardView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        AppFilterChip: { template: '<button></button>' },
        AsyncView: {
          props: ['state'],
          template: '<div :data-status="state?.status"><slot /></div>',
        },
        FilterFacetPickerModal: true,
      },
    },
  });
  await flushPromises();
  return w;
}

/** Rank 4..N rows the view marked as openable / inert. */
const openableRows = (w) => w.findAll('[data-testid="row-openable"]');
const inertRows = (w) => w.findAll('[data-testid="row-inert"]');
const openablePodium = (w) => w.findAll('[data-testid="podium-openable"]');
const inertPodium = (w) => w.findAll('[data-testid="podium-inert"]');

describe('admin Peringkat → one student’s scores', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    heldAbilities = ['tutoring.score.view'];
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
    (TutoringBimbelService.listAssessments as any).mockResolvedValue({ items: [] });
    (TutoringLeaderboardService.getGroup as any).mockResolvedValue({ items: ROWS });
    (TutoringLeaderboardService.getProgram as any).mockResolvedValue({ items: ROWS });
  });

  it('opens THAT student’s scores from a tail row', async () => {
    const w = await mountView();
    await openableRows(w)[0].trigger('click');

    expect(push).toHaveBeenCalledWith({
      name: 'admin.tutoring2.student-scores',
      params: { studentId: 'st-4' },
      query: { name: 'Dimas Yoga' },
    });
  });

  it('makes the podium tappable too — its three names are students', async () => {
    const w = await mountView();
    expect(openablePodium(w)).toHaveLength(3);

    await openablePodium(w)[0].trigger('click');
    expect(push).toHaveBeenCalledWith({
      name: 'admin.tutoring2.student-scores',
      params: { studentId: 'st-1' },
      query: { name: 'Anaya Putri' },
    });
  });

  it('carries the name the board already rendered, so the header can title itself', async () => {
    // The destination cannot look the name up: GET /students/{id}
    // authorizes `tutoring.student.view`, which a tutor lacks. The board
    // hands it over instead.
    const w = await mountView();
    await openablePodium(w)[1].trigger('click');
    expect(push.mock.calls[0][0].query).toEqual({ name: 'Budi Santoso' });
  });

  it('omits ?name= entirely when the board itself has no name', async () => {
    (TutoringLeaderboardService.getGroup as any).mockResolvedValue({
      items: [{ ...ROWS[0], student_name: '   ' }],
    });
    const w = await mountView();
    await openablePodium(w)[0].trigger('click');
    // Not `{ name: '' }` — the destination renders its own placeholder
    // rather than an empty title.
    expect(push.mock.calls[0][0].query).toBeUndefined();
  });

  it('a reader WITHOUT tutoring.score.view gets no tap and no hover', async () => {
    // Holding the board's own key is not enough: the board says who
    // ranks where, the drill-in says what they scored.
    heldAbilities = ['tutoring.leaderboard.view'];
    const w = await mountView();

    expect(openableRows(w)).toHaveLength(0);
    expect(openablePodium(w)).toHaveLength(0);
    expect(inertPodium(w)).toHaveLength(3);
    expect(inertRows(w)).toHaveLength(2);

    await inertRows(w)[0].trigger('click');
    expect(push).not.toHaveBeenCalled();
  });

  it('a row the server sent with no student_id is not tappable', async () => {
    const w = await mountView();
    // Rank 4 has an id, rank 5 does not — same ability, different rows.
    expect(openableRows(w)).toHaveLength(1);
    expect(inertRows(w)).toHaveLength(1);

    await inertRows(w)[0].trigger('click');
    expect(push).not.toHaveBeenCalled();
  });

  it('paints no hover affordance where the tap is not offered', async () => {
    const w = await mountView();
    // The id-less row is the one inert row on this board.
    const inert = inertRows(w)[0];
    expect(inert.classes()).not.toContain('hover:bg-slate-50');
    expect(inert.classes()).not.toContain('cursor-pointer');
    // …while a real one keeps both.
    const open = openableRows(w)[0];
    expect(open.classes()).toContain('hover:bg-slate-50');
    expect(open.classes()).toContain('cursor-pointer');
  });

  it('announces an openable row to assistive tech, and an inert one not at all', async () => {
    const w = await mountView();
    expect(openableRows(w)[0].attributes('role')).toBe('button');
    expect(openableRows(w)[0].attributes('tabindex')).toBe('0');
    expect(inertRows(w)[0].attributes('role')).toBeUndefined();
    expect(inertRows(w)[0].attributes('tabindex')).toBeUndefined();
  });

  it('opens on Enter as well as on click', async () => {
    const w = await mountView();
    await openableRows(w)[0].trigger('keydown.enter');
    expect(push).toHaveBeenCalledWith({
      name: 'admin.tutoring2.student-scores',
      params: { studentId: 'st-4' },
      query: { name: 'Dimas Yoga' },
    });
  });
});
