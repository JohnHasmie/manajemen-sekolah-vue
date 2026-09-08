/**
 * The tutor's session detail must load THE session, not hunt for it in a
 * page of the list.
 *
 * The screen used to do this:
 *
 *     const { items } = await TutoringBimbelService.listSessions({ per_page: 100 });
 *     const match = items.find((s) => s.id === sessionId.value);
 *     return match ?? null;
 *
 * On a centre with more than 100 sessions the 101st is simply not in the
 * page, so `find` returns `undefined`, the loader returns `null`, and
 * the screen renders "Sesi tidak ditemukan" for a row the list above it
 * had just displayed. `GET /tutoring-v2/sessions/{id}` has no such
 * horizon.
 *
 * Own file rather than an addition to the reschedule
 * (`…SessionDetailView.spec.ts`) or gating (`.gate.spec.ts`) specs:
 * those mount a session that resolves and are about what happens
 * afterwards. This one is about the fetch itself, including the case
 * where it fails.
 *
 * `listSessions` is deliberately still on the service mock below, for
 * the opposite reason to before — so the pagination test can assert the
 * screen does NOT call it, and so it stays runnable (and red) against
 * the old implementation.
 *
 * NOT covered here, because it is not true: this change does not
 * recover any field the list was missing. `SessionController::index`
 * and `::show` run an identical `withCount` for `attendances` /
 * `attendances_present_count`, and both render `SessionResource`.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import SessionDetail from './TutorTutoring2SessionDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    getSession: vi.fn(),
    listSessions: vi.fn(),
    rescheduleSession: vi.fn(),
    completeSession: vi.fn(),
  },
}));
/** The session under test is the 101st — past the old `per_page: 100`. */
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'ses-101' } }),
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

function makeSession(id: string, overrides: Record<string, unknown> = {}) {
  return {
    id,
    learning_group_id: 'grp-1',
    learning_group_name: 'UTBK Pagi A',
    starts_at: '2026-07-18T09:00:00+07:00',
    ends_at: '2026-07-18T10:30:00+07:00',
    room: 'R1',
    status: 'scheduled',
    ...overrides,
  };
}

/**
 * A full first page that does NOT contain `ses-101`, which is exactly
 * what the server returns for a centre with more than 100 sessions.
 * The old loader saw this and concluded the session did not exist.
 */
const FIRST_PAGE = Array.from({ length: 100 }, (_, i) =>
  makeSession(`ses-${i + 1}`),
);

const TARGET = makeSession('ses-101', { room: 'R-101' });

async function mountView() {
  setActivePinia(createPinia());

  const w = mount(SessionDetail, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: {} },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: true,
        // Surfaces the BRANCH as an attribute: a missing session used to
        // land on `empty` (loader returned null) and now lands on
        // `error` (the endpoint 404s), and that difference is the point
        // of the second test below.
        AsyncView: {
          props: ['state'],
          template:
            `<div :data-status="state?.status" :data-error="state?.error ?? ''">` +
            `<slot v-if="state?.status === 'content'" :data="state.data" /></div>`,
        },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
        BottomSheetFooter: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('TutorTutoring2SessionDetailView — loading one session', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // Whatever the test does with `getSession`, the list is answerable
    // and does not contain the target. Against the old implementation
    // this is the page that produced "Sesi tidak ditemukan".
    vi.mocked(TutoringBimbelService.listSessions).mockResolvedValue({
      items: FIRST_PAGE,
    } as never);
  });

  it('renders a session that is NOT in the first page of the list', async () => {
    vi.mocked(TutoringBimbelService.getSession).mockResolvedValue(
      TARGET as never,
    );

    const w = await mountView();

    expect(w.get('[data-status]').attributes('data-status')).toBe('content');
    // The room only reaches the DOM if the session itself did.
    expect(w.text()).toContain('R-101');
  });

  it('asks the server for the route id instead of paging the list', async () => {
    vi.mocked(TutoringBimbelService.getSession).mockResolvedValue(
      TARGET as never,
    );

    await mountView();

    expect(TutoringBimbelService.getSession).toHaveBeenCalledWith('ses-101');
    // One row fetched, not a hundred.
    expect(TutoringBimbelService.listSessions).not.toHaveBeenCalled();
  });

  it('shows the ERROR branch when the session 404s, not the empty one', async () => {
    // A deleted session, or one outside this tutor's `narrowToCaller`
    // scope, rejects — where the old client-side `find` returned
    // `undefined` and the screen fell to `empty`. Same wiring as the
    // admin session detail.
    vi.mocked(TutoringBimbelService.getSession).mockRejectedValue(
      new Error('Request failed with status code 404'),
    );

    const w = await mountView();

    const host = w.get('[data-status]');
    expect(host.attributes('data-status')).toBe('error');
    expect(host.attributes('data-error')).toContain('404');
  });
});
