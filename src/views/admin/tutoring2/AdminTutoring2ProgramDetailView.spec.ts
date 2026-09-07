/**
 * Vitest spec for AdminTutoring2ProgramDetailView — seat and score
 * counts that are ABSENT from the wire must not be rendered as zero.
 *
 * This view had no spec at all, which is how three fabricated numbers
 * lived here unnoticed:
 *
 *   • the "Kelompok" tile's "N siswa" suffix summed `seated_count ?? 0`
 *     across groups. `GET /learning-groups` (index) never emits that
 *     field, so the sum was always 0 and the suffix NEVER rendered.
 *   • each group card's subtitle read "0 / 12" for every group.
 *   • each assessment's subtitle read "0 nilai", and the "Lihat nilai"
 *     shortcut — gated on `(scores_count ?? 0) > 0` — never rendered at
 *     all, because `AssessmentController::index` runs no
 *     `withCount('scores')` either.
 *
 * The counterpart assertions ("a real 0 still reads 0") are what stop
 * the fix from lying in the opposite direction.
 */
// @ts-nocheck — mount stubs are structurally typed, not worth pinning
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2ProgramDetailView from './AdminTutoring2ProgramDetailView.vue';
import KpiStripCards from '@/components/feature/KpiStripCards.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    getProgram: vi.fn(),
    listPackages: vi.fn(),
    listGroups: vi.fn(),
    listAssessments: vi.fn(),
    createPackage: vi.fn(),
  },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { programId: 'pr-1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
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

const PROGRAM = {
  id: 'pr-1',
  name: 'Intensif UTBK',
  grade_level: '12',
  status: 'active',
  status_label: 'Aktif',
};

function makeGroup(overrides = {}) {
  return {
    id: 'gr-1',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    term_id: 'tm-1',
    term_name: 'Gelombang 1',
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    name: 'UTBK Pagi A',
    kind: 'group',
    capacity: 12,
    status: 'active',
    // No `seated_count` — the list endpoint does not send one.
    ...overrides,
  };
}

function makeAssessment(overrides = {}) {
  return {
    id: 'as-1',
    program_id: 'pr-1',
    title: 'Tryout 1',
    kind: 'tryout',
    kind_label: 'Tryout',
    assessment_date: '2026-09-01',
    max_score: 100,
    published_at: null,
    // No `scores_count` — `index` does not count scores.
    ...overrides,
  };
}

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
          common: { metaStudents: '{count} siswa' },
          admin: {
            programDetail: {
              kpiPackages: 'Paket',
              kpiGroups: 'Kelompok',
              kpiAssessments: 'Penilaian',
              scoresCount: '{count} nilai',
              kpiCountedSuffix: '{count} kelompok terdata',
              viewScores: 'Lihat nilai',
              noTutor: 'Belum ada tutor',
            },
          },
        },
      },
    },
  });
}

