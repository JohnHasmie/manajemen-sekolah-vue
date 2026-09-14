/**
 * The tutor grader's two halves of one report:
 *
 *   "ketika diubah nilai dan umpan baliknya kenapa tidak ada tombol
 *    simpan, setelah diedit atau diisi dan di refresh data belum
 *    tersimpan"
 *
 * ── Half one: the save control ──
 *
 * There IS one, per row, and it does fire the request — the last two
 * tests here are the proof, and they were green before this change.
 * What it lacked was a way to be FOUND: it sat in the seventh column of
 * a horizontally scrolling table, under a header cell that was literally
 * empty, so on a narrow window it scrolled out of sight with nothing
 * above it to say anything was there. It is now labelled and pinned to
 * the right edge of the scroll area. `theadLabels` is what guards that:
 * a blank action header is the state being ruled out.
 *
 * ── Half two: the note ──
 *
 * `_feedbackInput` was hard-coded to `''` on every load, and the save
 * handler wrote back `status`, `score` and `graded_at` from the response
 * but never the note. So even once the server learned to store feedback
 * (backend MR), a refresh would still have shown an empty box — a second,
 * independent way to lose the same text. Both directions are asserted:
 * what the server already holds must appear, and what the server echoes
 * back after a save must replace what was typed (it is the trimmed,
 * canonical copy).
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SubmissionsView from './TutorTutoring2SubmissionsView.vue';
import { ActivitiesService } from '@/services/tutoring2/activities';
import { SubmissionsService } from '@/services/tutoring2/submissions';

vi.mock('@/services/tutoring2/activities', () => ({
  ActivitiesService: { get: vi.fn() },
}));
vi.mock('@/services/tutoring2/submissions', () => ({
  SubmissionsService: { listByActivity: vi.fn(), grade: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ query: { activity_id: 'act-1' }, params: {} }),
  useRouter: () => ({ push: vi.fn(), replace: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));
vi.mock('@/stores/me', () => ({
  useMeStore: () => ({ can: () => true, canAny: () => true }),
}));

const BASE_ROW = {
  id: 'sub-1',
  activity_id: 'act-1',
  enrollment_id: 'enr-1',
  student_id: 'stu-1',
  student_name: 'Aisyah Nur',
  status: 'submitted' as const,
  score: null,
  feedback: null,
  submitted_at: '2026-08-17T08:00:00+07:00',
};

async function mountView(rows: Record<string, unknown>[]) {
  setActivePinia(createPinia());
  vi.mocked(ActivitiesService.get).mockResolvedValue({
    id: 'act-1',
    title: 'Latihan 1',
    max_points: 100,
  } as never);
  vi.mocked(SubmissionsService.listByActivity).mockResolvedValue({
    items: rows,
  } as never);

  const w = mount(SubmissionsView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: {
            id: {
              tutoring2: {
                common: { student: 'Siswa', save: 'Simpan', actions: 'Aksi' },
              },
            },
          },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async">' +
            "<slot v-if=\"state?.status === 'content'\" :data=\"state.data\" />" +
            '</div>',
        },
      },
    },
  });
  await flushPromises();
  await flushPromises();
  return w;
}

type View = Awaited<ReturnType<typeof mountView>>;

/** The feedback textarea of the first body row. */
function feedbackBox(w: View) {
  return w.get('[data-testid="async"] tbody tr').get('textarea');
}

/** The score input of the first body row. */
function scoreBox(w: View) {
  return w.get('[data-testid="async"] tbody tr').get('input');
}

/** The per-row save button — the last button in the row. */
function saveButton(w: View) {
  const buttons = w.get('[data-testid="async"] tbody tr').findAll('button');
  return buttons[buttons.length - 1];
}

function theadLabels(w: View) {
  return w
    .get('[data-testid="async"] thead tr')
    .findAll('th')
    .map((th) => th.text().trim());
}

describe('TutorTutoring2SubmissionsView — umpan balik round trip', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows the note the server already holds', async () => {
    // The refresh in the report. A tutor who saved yesterday opens the
    // screen today: the box must not be blank.
    const w = await mountView([
      { ...BASE_ROW, status: 'graded', score: 90, feedback: 'Langkah ketiga masih terbalik.' },
    ]);

    expect((feedbackBox(w).element as HTMLTextAreaElement).value).toBe(
      'Langkah ketiga masih terbalik.',
    );
    expect((scoreBox(w).element as HTMLInputElement).value).toBe('90');
  });

  it('leaves the box empty when there is no note yet', async () => {
    const w = await mountView([{ ...BASE_ROW }]);

    expect((feedbackBox(w).element as HTMLTextAreaElement).value).toBe('');
  });

  it('keeps the note the server echoes back after a save', async () => {
    // The server is the canonical copy — it trims. If the screen kept
    // showing the raw typed text, the next save would diff against a
    // value the server never stored.
    const w = await mountView([{ ...BASE_ROW }]);

    await scoreBox(w).setValue('88');
    await feedbackBox(w).setValue('  Kerja bagus.  ');

    vi.mocked(SubmissionsService.grade).mockResolvedValue({
      ...BASE_ROW,
      status: 'graded',
      score: 88,
      feedback: 'Kerja bagus.',
      graded_at: '2026-09-14T10:00:00+07:00',
    } as never);

    await saveButton(w).trigger('click');
    await flushPromises();

    expect((feedbackBox(w).element as HTMLTextAreaElement).value).toBe('Kerja bagus.');
  });

  it('gives the save column a header instead of a blank cell', async () => {
    // A control nobody can see is, to the tutor, a control that does not
    // exist — which is what the report said about it.
    const w = await mountView([{ ...BASE_ROW }]);

    const labels = theadLabels(w);
    expect(labels[labels.length - 1]).not.toBe('');
    expect(labels[labels.length - 1]).toBe('Aksi');
  });

  it('still sends BOTH the score and the note when Simpan is pressed', async () => {
    // The control-that-lies check. Green before this change too — the
    // handler was always wired; the wire just went nowhere on the server.
    const w = await mountView([{ ...BASE_ROW }]);

    await scoreBox(w).setValue('75');
    await feedbackBox(w).setValue('Perlu latihan pecahan.');

    vi.mocked(SubmissionsService.grade).mockResolvedValue({
      ...BASE_ROW,
      status: 'graded',
      score: 75,
      feedback: 'Perlu latihan pecahan.',
    } as never);

    await saveButton(w).trigger('click');
    await flushPromises();

    expect(SubmissionsService.grade).toHaveBeenCalledWith('sub-1', {
      score: 75,
      feedback: 'Perlu latihan pecahan.',
    });
  });

  it('enables Simpan only once the row has been touched', async () => {
    const w = await mountView([{ ...BASE_ROW }]);

    expect(saveButton(w).attributes('disabled')).toBeDefined();

    await feedbackBox(w).setValue('Sudah rapi.');

    expect(saveButton(w).attributes('disabled')).toBeUndefined();
  });
});
