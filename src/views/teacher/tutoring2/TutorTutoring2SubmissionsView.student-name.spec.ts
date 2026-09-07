/**
 * The submissions grader had the right IDEA and the wrong ORDER:
 *
 *   row.student_name ?? row.student_id ?? row.enrollment_id.slice(0, 8)
 *
 * Name first is correct. But the middle rung is a FULL untruncated uuid,
 * and it is reached before the one rung that was actually truncated —
 * so the only way to see the tidy 8-character fallback was for the row
 * to be missing `student_id` too. In practice a nameless row rendered
 * 36 characters into a table cell.
 *
 * This is the lower-severity member of the sweep, and pinning it is
 * mostly about the ORDER, not the strings: what must never be true
 * again is "a raw full uuid is a reachable rendered outcome".
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

const FULL_STUDENT_ID = '01a00e34-dead-beef-cafe-000000000001';
const FULL_ENROLLMENT_ID = '77771111-dead-beef-cafe-000000000002';

function makeSubmission(overrides: Record<string, unknown> = {}) {
  return {
    id: 'sub-1',
    activity_id: 'act-1',
    enrollment_id: FULL_ENROLLMENT_ID,
    student_id: FULL_STUDENT_ID,
    student_name: 'Aisyah Nur',
    status: 'submitted',
    status_label: 'Dikumpulkan',
    submitted_at: '2026-08-17T08:00:00+07:00',
    ...overrides,
  };
}

async function mountView(items: unknown[]) {
  setActivePinia(createPinia());
  vi.mocked(ActivitiesService.get).mockResolvedValue({
    id: 'act-1',
    title: 'Latihan 1',
    max_score: 100,
  } as never);
  vi.mocked(SubmissionsService.listByActivity).mockResolvedValue({ items } as never);

  const w = mount(SubmissionsView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: { tutoring2: { common: { student: 'Siswa' } } } },
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

/** Text of the first cell of each body row — the student column. */
function studentCells(w: Awaited<ReturnType<typeof mountView>>) {
  return w.findAll('[data-testid="async"] tbody tr').map((tr) => tr.get('td').text());
}

describe('TutorTutoring2SubmissionsView — student label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows the student NAME when the row carries one', async () => {
    const w = await mountView([makeSubmission()]);

    expect(studentCells(w)).toHaveLength(1);
    expect(studentCells(w)[0]).toContain('Aisyah Nur');
    expect(studentCells(w)[0]).not.toContain('01a00e34');
  });

  it('truncates the student id instead of printing the raw uuid', async () => {
    // The regression: this exact row used to render 36 characters.
    const w = await mountView([makeSubmission({ student_name: null })]);

    expect(studentCells(w)).toHaveLength(1);
    expect(studentCells(w)[0]).toContain('01a00e34');
    expect(studentCells(w)[0]).not.toContain(FULL_STUDENT_ID);
    expect(studentCells(w)[0]).not.toContain('dead-beef');
  });

  it('still falls through to the enrollment id when there is no student id', async () => {
    // Submissions are keyed by enrollment; `student_id` is optional on
    // the wire, so this rung must survive the reorder.
    const w = await mountView([makeSubmission({ student_name: null, student_id: null })]);

    expect(studentCells(w)[0]).toContain('77771111');
    expect(studentCells(w)[0]).not.toContain(FULL_ENROLLMENT_ID);
  });

  it('never renders a full uuid on any rung', async () => {
    for (const row of [
      makeSubmission(),
      makeSubmission({ student_name: null }),
      makeSubmission({ student_name: '   ' }),
      makeSubmission({ student_name: null, student_id: null }),
    ]) {
      const w = await mountView([row]);
      expect(studentCells(w)).toHaveLength(1);
      expect(studentCells(w)[0]).not.toContain(FULL_STUDENT_ID);
      expect(studentCells(w)[0]).not.toContain(FULL_ENROLLMENT_ID);
    }
  });
});
