/**
 * The tutor's student list showed each student as an 8-character uuid
 * fragment — and unlike the group-label bugs, this one could NOT be
 * fixed in the template alone.
 *
 * `BimbelEnrollment` carries `student_name`. This screen folds many
 * enrollments into one row per student through a local `StudentRow`
 * type, and that type had no name field at all: the name arrived from
 * the server and was DROPPED on the way to the template. The template
 * was printing the only thing it had been handed.
 *
 * So the first three tests below are the load-bearing ones — they
 * assert the name SURVIVES the fold, and they cover BOTH branches of
 * it separately, because the two fail in different directions:
 *
 *   - the CREATE branch (first enrollment for a student) — a
 *     template-only "fix" leaves it reading undefined;
 *   - the EXISTING branch (second enrollment onwards, where only the
 *     counters used to be touched) — reached by every student with more
 *     than one program. A fold that copies the name only on create
 *     shows the id fragment for any such student whose FIRST row came
 *     back nameless, while their single-program classmate right above
 *     them is named. That is the confusing kind of wrong: one list, two
 *     conventions, and nothing on screen to explain the difference.
 *
 * The pair is asserted in both orders on purpose. "Named row first,
 * nameless row second" catches the opposite mistake — an unconditional
 * overwrite that lets a later empty row ERASE a name already found.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import StudentsView from './TutorTutoring2StudentsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

const FULL_STUDENT_ID = '01a00e34-dead-beef-cafe-000000000001';

function makeEnrollment(overrides: Record<string, unknown> = {}) {
  return {
    id: 'enr-1',
    student_id: FULL_STUDENT_ID,
    student_name: 'Aisyah Nur',
    program_id: '9f0a1122-dead-beef',
    program_name: 'Intensif UTBK',
    billing_mode: 'monthly',
    status: 'active',
    status_label: 'Aktif',
    ...overrides,
  };
}

async function mountView(items: unknown[]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue({ items } as never);

  const w = mount(StudentsView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: { tutoring2: { common: { studentId: 'ID siswa' } } } },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: true,
        AppFilterChip: true,
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
  return w;
}

function rowText(w: Awaited<ReturnType<typeof mountView>>) {
  return w.findAll('[data-testid="async"] button').map((b) => b.text());
}

describe('TutorTutoring2StudentsView — student label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('carries the name through the enrollment→student fold', async () => {
    // Two enrollments for ONE student, both named: the first creates
    // the row, the second takes the "existing" branch.
    const w = await mountView([
      makeEnrollment(),
      makeEnrollment({ id: 'enr-2', program_id: 'aaa11111', status: 'trial' }),
    ]);

    // Non-vacuity: exactly one folded row, and it rendered.
    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Aisyah Nur');
    expect(rowText(w)[0]).not.toContain('01a00e34');
    expect(rowText(w)[0]).not.toContain(FULL_STUDENT_ID);
  });

  it('names the row from the SECOND enrollment when the first had no name', async () => {
    // The existing-row branch on its own. Both rows carry the same
    // `student_id`, so row 2 never creates a row — if the fold only
    // copies the name on create, this row stays an id fragment.
    const w = await mountView([
      makeEnrollment({ id: 'enr-1', student_name: null }),
      makeEnrollment({ id: 'enr-2', program_id: 'aaa11111', student_name: 'Aisyah Nur' }),
    ]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Aisyah Nur');
    expect(rowText(w)[0]).not.toContain('ID siswa 01a00e34');
    expect(rowText(w)[0]).not.toContain(FULL_STUDENT_ID);
  });

  it('does not let a later nameless enrollment erase a name already found', async () => {
    // The mirror of the test above. Fixing the existing-row branch with
    // an unconditional assignment would pass that one and fail this.
    const w = await mountView([
      makeEnrollment({ id: 'enr-1', student_name: 'Aisyah Nur' }),
      makeEnrollment({ id: 'enr-2', program_id: 'aaa11111', student_name: null }),
      makeEnrollment({ id: 'enr-3', program_id: 'bbb22222', student_name: '   ' }),
    ]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Aisyah Nur');
    expect(rowText(w)[0]).not.toContain('ID siswa 01a00e34');
  });

  it('treats a whitespace-only first name as still unnamed, not as an answer', async () => {
    // `"   "` must not squat in the row and block the real name that
    // arrives on the next enrollment — the trim in the fold is what
    // this pins.
    const w = await mountView([
      makeEnrollment({ id: 'enr-1', student_name: '   ' }),
      makeEnrollment({ id: 'enr-2', program_id: 'aaa11111', student_name: 'Aisyah Nur' }),
    ]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Aisyah Nur');
    expect(rowText(w)[0]).not.toContain('ID siswa 01a00e34');
  });

  it('falls back to a short id when the name was not sent', async () => {
    const w = await mountView([makeEnrollment({ student_name: null })]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('ID siswa 01a00e34');
    expect(rowText(w)[0]).not.toContain(FULL_STUDENT_ID);
  });

  it('does not let a whitespace-only name blank the row', async () => {
    const w = await mountView([makeEnrollment({ student_name: '   ' })]);

    expect(rowText(w)[0]).toContain('ID siswa 01a00e34');
  });

  it('gives an em-dash when nothing identifies the student', async () => {
    const w = await mountView([makeEnrollment({ student_name: null, student_id: '' })]);

    expect(rowText(w)[0]).toContain('—');
    expect(rowText(w)[0]).not.toContain('ID siswa');
  });
});
