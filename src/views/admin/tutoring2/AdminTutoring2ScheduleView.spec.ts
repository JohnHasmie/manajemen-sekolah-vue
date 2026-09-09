/**
 * Vitest contract spec for AdminTutoring2ScheduleView.
 *
 * Pins the Kelompok / Tutor filter chips, which shipped inert: the click
 * handler was `@click="groupFilter = ''"`, i.e. it only ever CLEARED to
 * the "Semua" default and no menu existed behind it, so a bimbel admin
 * on prod reported "semua button/filter tdk berfungsi". Both chips also
 * rendered `truncateId(...)` — an id fragment — so even a working filter
 * would have read as hex.
 *
 * Also pinned: the Kelompok / Tutor TABLE columns rendered
 * `truncateId(s.learning_group_id)` while `learning_group_name` and
 * `tutor_name` were already present on the very same row (
 * SessionController::index eager-loads both, SessionResource exposes
 * them). The names must win.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body and would escape the wrapper);
 * the option rows clicked here are the ones an admin clicks.
 *
 * The STATUS chip was missed by that pass and stayed broken after the
 * screen was reported fixed to the customer. Its handler was
 * `statusFilter = statusFilter ? '' : 'scheduled'` — a two-value toggle
 * over the four-value `BimbelSession['status']` lifecycle — so
 * `in_progress`, `done` and `cancelled` were unreachable however often
 * the chip was pressed, and the chip rendered the raw enum
 * (`scheduled`) where a label belongs. The last describe block below
 * pins all of that, plus the reload count, since a picker that refetches
 * twice per pick is its own defect.
 */
// @ts-nocheck — vitest types not installed yet
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { reactive } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2ScheduleView from './AdminTutoring2ScheduleView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

/**
 * Only the SERVICE object is faked. The module's constants — notably
 * `BIMBEL_SESSION_STATUSES`, the runtime spelling of the canonical
 * `BimbelSession['status']` union — come through untouched via
 * `importOriginal`, so the Status picker under test renders the real
 * lifecycle list. A hand-written copy in this mock would let the two
 * drift apart and still go green, which is the exact class of lie this
 * screen is being fixed for.
 */
vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal()),
  TutoringBimbelService: {
    listSessions: vi.fn(),
    listGroups: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

/**
 * Ability the "+ Buat sesi" CTA is gated on. Mutable so the "hidden
 * without the grant" case can revoke it per test.
 */
let grantedAbilities: string[] = ['tutoring.session.manage'];

/**
 * Spied, not just stubbed: one test asserts the view asks `useMe` (the
 * /me snapshot, scoped by X-Active-Role) rather than reaching into the
 * auth store's unscoped `roles[].permission_keys`.
 */
const canSpy = vi.fn((ability: string) => grantedAbilities.includes(ability));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: canSpy,
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

const push = vi.fn();
const replace = vi.fn();

/**
 * Mutable so the Laporan Aktivitas drill-in (`?date=YYYY-MM-DD`) can be
 * simulated per test. `useRoute()` returns the SAME object every call,
 * which is what lets the view's `watch(() => route.query.date, …)` see a
 * later mutation.
 */
// REACTIVE, because the view watches `() => route.query.date`. A plain
// object would never notify, and the "follows the URL" test would be
// asserting nothing.
const route = reactive({ params: {}, query: {} as Record<string, unknown> });
const routeQuery = route.query;

function setDateQuery(value?: string) {
  for (const k of Object.keys(routeQuery)) delete routeQuery[k];
  if (value !== undefined) routeQuery.date = value;
}

vi.mock('vue-router', () => ({
  useRouter: () => ({ push, replace, back: vi.fn() }),
  useRoute: () => route,
}));

function makeSession(overrides = {}) {
  return {
    id: 'se-1',
    learning_group_id: 'gr-1',
    learning_group_name: 'UTBK Pagi A',
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    starts_at: '2026-08-17T08:00:00+07:00',
    ends_at: '2026-08-17T10:00:00+07:00',
    room: 'R1',
    status: 'scheduled',
    status_label: 'Terjadwal',
    ...overrides,
  };
}

const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', program_name: 'Intensif UTBK', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-2', program_name: 'Reguler SMP', name: 'SMP Sore B', kind: 'group', capacity: 10, status: 'active' },
];
const TUTORS = [
  { id: 'tu-1', user_id: 'us-1', name: 'Pak Rahmat', is_active: true, active_group_count: 2 },
  { id: 'tu-2', user_id: 'us-2', name: 'Bu Sinta', is_active: true, active_group_count: 1 },
];

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: {
            all: 'Semua',
            group: 'Kelompok',
            tutor: 'Tutor',
            status: 'Status',
            period: 'Periode',
          },
          admin: {
            schedule: {
              // The real id.json values for the drill-in context bar.
              dateFilterActive: 'Menampilkan sesi pada {date}',
              dateFilterClear: 'Tampilkan semua tanggal',
            },
          },
          // The real id.json values. The Status chip and its picker must
          // render THESE, never the wire enums they key off.
          status: {
            scheduled: 'Terjadwal',
            inProgress: 'Berlangsung',
            done: 'Selesai',
            cancelled: 'Dibatalkan',
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const i18n = makeI18n();
  const w = mount(AdminTutoring2ScheduleView, {
    global: {
      plugins: [i18n],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
        // Mirrors the real chip's contract: renders `value`, honours
        // `disabled`, emits `click`.
        AppFilterChip: {
          props: ['label', 'value', 'iconName', 'active', 'disabled'],
          emits: ['click'],
          template:
            '<button data-testid="chip" :disabled="disabled" @click="$emit(\'click\')">{{ value }}</button>',
        },
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
        // FilterFacetPickerModal is NOT stubbed — only the Modal shell it
        // renders into, because Modal teleports to body.
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  mounted.push(w);
  return w;
}

/**
 * Every wrapper this file mounts, torn down after each test.
 *
 * Mandatory now that `route` is a shared reactive object: a view left
 * mounted keeps its `watch(() => route.query.date, …)` alive, so the
 * NEXT test's `setDateQuery()` reloads every zombie from every earlier
 * test as well as the one under test. That is how the refetch counters
 * in this file went from 1 to 69.
 */
const mounted: ReturnType<typeof mount>[] = [];
afterEach(() => {
  for (const w of mounted.splice(0)) w.unmount();
});

/** Chips render in template order: status, group, tutor, period. */
const CHIP = { status: 0, group: 1, tutor: 2, period: 3 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function lastListSessionsArg() {
  const calls = (TutoringBimbelService.listSessions as any).mock.calls;
  return calls[calls.length - 1][0];
}

describe('AdminTutoring2ScheduleView filter chips', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('loads both option lists on mount', async () => {
    await mountView();

    expect(TutoringBimbelService.listGroups).toHaveBeenCalledTimes(1);
    expect(TutoringTutorsService.list).toHaveBeenCalledTimes(1);
  });

  it('the id-valued chips start at "Semua" and are enabled once options arrive', async () => {
    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    for (const i of [CHIP.group, CHIP.tutor]) {
      expect(chips[i].text()).toBe('Semua');
      expect(chips[i].attributes('disabled')).toBeUndefined();
    }
  });

  it('clicking the Kelompok chip OPENS a picker listing groups by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — this is the regression: the old
    // handler set the filter to '' and opened nothing at all.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('UTBK Pagi A');
    expect(labels.join(' ')).toContain('SMP Sore B');
  });

  it('picking a group re-queries with learning_group_id and shows its name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');

    // Row 0 is the "Semua" reset; row 2 is the second group.
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListSessionsArg().learning_group_id).toBe('gr-2');
    const chip = w.findAll('[data-testid="chip"]')[CHIP.group];
    expect(chip.text()).toBe('SMP Sore B');
    expect(chip.text()).not.toContain('gr-2');
  });

  it('picking a tutor re-queries with tutor_id and shows their name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListSessionsArg().tutor_id).toBe('tu-2');
    expect(w.findAll('[data-testid="chip"]')[CHIP.tutor].text()).toBe('Bu Sinta');
  });

  it('the "Semua" row clears the filter back off the query', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListSessionsArg().learning_group_id).toBe('gr-2');

    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListSessionsArg().learning_group_id).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.group].text()).toBe('Semua');
  });

  it('a facet whose list came back empty disables its own chip only', async () => {
    (TutoringTutorsService.list as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.tutor].attributes('disabled')).toBeDefined();
    // The other chip must stay usable — one dead endpoint must not take
    // the whole toolbar down with it.
    expect(chips[CHIP.group].attributes('disabled')).toBeUndefined();
  });

  it('one failing option endpoint does not blank the other chip', async () => {
    (TutoringBimbelService.listGroups as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.group].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.tutor].attributes('disabled')).toBeUndefined();
  });
});

