/**
 * The two parent screens disagreed about the child's own name.
 *
 * `ParentTutoring2HomeView` and this screen fold the SAME
 * `listEnrollments` payload into the same "one row per child" shape.
 * The Home view copied `student_name` into its row; this one's local
 * `ChildRow` had no name field, so it dropped the name and printed
 * "ID siswa 01a00e34". A parent saw their child's name on one screen
 * and a uuid fragment on the next — the worst version of this bug,
 * because a parent has no way to know the two refer to the same child.
 *
 * The fold, not the template, is what is pinned here. `ChildRow` is
 * built once per child and then reused, so the name-copy must work on
 * BOTH paths through the loop, and each is asserted on its own:
 *
 *   - the CREATE path, first enrollment for a child;
 *   - the REUSE path, second enrollment onwards — taken by every child
 *     with more than one programme. If the name is only copied on
 *     create, such a child renders as an id fragment whenever their
 *     FIRST enrollment came back nameless, sitting in the same list as
 *     a named sibling.
 *
 * Both orders are asserted, because the two fixes fail oppositely: an
 * unconditional overwrite would name the child from a later row and
 * then let a still-later nameless row erase it again.
 *
 * This screen is DELIBERATELY STRICTER than its sibling Home view.
 * Home writes `c.student_name ?? …`, which lets a whitespace-only name
 * win and render a blank row, and it copies the name on create only.
 * The shared ladder trims first. The divergence is intentional and the
 * direction matters: Home should be brought UP to this, never this
 * loosened back down to Home. Home is not one of the seven screens in
 * this sweep, so it is filed as a follow-up.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import PickChild from './ParentTutoring2PickChildView.vue';
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
    ...overrides,
  };
}

async function mountView(items: unknown[]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue({ items } as never);

  const w = mount(PickChild, {
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
  return w.findAll('[data-testid="async"] li').map((li) => li.text());
}

describe('ParentTutoring2PickChildView — child label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('carries the child name through the enrollment→child fold', async () => {
    const w = await mountView([
      makeEnrollment(),
      makeEnrollment({ id: 'enr-2', program_id: 'aaa11111', status: 'trial' }),
    ]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Aisyah Nur');
    expect(rowText(w)[0]).not.toContain('01a00e34');
    expect(rowText(w)[0]).not.toContain(FULL_STUDENT_ID);
  });

  it('names the child from the SECOND enrollment when the first had no name', async () => {
    // The reuse path on its own: same `student_id`, so enrollment 2
    // never creates a row. A create-only copy leaves this an id
    // fragment.
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
    const w = await mountView([
      makeEnrollment({ id: 'enr-1', student_name: 'Aisyah Nur' }),
      makeEnrollment({ id: 'enr-2', program_id: 'aaa11111', student_name: null }),
      makeEnrollment({ id: 'enr-3', program_id: 'bbb22222', student_name: '  ' }),
    ]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Aisyah Nur');
    expect(rowText(w)[0]).not.toContain('ID siswa 01a00e34');
  });

  it('treats a whitespace-only first name as still unnamed, not as an answer', async () => {
    const w = await mountView([
      makeEnrollment({ id: 'enr-1', student_name: '  ' }),
      makeEnrollment({ id: 'enr-2', program_id: 'aaa11111', student_name: 'Aisyah Nur' }),
    ]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('Aisyah Nur');
    expect(rowText(w)[0]).not.toContain('ID siswa 01a00e34');
  });

  it('agrees with the sibling Home screen on the same payload', async () => {
    // The regression this file exists to stop: both screens fold the
    // identical payload, so both must reach the identical label.
    const items = [makeEnrollment()];
    const w = await mountView(items);

    expect(rowText(w)[0]).toContain(items[0].student_name as string);
  });

  it('falls back to a short id when the name was not sent', async () => {
    const w = await mountView([makeEnrollment({ student_name: null })]);

    expect(rowText(w)).toHaveLength(1);
    expect(rowText(w)[0]).toContain('ID siswa 01a00e34');
    expect(rowText(w)[0]).not.toContain(FULL_STUDENT_ID);
  });

  it('does not let a whitespace-only name blank the row', async () => {
    const w = await mountView([makeEnrollment({ student_name: '  ' })]);

    expect(rowText(w)[0]).toContain('ID siswa 01a00e34');
  });

  it('gives an em-dash when nothing identifies the child', async () => {
    const w = await mountView([makeEnrollment({ student_name: null, student_id: '' })]);

    expect(rowText(w)[0]).toContain('—');
    expect(rowText(w)[0]).not.toContain('ID siswa');
  });
});
