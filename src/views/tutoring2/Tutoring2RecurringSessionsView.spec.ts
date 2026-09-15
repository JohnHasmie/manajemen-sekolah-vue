/**
 * Wire contract for Tutoring2RecurringSessionsView.
 *
 * The screen's whole job is one POST. Every field name and shape below
 * is read off `StoreRecurringSessionsRequest::rules()` and
 * `CreateRecurringSessionsAction` on the backend `main`, not off the
 * previous view's source — the v1 form posted a DIFFERENT set
 * (`group_id`, `start_date`, `end_date`, `time`, `duration_minutes`)
 * and a field the FormRequest does not declare is dropped silently
 * rather than refused, which is exactly the failure a spec written
 * against the UI instead of the contract cannot see.
 *
 *   learning_group_id  required uuid
 *   tutor_id           nullable uuid   ← deliberately NOT sent; see below
 *   weekdays           required array, min 1, each int between 1 and 7
 *   start_time         required, /^\d{2}:\d{2}$/
 *   end_time           required, /^\d{2}:\d{2}$/   (strictly after start)
 *   from_date          required date
 *   to_date            required date, after_or_equal:from_date
 *   room               nullable string max 64
 *   materials_note     nullable string max 4000
 *
 * `tutor_id` is optional server-side and defaults to `$group->tutor_id`
 * inside the action. The admin screen does not send it: the group
 * already owns that answer, and a second control for it would be a
 * second source of truth. The assertion below pins the ABSENCE, because
 * "we chose not to send it" and "we forgot" look identical in a diff.
 *
 * The date fields are asserted against LOCAL calendar dates, never
 * `toISOString()`. A UTC round-trip moves a WIB admin's early-morning
 * boundary date to the previous day — the bug `toLocalYmd` exists to
 * prevent.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import Tutoring2RecurringSessionsView from './Tutoring2RecurringSessionsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listGroups: vi.fn(),
    createRecurringSessions: vi.fn(),
  },
}));

const toastError = vi.fn();
const toastSuccess = vi.fn();
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: toastSuccess, error: toastError }),
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
}));

let activeRole = 'admin';
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({
    get activeRole() {
      return activeRole;
    },
  }),
}));

const GROUPS = [
  { id: 'aa000000-0000-4000-8000-000000000001', name: 'UTBK Pagi A', status: 'active' },
  { id: 'aa000000-0000-4000-8000-000000000002', name: 'SMP Sore B', status: 'active' },
];

/**
 * The REAL id locale, not a hand-written fixture. A spec with inline
 * messages passes even when the key it renders was never added to
 * `locales/id.json`, which is the half of "add the string to both
 * locales" that silently rots.
 */
function makeI18n() {
  const id = JSON.parse(
    readFileSync(join(__dirname, '../../locales/id.json'), 'utf-8'),
  );
  return createI18n({ legacy: false, locale: 'id', fallbackLocale: 'id', messages: { id } });
}