async function mountView({ groups = [], assessments = [] } = {}) {
  setActivePinia(createPinia());
  (TutoringBimbelService.getProgram as any).mockResolvedValue(PROGRAM);
  (TutoringBimbelService.listPackages as any).mockResolvedValue({ items: [] });
  (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: groups });
  (TutoringBimbelService.listAssessments as any).mockResolvedValue({ items: assessments });

  const w = mount(AdminTutoring2ProgramDetailView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        // KpiStripCards is deliberately NOT stubbed.
        BrandPageHeader: true,
        StatusBadge: true,
        NavIcon: true,
        AdminTutoring2GroupCreateSheet: true,
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** The "Kelompok" tile is the second of the three cards. */
const GROUPS_TILE = 1;

function kpiCards(w) {
  return w.findComponent(KpiStripCards).props('cards');
}

function bodyText(w) {
  return w.text().replace(/\s+/g, ' ');
}

describe('AdminTutoring2ProgramDetailView — seats absent vs zero', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders "— / 12" for a group whose seat count was never sent', async () => {
    const w = await mountView({ groups: [makeGroup()] });

    expect(bodyText(w)).toContain('— / 12');
    expect(bodyText(w)).not.toContain('0 / 12');
  });

  it('omits the "N siswa" suffix entirely when no group reported', async () => {
    const w = await mountView({ groups: [makeGroup(), makeGroup({ id: 'gr-2' })] });

    expect(kpiCards(w)[GROUPS_TILE].suffix).toBeUndefined();
  });

  it('THE INVARIANT: a group reporting zero seated still reads "0 / 12"', async () => {
    const w = await mountView({ groups: [makeGroup({ seated_count: 0 })] });

    expect(bodyText(w)).toContain('0 / 12');
    expect(bodyText(w)).not.toContain('— / 12');
    // Knowing the total is zero is not the same as not knowing it, so
    // the suffix is present and says so.
    expect(kpiCards(w)[GROUPS_TILE].suffix).toBe('0 siswa');
  });

  it('sums only the groups that reported, and shows the real total', async () => {
    const w = await mountView({
      groups: [
        makeGroup({ id: 'gr-1', seated_count: 6 }),
        makeGroup({ id: 'gr-2', seated_count: 2 }),
      ],
    });

    expect(kpiCards(w)[GROUPS_TILE].suffix).toBe('8 siswa');
    expect(bodyText(w)).toContain('6 / 12');
    expect(bodyText(w)).toContain('2 / 12');
  });

  // ── Partial coverage says so ──────────────────────────────────────
  // AdminTutoring2GroupsView already qualified its seat tiles this way;
  // this screen summed the same field and did not. On a mixed payload it
  // printed a subset total as a bare, authoritative number.
  it('names the counted subset when only some groups reported', async () => {
    const w = await mountView({
      groups: [
        makeGroup({ id: 'gr-1', seated_count: 6 }),
        makeGroup({ id: 'gr-2' }), // silent
      ],
    });

    expect(kpiCards(w)[GROUPS_TILE].suffix).toBe('6 siswa · 1 kelompok terdata');
  });

  it('drops the coverage note when every group reported', async () => {
    const w = await mountView({
      groups: [
        makeGroup({ id: 'gr-1', seated_count: 6 }),
        makeGroup({ id: 'gr-2', seated_count: 2 }),
      ],
    });

    expect(kpiCards(w)[GROUPS_TILE].suffix).toBe('8 siswa');
    expect(kpiCards(w)[GROUPS_TILE].suffix).not.toContain('terdata');
  });

  // ── An empty collection is a KNOWN zero ───────────────────────────
  // Over-correcting `?? 0` into "always — when nothing reported" hid a
  // number we actually hold: a program with no groups seats no students.
  it('a program with NO groups reports a real 0, not "unknown"', async () => {
    const w = await mountView({ groups: [] });

    expect(kpiCards(w)[GROUPS_TILE].suffix).toBe('0 siswa');
    expect(kpiCards(w)[GROUPS_TILE].suffix).not.toBeUndefined();
  });
});

describe('AdminTutoring2ProgramDetailView — assessment scores absent vs zero', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('does not claim "0 nilai" for an assessment whose count was never sent', async () => {
    const w = await mountView({ assessments: [makeAssessment()] });

    expect(bodyText(w)).not.toContain('0 nilai');
  });

  it('still offers the "Lihat nilai" shortcut when the count is unknown', async () => {
    // `(scores_count ?? 0) > 0` hid this button on every row forever.
    //
    // DELIBERATE CHOICE, not a side effect: because no row carries
    // `scores_count` today, "render when unknown" means the shortcut is
    // now on for every row where it used to be on for none. That is the
    // right trade here — it routes to the assessments LIST, a page that
    // exists and lists rows regardless, so an unknown count cannot
    // strand anyone on an empty screen. Hiding it instead would restore
    // the dead-button bug. Revisit only if the destination ever becomes
    // a per-assessment scores page that can be empty.
    const w = await mountView({ assessments: [makeAssessment()] });

    expect(bodyText(w)).toContain('Lihat nilai');
  });

  it('THE INVARIANT: a reported zero reads "0 nilai" and hides the shortcut', async () => {
    const w = await mountView({ assessments: [makeAssessment({ scores_count: 0 })] });

    expect(bodyText(w)).toContain('0 nilai');
    expect(bodyText(w)).not.toContain('Lihat nilai');
  });

  it('renders a reported positive count and keeps the shortcut', async () => {
    const w = await mountView({ assessments: [makeAssessment({ scores_count: 24 })] });

    expect(bodyText(w)).toContain('24 nilai');
    expect(bodyText(w)).toContain('Lihat nilai');
  });
});
