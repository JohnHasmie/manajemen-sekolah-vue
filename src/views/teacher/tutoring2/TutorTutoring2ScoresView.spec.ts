/**
 * TutorTutoring2ScoresView — the tutor input-skor screen, end to end.
 *
 * ── The mock is a little server, not a stub that says yes ───────────
 *
 * `upsertScores` here APPLIES what it is sent to a stored row set and
 * restamps `marked_at`, exactly as `UpsertScoresAction` does
 * (`'marked_at' => now()` inside the values array of `updateOrCreate`,
 * so a re-mark is restamped too). `listScores` then serves that store.
 *
 * A `mockResolvedValue` ignoring its argument would make every save
 * test vacuous: "saving works" would pass for a screen that posted an
 * empty array, the wrong enrollment, or a stale score. Here the POST
 * payload is recorded and asserted, and the reload that follows reads
 * back what the save actually wrote.
 *
 * ── Why the entry list is NOT stubbed ───────────────────────────────
 *
 * The thing under test is the round trip: edit → Save enabled → POST →
 * confirmation → reload → marker shows the new time → Save quiet again.
 * Stubbing the list would leave only the half of that the view owns.
 *
 * The clock is pinned with `vi.setSystemTime`, the zone by
 * `vitest.config.ts` (Asia/Jakarta), so the restamped time renders as a
 * fixed string instead of whatever the machine happened to say.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ScoresView from './TutorTutoring2ScoresView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { BimbelAssessment } from '@/services/tutoring-bimbel.service';
import type { TutoringScoreRow } from '@/types/tutoring-bimbel';

const ID = JSON.parse(
  readFileSync(join(process.cwd(), 'src', 'locales', 'id.json'), 'utf8'),
);

const { push, routeState, toastSpies } = vi.hoisted(() => ({
  push: vi.fn(),
  routeState: { id: 'as-1' },
  toastSpies: { success: vi.fn(), error: vi.fn(), info: vi.fn() },
}));

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listScores: vi.fn(),
    getAssessment: vi.fn(),
    upsertScores: vi.fn(),
  },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push, replace: push }),
  useRoute: () => ({ params: { id: routeState.id }, query: {} }),
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ ...toastSpies, show: vi.fn(), undoable: vi.fn(), dismiss: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

const ASSESSMENT: BimbelAssessment = {
  id: 'as-1',
  program_id: 'pr-1',
  title: 'Try Out 1',
  kind: 'tryout',
  max_score: 100,
  kkm: 75,
};

/** Seeded server state: one scored row, one never scored. */
function seedRows(): TutoringScoreRow[] {
  return [
    {
      enrollment_id: 'en-scored',
      student_id: 'st-1',
      student_name: 'Nadia Putri',
      student_number: '2026-001',
      score: 80,
      notes: null,
      marked_at: '2026-09-09T14:30:00+07:00',
    },
    {
      enrollment_id: 'en-blank',
      student_id: 'st-2',
      student_name: 'Salsa Lestari',
      student_number: '2026-002',
      score: null,
      notes: null,
      marked_at: null,
    },
  ];
}

/** Every payload `upsertScores` was called with, in order. */
let posted: unknown[][] = [];
let store: TutoringScoreRow[] = [];

const stubs = {
  BrandPageHeader: true,
  Button: { template: '<button v-bind="$attrs"><slot /></button>' },
  AsyncView: {
    props: ['state'],
    template:
      '<div data-testid="async" :data-status="state?.status">' +
      "<slot v-if=\"state?.status === 'content' || state?.status === 'empty'\" />" +
      '</div>',
  },
};

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(ScoresView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: ID },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs,
    },
  });
  await flushPromises();
  await flushPromises();
  return w;
}

const at = (w, id) => w.find(`[data-testid="${id}"]`);
const saveBtn = (w) => w.find('[data-testid="score-save"]');
const isDisabled = (w) => saveBtn(w).attributes('disabled') !== undefined;

async function type(w, enrollmentId, value) {
  const box = at(w, `score-input-${enrollmentId}`);
  box.element.value = value;
  await box.trigger('input');
}

beforeAll(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-09-15T09:00:00+07:00'));
});
afterAll(() => {
  vi.useRealTimers();
});

beforeEach(() => {
  vi.clearAllMocks();
  posted = [];
  store = seedRows();

  vi.mocked(TutoringBimbelService.getAssessment).mockImplementation(async (id) => {
    if (id !== ASSESSMENT.id) throw new Error('Request failed with status code 404');
    return ASSESSMENT;
  });
  vi.mocked(TutoringBimbelService.listScores).mockImplementation(async (id) => {
    if (id !== ASSESSMENT.id) throw new Error('Request failed with status code 404');
    return { items: store.map((r) => ({ ...r })), pagination: undefined };
  });
  vi.mocked(TutoringBimbelService.upsertScores).mockImplementation(async (id, rows) => {
    if (id !== ASSESSMENT.id) throw new Error('Request failed with status code 404');
    posted.push(rows);
    // What the backend does: apply, and restamp marked_at on every row
    // it was handed — first mark and re-mark alike.
    const now = new Date().toISOString();
    for (const sent of rows) {
      const target = store.find((r) => r.enrollment_id === sent.enrollment_id);
      if (target) {
        target.score = sent.score;
        target.notes = sent.notes ?? null;
        target.marked_at = now;
      }
    }
    return { items: [], pagination: undefined };
  });
});