async function mountView() {
  setActivePinia(createPinia());
  TutoringBimbelService.listGroups.mockResolvedValue({ items: GROUPS });
  TutoringBimbelService.createRecurringSessions.mockResolvedValue([{ id: 's1' }, { id: 's2' }]);

  const w = mount(Tutoring2RecurringSessionsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        NavIcon: true,
        Button: {
          props: ['loading', 'variant', 'size'],
          template: '<button :type="$attrs.type" @click="$emit(\'click\')"><slot /></button>',
        },
        // Render the default slot so the form is in the DOM; the real
        // AsyncView would hide it behind its own loading state.
        AsyncView: {
          props: ['state'],
          template: '<div><slot :data="state?.data ?? []" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** The single payload handed to the service by the last submit. */
function lastPayload() {
  const calls = TutoringBimbelService.createRecurringSessions.mock.calls;
  expect(calls.length, 'the form did not POST at all').toBe(1);
  return calls[0][0];
}

async function fillAndSubmit(w, opts = {}) {
  const {
    group = GROUPS[0].id,
    from = '2026-09-01',
    to = '2026-09-30',
    start = '16:00',
    room = 'Ruang A',
    note = 'Bab 3 trigonometri',
  } = opts;

  await w.find('#recurring-group').setValue(group);
  await w.find('#recurring-from').setValue(from);
  await w.find('#recurring-to').setValue(to);
  await w.find('#recurring-time').setValue(start);
  if (room !== null) await w.find('#recurring-room').setValue(room);
  if (note !== null) await w.find('#recurring-materials').setValue(note);

  await w.find('[data-testid="recurring-sessions-form"]').trigger('submit');
  await flushPromises();
}

describe('Tutoring2RecurringSessionsView — POST /tutoring-v2/sessions/recurring', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    activeRole = 'admin';
  });

  it('sends exactly the keys StoreRecurringSessionsRequest declares', async () => {
    const w = await mountView();
    await fillAndSubmit(w);

    // Not a subset match: an EXTRA key is the v1-vocabulary regression
    // this guards (`group_id`, `start_date`, `duration_minutes` …),
    // and it would be dropped by the FormRequest without complaint.
    expect(Object.keys(lastPayload()).sort()).toEqual([
      'end_time',
      'from_date',
      'learning_group_id',
      'materials_note',
      'room',
      'start_time',
      'to_date',
      'weekdays',
    ]);
  });

  it('does not send tutor_id — the action defaults it from the group', async () => {
    const w = await mountView();
    await fillAndSubmit(w);

    expect('tutor_id' in lastPayload()).toBe(false);
  });

  it('sends the group id and the local from/to dates verbatim', async () => {
    const w = await mountView();
    await fillAndSubmit(w, { from: '2026-09-01', to: '2026-09-30' });

    const p = lastPayload();
    expect(p.learning_group_id).toBe(GROUPS[0].id);
    // Exactly what was typed: no timezone round-trip on the way out.
    expect(p.from_date).toBe('2026-09-01');
    expect(p.to_date).toBe('2026-09-30');
  });

  it('sends weekdays as ISO ints (1=Mon…7=Sun), sorted and non-empty', async () => {
    const w = await mountView();
    await fillAndSubmit(w);

    const { weekdays } = lastPayload();
    expect(Array.isArray(weekdays)).toBe(true);
    expect(weekdays.length).toBeGreaterThan(0);
    expect(weekdays.every((d) => Number.isInteger(d) && d >= 1 && d <= 7)).toBe(true);
    expect([...weekdays].sort((a, b) => a - b)).toEqual(weekdays);
  });

  it('derives end_time from the duration as HH:MM, strictly after start_time', async () => {
    const w = await mountView();
    // Default duration is 90 minutes.
    await fillAndSubmit(w, { start: '16:00' });

    const p = lastPayload();
    expect(p.start_time).toBe('16:00');
    expect(p.end_time).toBe('17:30');
    // The regex both the FormRequest and the action apply.
    expect(p.start_time).toMatch(/^\d{2}:\d{2}$/);
    expect(p.end_time).toMatch(/^\d{2}:\d{2}$/);
    expect(p.end_time > p.start_time).toBe(true);
  });

  it('sends null, not "", for an empty room / materials note', async () => {
    const w = await mountView();
    await fillAndSubmit(w, { room: '', note: '' });

    const p = lastPayload();
    // `nullable` accepts null; an empty string would also pass, but
    // storing "" as a room is a value nobody asked for.
    expect(p.room).toBeNull();
    expect(p.materials_note).toBeNull();
  });

  it('refuses to POST when no group is picked', async () => {
    const w = await mountView();
    await fillAndSubmit(w, { group: '' });

    expect(TutoringBimbelService.createRecurringSessions).not.toHaveBeenCalled();
    expect(toastError).toHaveBeenCalled();
  });

  it('refuses to POST when the duration would cross midnight', async () => {
    const w = await mountView();
    // 23:30 + the default 90 minutes lands past midnight, which
    // CreateRecurringSessionsAction rejects (end must be after start on
    // the SAME calendar day).
    await fillAndSubmit(w, { start: '23:30' });

    expect(TutoringBimbelService.createRecurringSessions).not.toHaveBeenCalled();
    expect(toastError).toHaveBeenCalled();
  });

  it('refuses to POST an inverted date range', async () => {
    const w = await mountView();
    await fillAndSubmit(w, { from: '2026-09-30', to: '2026-09-01' });

    expect(TutoringBimbelService.createRecurringSessions).not.toHaveBeenCalled();
    expect(toastError).toHaveBeenCalled();
  });

  it('reports the number of sessions the server actually created', async () => {
    const w = await mountView();
    await fillAndSubmit(w);

    // The endpoint returns the created rows; the count is their length,
    // never a client-side prediction. The service mock resolves TWO
    // rows while the form's own preview for Sep 2026 Mon+Wed is nine,
    // so a view that echoed its prediction instead of the response
    // fails here. (`toContain('2')` would NOT catch that — the rendered
    // form is full of 2026 dates.)
    expect(toastSuccess).toHaveBeenCalled();
    expect(w.text()).toContain('2 sesi berhasil dibuat.');
  });
});

describe('Tutoring2RecurringSessionsView — role adaptation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('serves the same form to a tutor whose tenant granted the key', async () => {
    activeRole = 'teacher';
    const w = await mountView();
    await fillAndSubmit(w);

    // One view, two routes: the payload must not depend on who reached
    // it. A role-specific branch here would be the drift that splitting
    // the file into two copies causes.
    expect(Object.keys(lastPayload()).sort()).toEqual([
      'end_time',
      'from_date',
      'learning_group_id',
      'materials_note',
      'room',
      'start_time',
      'to_date',
      'weekdays',
    ]);
  });
});