describe('AdminTutoring2ScheduleView table labels', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('renders the group and tutor NAMES the row already carries', async () => {
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession({ learning_group_id: 'gr-aaaaaaaa-bbbb', tutor_id: 'tu-cccccccc-dddd' })],
      pagination: undefined,
    });

    const w = await mountView();
    const row = w.find('[data-testid="async"] tbody tr').text();

    expect(row).toContain('UTBK Pagi A');
    expect(row).toContain('Pak Rahmat');
    // The ids must not leak into the cells now that names are available.
    expect(row).not.toContain('gr-aaaaa');
    expect(row).not.toContain('tu-ccccc');
  });

  it('falls back to an id fragment only when the row carries no name', async () => {
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession({ learning_group_name: null, tutor_name: null })],
      pagination: undefined,
    });

    const w = await mountView();
    const row = w.find('[data-testid="async"] tbody tr').text();

    expect(row).toContain('gr-1');
    expect(row).toContain('tu-1');
  });
});

/**
 * The floating "+ Buat sesi" CTA.
 *
 * It shipped fully styled, with the right i18n label, and with NO
 * `@click` at all — prod reported "tombol diklik tidak terjadi apa-apa".
 * Same defect !1211 fixed on the Kelompok and Program lists.
 *
 * Each test here fails against that old template:
 *
 *   1. has a handler       — clicking must DO something. The old button
 *                            swallowed the click silently.
 *   2. goes to the shared  — and specifically to
 *      create route          `admin.tutoring2.session-create`, the route
 *                            added for <Tutoring2CreateSessionView>. A
 *                            handler that navigated elsewhere would
 *                            relocate the complaint, not fix it.
 *   3. ability-gated       — no `tutoring.session.manage` → the CTA is
 *                            not rendered at all, rather than rendered
 *                            and refusing. Matches AdminTutoring2GroupsView.
 *   4. gate reads /me      — via `useMe().can`, never
 *                            `roles[].permission_keys`.
 */
const CTA = '[data-testid="schedule-new-cta"]';

describe('AdminTutoring2ScheduleView "+ Buat sesi" CTA', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    grantedAbilities = ['tutoring.session.manage'];
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('renders the CTA for an admin holding tutoring.session.manage', async () => {
    const w = await mountView();

    const cta = w.find(CTA);
    expect(cta.exists()).toBe(true);
    // Enabled — this one is genuinely wired, unlike the four CTAs on
    // sibling screens that have no surface to open.
    expect(cta.attributes('disabled')).toBeUndefined();
  });

  it('clicking it navigates somewhere — the click is not swallowed', async () => {
    const w = await mountView();

    await w.find(CTA).trigger('click');

    // The whole bug: the old button had no @click, so this was 0.
    expect(push).toHaveBeenCalledTimes(1);
  });

  it('navigates to the shared session-create route', async () => {
    const w = await mountView();

    await w.find(CTA).trigger('click');

    expect(push).toHaveBeenCalledWith({ name: 'admin.tutoring2.session-create' });
  });

  it('hides the CTA entirely without tutoring.session.manage', async () => {
    grantedAbilities = [];

    const w = await mountView();

    // Not rendered-and-refusing: absent. An admin never sees a button
    // that would reject them.
    expect(w.find(CTA).exists()).toBe(false);
  });

  it('reads the grant off the /me snapshot via useMe().can', async () => {
    await mountView();

    expect(canSpy).toHaveBeenCalledWith('tutoring.session.manage');
  });
});

