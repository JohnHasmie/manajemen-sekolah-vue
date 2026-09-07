/**
 * The "Tutor" row on the tutor's session detail rendered
 * `session.tutor_id ?? '—'` — a FULL 36-character uuid — while
 * `tutor_name` sat on the same session object.
 *
 * Own file rather than an addition to `.group-name.spec.ts`: that file
 * is the pin for !1244's fix, and the two defects have different
 * histories. This one is worse in a specific way worth keeping written
 * down — `?? '—'` reads as a considered fallback, so nobody re-read the
 * line. It guarded against the field being ABSENT and never asked
 * whether a better field was PRESENT. The group rows at least looked
 * obviously unfinished; this one looked done.
 *
 * The id rung is pinned as truncated, not merely "not the name": a
 * co-teaching tutor whose name was not eager-loaded still needs
 * something quotable, but a raw uuid overflows the row and tells the
 * reader nothing the first 8 characters do not.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionDetail from './TutorTutoring2SessionDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listSessions: vi.fn(),
    rescheduleSession: vi.fn(),
    completeSession: vi.fn(),
  },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'ses-1' } }),
  useRouter: () => ({ push: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));
vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: () => true, canAny: () => true }),
}));

const FULL_TUTOR_ID = 'ab120000-dead-beef-cafe-000000000001';

function makeSession(overrides: Record<string, unknown> = {}) {
  return {
    id: 'ses-1',
    learning_group_id: '01a00e34-dead-beef',
    learning_group_name: 'UTBK Pagi A',
    tutor_id: FULL_TUTOR_ID,
    tutor_name: 'Pak Rudi',
    starts_at: '2026-07-18T09:00:00+07:00',
    ends_at: '2026-07-18T10:30:00+07:00',
    room: 'R1',
    status: 'scheduled',
    ...overrides,
  };
}

async function mountView(session: Record<string, unknown>) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
    items: [session],
  } as never);

  const w = mount(SessionDetail, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: {
            id: { tutoring2: { common: { group: 'Kelompok', tutor: 'Tutor' } } },
          },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        AsyncView: {
          props: ['state'],
          template:
            "<div><slot v-if=\"state?.status === 'content'\" :data=\"state.data\" /></div>",
        },
        Modal: { template: '<div><slot /></div>' },
        BottomSheetFooter: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Text of the definition list row whose term is "Tutor". */
function tutorRowText(w: Awaited<ReturnType<typeof mountView>>) {
  const row = w
    .findAll('dl > div')
    .find((d) => d.find('dt').exists() && d.get('dt').text() === 'Tutor');
  expect(row, 'no "Tutor" row rendered').toBeTruthy();
  return row!.get('dd').text();
}

describe('TutorTutoring2SessionDetailView — tutor label', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows the tutor NAME the payload already carries', async () => {
    const w = await mountView(makeSession());

    expect(tutorRowText(w)).toBe('Pak Rudi');
  });

  it('falls back to a TRUNCATED id, never the raw uuid', async () => {
    const w = await mountView(makeSession({ tutor_name: null }));

    expect(tutorRowText(w)).toBe('Tutor ab120000');
    expect(tutorRowText(w)).not.toContain(FULL_TUTOR_ID);
  });

  it('keeps the em-dash when the session has no tutor at all', async () => {
    // An unassigned session is a real state, not an error — the row must
    // still say "we were not told", not "Tutor " with a dangling space.
    const w = await mountView(makeSession({ tutor_name: null, tutor_id: null }));

    expect(tutorRowText(w)).toBe('—');
  });
});