describe('TutorTutoring2ScoresView — loading', () => {
  it('asks for the assessment named by the route, rows and meta together', async () => {
    await mountView();
    expect(TutoringBimbelService.listScores).toHaveBeenCalledWith('as-1');
    expect(TutoringBimbelService.getAssessment).toHaveBeenCalledWith('as-1');
  });

  it('shows the server-side marker and its local time on the scored row only', async () => {
    const w = await mountView();
    expect(at(w, 'score-time-en-scored').text()).toContain('9 Sep 2026, 14.30');
    expect(at(w, 'score-marked-en-blank').exists()).toBe(false);
  });

  it('opens with Save disabled — nothing has changed yet', async () => {
    const w = await mountView();
    expect(isDisabled(w)).toBe(true);
  });
});

describe('TutorTutoring2ScoresView — saving', () => {
  it('posts ONLY the changed row, with the value that was typed', async () => {
    const w = await mountView();
    await type(w, 'en-blank', '70');
    await saveBtn(w).trigger('click');
    await flushPromises();

    expect(posted).toHaveLength(1);
    expect(posted[0]).toEqual([
      { enrollment_id: 'en-blank', score: 70, notes: null },
    ]);
  });

  it('fires the confirmation, naming how many scores were updated', async () => {
    const w = await mountView();
    await type(w, 'en-blank', '70');
    await saveBtn(w).trigger('click');
    await flushPromises();

    expect(toastSpies.success).toHaveBeenCalledTimes(1);
    expect(toastSpies.success).toHaveBeenCalledWith('1 skor diperbarui');
    expect(toastSpies.error).not.toHaveBeenCalled();
  });

  it('re-reads the server after saving, so the marker shows the NEW time', async () => {
    const w = await mountView();
    await type(w, 'en-scored', '95');
    await saveBtn(w).trigger('click');
    await flushPromises();

    // The pinned clock is 15 Sep 2026 09:00 WIB — the restamped value.
    expect(at(w, 'score-time-en-scored').text()).toContain('15 Sep 2026, 09.00');
    // And the row the tutor never touched keeps its original stamp.
    expect(store.find((r) => r.enrollment_id === 'en-blank').marked_at).toBeNull();
  });

  it('settles back to a disabled Save once the save lands', async () => {
    const w = await mountView();
    await type(w, 'en-scored', '95');
    expect(isDisabled(w)).toBe(false);
    await saveBtn(w).trigger('click');
    await flushPromises();
    expect(isDisabled(w)).toBe(true);
  });

  it('newly scored row gains the marker after the save round trip', async () => {
    const w = await mountView();
    expect(at(w, 'score-marked-en-blank').exists()).toBe(false);
    await type(w, 'en-blank', '70');
    await saveBtn(w).trigger('click');
    await flushPromises();
    expect(at(w, 'score-marked-en-blank').exists()).toBe(true);
    expect(at(w, 'score-time-en-blank').text()).toContain('15 Sep 2026, 09.00');
  });

  it('posts nothing at all when nothing was edited', async () => {
    const w = await mountView();
    await saveBtn(w).trigger('click');
    await flushPromises();
    expect(TutoringBimbelService.upsertScores).not.toHaveBeenCalled();
    expect(toastSpies.success).not.toHaveBeenCalled();
  });

  it('reports a failed save and does NOT claim success', async () => {
    const w = await mountView();
    vi.mocked(TutoringBimbelService.upsertScores).mockRejectedValueOnce(
      new Error('Request failed with status code 422'),
    );
    await type(w, 'en-scored', '95');
    await saveBtn(w).trigger('click');
    await flushPromises();

    expect(toastSpies.success).not.toHaveBeenCalled();
    expect(toastSpies.error).toHaveBeenCalledWith(
      'Gagal menyimpan skor: Request failed with status code 422',
    );
    // The edit is still pending, so the tutor can retry.
    expect(isDisabled(w)).toBe(false);
  });
});

describe('TutorTutoring2ScoresView — contract', () => {
  it('reads the ceiling off the assessment, which need not be 100', () => {
    const a: BimbelAssessment = {
      id: 'as-2',
      program_id: 'pr-1',
      title: 'TO 1',
      kind: 'tryout',
      max_score: 50,
      kkm: 30,
    };
    expect(a.max_score).not.toBe(100);
    expect(a.kkm).not.toBe(75);
  });

  it('carries marked_at on the row type — the stamp the marker renders', () => {
    const r: TutoringScoreRow = {
      enrollment_id: 'en-1',
      student_id: 'st-1',
      student_name: 'Budi Santoso',
      student_number: 'S-0042',
      score: 42,
      marked_at: '2026-09-09T14:30:00+07:00',
    };
    expect(r.marked_at).toBeTruthy();
  });
});