/**
 * The Status chip.
 *
 * Verified red against the shipped
 * `@click="statusFilter = statusFilter ? '' : 'scheduled'"`: 10 of the
 * 11 tests below fail on it.
 *
 *   - opens a picker      — the toggle opened nothing at all.
 *   - lists all four      — the toggle could reach exactly one status.
 *   - each state queries  — `in_progress` / `done` / `cancelled` never
 *                           once reached `listSessions` under the toggle.
 *   - human label         — the toggle chip printed `scheduled`.
 *   - Semua clears        — the toggle could clear, but only by pressing
 *                           the chip a second time; there was no "Semua"
 *                           row to click, so this fails on it too.
 *   - exactly one refetch — counted, so a double-fire watcher fails as
 *                           loudly as a dead one.
 *   - same pick, no work  — re-picking the current status must not
 *                           re-hit the API.
 *
 * The one that passes either way is the rest-state check ("Semua", no
 * `status` on the query) — deliberately so: it is the baseline the
 * others move away from, not a defect pin.
 */
const STATUS_LABELS = {
  scheduled: 'Terjadwal',
  in_progress: 'Berlangsung',
  done: 'Selesai',
  cancelled: 'Dibatalkan',
} as const;

function listSessionsCalls() {
  return (TutoringBimbelService.listSessions as any).mock.calls;
}

/** Open the Status picker and click the row carrying `label`. */
async function pickStatus(w, label: string) {
  await w.findAll('[data-testid="chip"]')[CHIP.status].trigger('click');
  const row = optionRows(w).find((b) => b.text() === label);
  if (!row) {
    throw new Error(
      `no "${label}" row in the Status picker; saw: ${optionRows(w)
        .map((b) => b.text())
        .join(' | ')}`,
    );
  }
  await row.trigger('click');
  await flushPromises();
}

