/**
 * Two dropped names on one screen, both fixable only because the data
 * was already in hand:
 *
 *   - the HEADER and info card said `shortId(studentId)`, taking the id
 *     straight off the route. That was defensible when written — the
 *     route is all this screen is given — but every enrollment it then
 *     loads carries `student_name`, so by the time the page paints, the
 *     student's name is sitting in memory unread.
 *   - each enrollment row said `shortId(e.program_id)` while
 *     `e.program_name` was a field away on the SAME object.
 *
 * The header case is the interesting one to pin, because its fallback
 * is load-bearing in a way the others are not: the label must show the
 * id fragment while the request is still in flight and only become the
 * name once rows arrive. If the ladder were reordered so a missing name
 * blanked the header, the page would flash empty on every load.
 *
 * The info card is pinned separately from the header because the two
 * want DIFFERENT strings from the same ladder. The header meta stands
 * alone, so its id fragment has to carry the "ID siswa" prefix to say
 * what it is. The card prints its own kicker directly above the value,
 * so the same prefixed string read "ID SISWA / ID siswa 01a00e34" —
 * and once the value became a name, the kicker was naming the wrong
 * field entirely. The card now says "Siswa" and takes the unprefixed
 * label. The unnamed path is asserted, not just the named one, because
 * the duplication only ever showed up there.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import StudentDetail from './TutorTutoring2StudentDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listEnrollments: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: '01a00e34-dead-beef-cafe-000000000001' } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

const FULL_STUDENT_ID = '01a00e34-dead-beef-cafe-000000000001';
const FULL_PROGRAM_ID = '9f0a1122-dead-beef-cafe-000000000002';

function makeEnrollment(overrides: Record<string, unknown> = {}) {
  return {
    id: 'enr-1',
    student_id: FULL_STUDENT_ID,
    student_name: 'Aisyah Nur',
    program_id: FULL_PROGRAM_ID,
    program_name: 'Intensif UTBK',
    billing_mode: 'monthly',
    billing_mode_label: 'Bulanan',
    status: 'active',
    status_label: 'Aktif',
    ...overrides,
  };
}

async function mountView(items: unknown[]) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listEnrollments).mockResolvedValue({ items } as never);

  const w = mount(StudentDetail, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: {
            id: {
              tutoring2: {
                common: { studentId: 'ID siswa', student: 'Siswa', program: 'Program' },
              },
            },
          },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        // Not `true` — the header's label is a PROP, and a fully stubbed
        // component renders none of its attributes, so asserting on the
        // page text would silently miss it.
        BrandPageHeader: {
          props: ['meta'],
          template: '<header data-testid="page-header">{{ meta }}</header>',
        },
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
  return w;
}

const headerText = (w: Awaited<ReturnType<typeof mountView>>) =>
  w.get('[data-testid="page-header"]').text();
const bodyText = (w: Awaited<ReturnType<typeof mountView>>) =>
  w.get('[data-testid="async"]').text();

describe('TutorTutoring2StudentDetailView — student + program labels', () => {
  beforeEach(() => vi.clearAllMocks());

  it('names the student from the enrollments it already loaded', async () => {
    const w = await mountView([makeEnrollment()]);

    expect(headerText(w)).toBe('Aisyah Nur');
    expect(bodyText(w)).toContain('Aisyah Nur');
    expect(bodyText(w)).not.toContain(FULL_STUDENT_ID);
    expect(bodyText(w)).not.toContain('01a00e34');
  });

  it('names the program from the same enrollment row', async () => {
    const w = await mountView([makeEnrollment()]);

    expect(bodyText(w)).toContain('Intensif UTBK');
    expect(bodyText(w)).not.toContain(FULL_PROGRAM_ID);
    expect(bodyText(w)).not.toContain('9f0a1122');
  });

  it('takes the name from the first enrollment that actually has one', async () => {
    // Rows are not guaranteed to be uniform: `whenLoaded` omits the key
    // per row, so row 1 can be nameless while row 2 is named.
    const w = await mountView([
      makeEnrollment({ id: 'enr-1', student_name: null }),
      makeEnrollment({ id: 'enr-2', student_name: 'Aisyah Nur' }),
    ]);

    expect(headerText(w)).toBe('Aisyah Nur');
  });

  it('falls back to short ids when no name was sent', async () => {
    const w = await mountView([
      makeEnrollment({ student_name: null, program_name: null }),
    ]);

    expect(headerText(w)).toBe('ID siswa 01a00e34');
    expect(bodyText(w)).toContain('Program 9f0a1122');
    expect(bodyText(w)).not.toContain(FULL_STUDENT_ID);
    expect(bodyText(w)).not.toContain(FULL_PROGRAM_ID);
  });

  it('labels the info card "Siswa", not "ID siswa", now that it holds a name', async () => {
    const w = await mountView([makeEnrollment()]);

    // The kicker names the field; the value under it is the name.
    expect(bodyText(w)).toContain('Siswa');
    expect(bodyText(w)).toContain('Aisyah Nur');
    expect(bodyText(w)).not.toContain('ID siswa');
  });

  it('does not repeat the prefix in the info card on the unnamed path', async () => {
    // The regression this pins: kicker "ID siswa" over a value that was
    // itself prefixed, i.e. "ID SISWA / ID siswa 01a00e34".
    const w = await mountView([makeEnrollment({ student_name: null })]);

    // Header still carries the prefix — it has no kicker beside it.
    expect(headerText(w)).toBe('ID siswa 01a00e34');
    // Card: kicker + bare fragment, and the fragment appears once.
    expect(bodyText(w)).toContain('01a00e34');
    expect(bodyText(w)).not.toContain('ID siswa 01a00e34');
    expect(bodyText(w).match(/01a00e34/g)).toHaveLength(1);
    expect(bodyText(w)).not.toContain(FULL_STUDENT_ID);
  });

  it('shows the id fragment, never a blank, before the rows arrive', async () => {
    // Header paints on the route param alone while the list is empty.
    const w = await mountView([]);

    expect(headerText(w)).toBe('ID siswa 01a00e34');
  });
});