describe('AdminTutoring2ScheduleView Status chip', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('reads "Semua" at rest and sends no status', async () => {
    const w = await mountView();

    expect(w.findAll('[data-testid="chip"]')[CHIP.status].text()).toBe('Semua');
    expect(lastListSessionsArg().status).toBeUndefined();
  });

  it('clicking the chip OPENS a picker instead of toggling the filter', async () => {
    const w = await mountView();
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.status].trigger('click');

    // The regression: the old handler set the ref and opened nothing.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    // ...and the filter must NOT have moved just because the menu opened.
    expect(w.findAll('[data-testid="chip"]')[CHIP.status].text()).toBe('Semua');
  });

  it('the picker lists Semua plus every lifecycle state, by label', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.status].trigger('click');

    const labels = optionRows(w).map((b) => b.text());

    expect(labels).toEqual([
      'Semua',
      STATUS_LABELS.scheduled,
      STATUS_LABELS.in_progress,
      STATUS_LABELS.done,
      STATUS_LABELS.cancelled,
    ]);
    // No wire enum leaks into the menu.
    expect(labels.join(' ')).not.toContain('in_progress');
  });

  // The heart of the customer report: three of these four were
  // unreachable, so the API never once saw them.
  for (const [value, label] of Object.entries(STATUS_LABELS)) {
    it(`picking "${label}" queries the API with status=${value}`, async () => {
      const w = await mountView();

      await pickStatus(w, label);

      expect(lastListSessionsArg().status).toBe(value);
      // And the chip reports the pick in words, not in enum.
      const chip = w.findAll('[data-testid="chip"]')[CHIP.status];
      expect(chip.text()).toBe(label);
      expect(chip.text()).not.toContain(value);
    });
  }

  it('the "Semua" row clears status back off the query', async () => {
    const w = await mountView();

    await pickStatus(w, STATUS_LABELS.cancelled);
    expect(lastListSessionsArg().status).toBe('cancelled');

    await pickStatus(w, 'Semua');

    expect(lastListSessionsArg().status).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.status].text()).toBe('Semua');
  });

  /**
   * Exactly once — counted, not merely "called".
   *
   * `toHaveBeenCalled()` would pass on a watcher that fires twice per
   * pick (a doubled reload is a real defect on this screen: it doubles
   * the 100-row query and can land the responses out of order). An exact
   * length fails on both a double-fire and a zero-fire.
   */
  it('one pick triggers exactly one refetch', async () => {
    const w = await mountView();
    // Mount itself loads once, via useDataRefresh's onMounted.
    expect(listSessionsCalls()).toHaveLength(1);

    await pickStatus(w, STATUS_LABELS.done);
    expect(listSessionsCalls()).toHaveLength(2);

    await pickStatus(w, STATUS_LABELS.scheduled);
    expect(listSessionsCalls()).toHaveLength(3);
  });

  it('re-picking the SAME status refetches zero times', async () => {
    const w = await mountView();

    await pickStatus(w, STATUS_LABELS.done);
    expect(listSessionsCalls()).toHaveLength(2);

    // Same value written to the same ref: Vue's watcher must not fire,
    // so the API count is unchanged.
    await pickStatus(w, STATUS_LABELS.done);
    await pickStatus(w, STATUS_LABELS.done);

    expect(listSessionsCalls()).toHaveLength(2);
    expect(lastListSessionsArg().status).toBe('done');
  });

  it('leaves the sibling chips alone', async () => {
    const w = await mountView();

    await pickStatus(w, STATUS_LABELS.done);

    const chips = w.findAll('[data-testid="chip"]');
    expect(chips[CHIP.group].text()).toBe('Semua');
    expect(chips[CHIP.tutor].text()).toBe('Semua');
    expect(chips[CHIP.period].text()).toBe('Semua');
    const arg = lastListSessionsArg();
    expect(arg.learning_group_id).toBeUndefined();
    expect(arg.tutor_id).toBeUndefined();
  });
});

/**
 * Row → detail.
 *
 * The reported defect: "pada website di halaman sesi, list sesinya belum
 * ada detail sesi dan edit sesi". `GET /sessions/{id}` had shipped long
 * before, but this table offered no way to reach it — the rows carried
 * a `hover:bg-slate-50` class and no handler at all, which reads as
 * clickable and is not.
 *
 * The row is deliberately NOT ability-gated. `SessionController::show`
 * authorizes on `tutoring.session.view`; only the EDIT control inside
 * the detail is a write. Gating the row would hide a session's room,
 * tutor and notes from a staff tier entitled to read them — which is
 * why the "without manage" case below is a real assertion.
 */
describe('AdminTutoring2ScheduleView row → detail', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    grantedAbilities = ['tutoring.session.manage'];
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('opens the session detail when a row is clicked', async () => {
    const w = await mountView();

    const row = w.find('[data-testid="schedule-row"]');
    expect(row.exists()).toBe(true);

    await row.trigger('click');

    expect(push).toHaveBeenCalledWith({
      name: 'admin.tutoring2.session.detail',
      params: { id: makeSession().id },
    });
  });

  it('opens it from the keyboard too', async () => {
    const w = await mountView();

    // A <tr> is not focusable on its own and the row is the only
    // affordance here, so without `tabindex` + Enter the whole feature
    // is mouse-only.
    const row = w.find('[data-testid="schedule-row"]');
    expect(row.attributes('tabindex')).toBe('0');

    await row.trigger('keydown.enter');

    expect(push).toHaveBeenCalledTimes(1);
  });

  it('stays reachable for a role without tutoring.session.manage', async () => {
    grantedAbilities = [];
    const w = await mountView();

    await w.find('[data-testid="schedule-row"]').trigger('click');

    // Read access is not the write gate.
    expect(push).toHaveBeenCalledTimes(1);
  });
});

/**
 * `?date=YYYY-MM-DD` — the Laporan Aktivitas drill-in.
 *
 * ── What already existed, and what did not ──────────────────────────
 *
 * `SessionController::index` has supported the narrowing since BE-4:
 *
 *     ->when($request->filled('from'), … where('starts_at', '>=', from))
 *     ->when($request->filled('to'),   … where('starts_at', '<',  to))
 *
 * and `TutoringBimbelService.listSessions` has always declared
 * `from?: string; to?: string` in its params type. Neither had a
 * caller — this screen passed neither, so a report row had nowhere to
 * land. Nothing new was built server-side; this block pins the caller.
 *
 * ── The exclusive upper bound ───────────────────────────────────────
 *
 * `to` is `<`, not `<=`, so one day D is the half-open `[D, D+1)`. That
 * matches the report's `starts_at::date = D` bucketing exactly, which
 * is what stops the two screens disagreeing about which sessions belong
 * to a day. `D+1` comes from `addDays()`; a `new Date(D)` +
 * `toISOString().slice(0, 10)` round-trip is the bug the TZ block below
 * exists to catch.
 *
 * Every test in this block is RED against the shipped view: it read no
 * query at all and sent neither bound. The one that passes either way
 * is the no-`?date=` baseline — deliberately, since it is what the
 * others move away from.
 */
describe('AdminTutoring2ScheduleView ?date= drill-in', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('sends no date bounds when no ?date= is present', async () => {
    await mountView();

    const arg = lastListSessionsArg();
    expect(arg.from).toBeUndefined();
    expect(arg.to).toBeUndefined();
  });

  it('narrows the query to [D, D+1) — the exclusive bound the API wants', async () => {
    setDateQuery('2026-09-09');

    await mountView();

    const arg = lastListSessionsArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
  });

  it('carries the day across a month boundary', async () => {
    setDateQuery('2026-09-30');

    await mountView();

    expect(lastListSessionsArg().to).toBe('2026-10-01');
  });

  it('carries the day across a year boundary', async () => {
    setDateQuery('2026-12-31');

    await mountView();

    const arg = lastListSessionsArg();
    expect(arg.from).toBe('2026-12-31');
    expect(arg.to).toBe('2027-01-01');
  });

  it('leaves the other facets alone', async () => {
    setDateQuery('2026-09-09');

    await mountView();

    const arg = lastListSessionsArg();
    expect(arg.status).toBeUndefined();
    expect(arg.learning_group_id).toBeUndefined();
    expect(arg.tutor_id).toBeUndefined();
  });

  it('composes with a facet picked afterwards, in ONE refetch', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();
    expect(listSessionsCalls()).toHaveLength(1);

    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(listSessionsCalls()).toHaveLength(2);
    const arg = lastListSessionsArg();
    expect(arg.learning_group_id).toBe('gr-2');
    // The day must survive the pick — narrowing by group must not widen
    // the window back to "every day".
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
  });

  it('drops a malformed ?date= rather than forwarding it to the API', async () => {
    // A value the API can never match would render as "no sessions" —
    // a lie about the data, rather than a visibly ignored parameter.
    for (const bad of ['2026-9-9', '2026-13-01', 'kemarin', '']) {
      vi.clearAllMocks();
      setDateQuery(bad);

      await mountView();

      const arg = lastListSessionsArg();
      expect(arg.from, `?date=${bad}`).toBeUndefined();
      expect(arg.to, `?date=${bad}`).toBeUndefined();
    }
  });

  it('follows the URL when it changes under a mounted view', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();

    // Back/Forward, or a second drill-in from the report, reuses this
    // same component instance.
    routeQuery.date = '2026-09-10';
    await flushPromises();

    const arg = lastListSessionsArg();
    expect(arg.from).toBe('2026-09-10');
    expect(arg.to).toBe('2026-09-11');
  });
});

/**
 * The day must survive the hop as the SAME calendar day.
 *
 * `addDays` never hands the string to `Date`, so both bounds stay on
 * the local calendar. The premise is asserted inside each test so
 * neither can pass vacuously on a UTC CI runner — same pattern as
 * `local-date.spec.ts`.
 */
describe('AdminTutoring2ScheduleView ?date= round-trip in WIB', () => {
  const REAL_TZ = process.env.TZ;

  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });
  afterEach(() => {
    process.env.TZ = REAL_TZ;
  });

  it('asks for 9 Sep, not 8 Sep, for a WIB admin', async () => {
    process.env.TZ = 'Asia/Jakarta';
    expect(new Date('2026-09-09T00:00:00Z').getTimezoneOffset()).toBe(-420);
    // The trap this is guarding: local midnight on the 9th serialises
    // through UTC as the 8th, so a `toISOString().slice(0, 10)` step
    // anywhere in the chain hands a WIB reader the previous day.
    expect(new Date(2026, 8, 9).toISOString().slice(0, 10)).toBe('2026-09-08');

    setDateQuery('2026-09-09');
    await mountView();

    const arg = lastListSessionsArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
  });

  it('is correct in a NEGATIVE offset too, where the naive parse loses a day', async () => {
    process.env.TZ = 'America/New_York'; // UTC-4 in September
    const utcParsed = new Date('2026-09-09');
    expect(utcParsed.getTimezoneOffset()).toBe(240);
    expect(utcParsed.getDate()).toBe(8); // the trap: 8 Sep, not 9 Sep

    setDateQuery('2026-09-09');
    await mountView();

    const arg = lastListSessionsArg();
    expect(arg.from).toBe('2026-09-09');
    expect(arg.to).toBe('2026-09-10');
  });
});

/**
 * The context bar.
 *
 * A filter the reader did not set on this screen has to say so, and has
 * to be undoable. Deliberately NOT an <AppFilterChip>: that chip has no
 * menu of its own, and a chip whose only behaviour is clearing itself is
 * the dead-control pattern !1191 spent four MRs removing from exactly
 * these screens.
 */
const BAR = '[data-testid="schedule-date-filter"]';
const BAR_CLEAR = '[data-testid="schedule-date-filter-clear"]';

describe('AdminTutoring2ScheduleView date filter bar', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    setDateQuery();
    (TutoringBimbelService.listSessions as any).mockResolvedValue({
      items: [makeSession()],
      pagination: undefined,
    });
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('is absent when no day is applied', async () => {
    const w = await mountView();

    expect(w.find(BAR).exists()).toBe(false);
  });

  it('names the day in words, not as the wire string', async () => {
    process.env.TZ = 'Asia/Jakarta';
    setDateQuery('2026-09-09');

    const w = await mountView();

    expect(w.find(BAR).exists()).toBe(true);
    expect(w.find(BAR).text()).toContain('9 September 2026');
    expect(w.find(BAR).text()).not.toContain('2026-09-09');
  });

  it('clearing it widens the query back to every day', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();
    expect(lastListSessionsArg().from).toBe('2026-09-09');

    await w.find(BAR_CLEAR).trigger('click');
    await flushPromises();

    const arg = lastListSessionsArg();
    expect(arg.from).toBeUndefined();
    expect(arg.to).toBeUndefined();
    expect(w.find(BAR).exists()).toBe(false);
  });

  it('clearing it also strips ?date= off the URL', async () => {
    setDateQuery('2026-09-09');
    const w = await mountView();

    await w.find(BAR_CLEAR).trigger('click');

    // Otherwise a refresh silently re-applies the filter the reader
    // just dismissed. `replace`, not `push` — dismissing a filter is
    // not a place in history worth returning to.
    expect(replace).toHaveBeenCalledTimes(1);
    expect(push).not.toHaveBeenCalled();
    const arg = replace.mock.calls[0][0];
    expect(arg.name).toBe('admin.tutoring2.schedule');
    expect(arg.query.date).toBeUndefined();
  });

  it('keeps the sibling query params it did not own', async () => {
    setDateQuery('2026-09-09');
    routeQuery.tab = 'sesi';
    const w = await mountView();

    await w.find(BAR_CLEAR).trigger('click');

    expect(replace.mock.calls[0][0].query).toEqual({ tab: 'sesi' });
  });
});
