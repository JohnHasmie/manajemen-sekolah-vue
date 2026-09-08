/**
 * RekapTab (Kehadiran Siswa · Rekap & Laporan) — the SECOND
 * `<input type="month">` in the app, found by sweeping for the control
 * behind the tutor Honor report rather than fixing only the screen that
 * was reported. Same defect, same cause: desktop Safari renders no
 * picker for `type="month"` and degrades it to a text box, so an admin
 * on macOS could not browse months here either.
 *
 * This toolbar is shaped differently from the Honor page — the month
 * sits between prev/next stepper arrows — so it uses <MonthPickerModal>
 * directly instead of the <MonthPickerField> wrapper.
 *
 * ── What this file locks ──
 *
 * 1. The month reads as a human label on a button, and opens the picker.
 * 2. Picking reloads EXACTLY ONCE with the new month's end date.
 * 3. The stepper arrows honour the SAME bounds as the picker. Before
 *    this, "next" walked forward without limit; a stepper that could
 *    reach a month the picker refuses to show would mean the two
 *    controls disagree about what is selectable.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import RekapTab from './RekapTab.vue';
import { AttendanceService } from '@/services/attendance.service';
import { ClassroomService } from '@/services/classrooms.service';
import idMessages from '@/locales/id.json';

vi.mock('@/services/attendance.service', () => ({
  AttendanceService: {
    getStudentHeatmap: vi.fn(),
    downloadMonthlyReport: vi.fn(),
  },
}));

vi.mock('@/services/classrooms.service', () => ({
  ClassroomService: { list: vi.fn() },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

vi.mock('@/stores/me', () => ({
  useMeStore: () => ({ can: () => true }),
}));

vi.mock('@/stores/academic-year', () => ({
  useAcademicYearStore: () => ({ selectedYearId: 'ay-1', selectedYear: { year: '2026/2027' } }),
}));

const TRIGGER = '[data-testid="rekap-month-trigger"]';
const MODAL = '[data-testid="month-picker-modal"]';
const CELL = '[data-testid="month-picker-cell"]';
const PREV = 'button[aria-label="Bulan sebelumnya"]';
const NEXT = 'button[aria-label="Bulan berikutnya"]';

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

async function mountTab() {
  setActivePinia(createPinia());
  vi.mocked(AttendanceService.getStudentHeatmap).mockResolvedValue({
    students: [],
    start_date: '2026-08-16',
    end_date: '2026-09-15',
  });
  vi.mocked(ClassroomService.list).mockResolvedValue({ items: [], pagination: undefined });

  const w = mount(RekapTab, {
    global: {
      plugins: [makeI18n()],
      stubs: { teleport: true, SegmentedControl: true },
    },
  });
  await flushPromises();
  return w;
}

/** The `end_date` of every heatmap request, oldest first. */
function requestedEndDates() {
  return vi.mocked(AttendanceService.getStudentHeatmap).mock.calls.map((c) => c[0]?.end_date);
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
  vi.setSystemTime(new Date(2026, 8, 15, 12, 0, 0)); // 15 Sep 2026, LOCAL
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Rekap kehadiran · period picker', () => {
  it('renders the month as a labeled button, with no typeable month input left', async () => {
    const w = await mountTab();
    const trigger = w.get(TRIGGER);
    expect(trigger.element.tagName).toBe('BUTTON');
    expect(trigger.text()).toBe('September 2026');
    expect(w.find('input[type="month"]').exists()).toBe(false);
  });

  it('opens the picker on click', async () => {
    const w = await mountTab();
    expect(w.find(MODAL).exists()).toBe(false);
    await w.get(TRIGGER).trigger('click');
    expect(w.find(MODAL).exists()).toBe(true);
    expect(w.findAll(CELL)).toHaveLength(12);
  });

  it('reloads EXACTLY ONCE with the picked month', async () => {
    const w = await mountTab();
    expect(requestedEndDates()).toHaveLength(1);

    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[2].trigger('click'); // March 2026
    await flushPromises();

    expect(vi.mocked(AttendanceService.getStudentHeatmap)).toHaveBeenCalledTimes(2);
    // A past month uses its own last day, not "today".
    expect(requestedEndDates().at(-1)).toBe('2026-03-31');
    expect(w.get(TRIGGER).text()).toBe('Maret 2026');
  });

  it('does not reload when the already-selected month is re-picked', async () => {
    const w = await mountTab();
    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[8].trigger('click'); // September — already current
    await flushPromises();
    expect(vi.mocked(AttendanceService.getStudentHeatmap)).toHaveBeenCalledTimes(1);
  });

  it('steps back a month through the arrow', async () => {
    const w = await mountTab();
    await w.get(PREV).trigger('click');
    await flushPromises();
    expect(w.get(TRIGGER).text()).toBe('Agustus 2026');
    expect(requestedEndDates().at(-1)).toBe('2026-08-31');
  });

  it('disables the forward arrow at the current month — the picker\'s ceiling', async () => {
    const w = await mountTab();
    // Default month IS the ceiling, so forward must be closed.
    expect(w.get(NEXT).attributes('disabled')).toBeDefined();
    expect(w.get(PREV).attributes('disabled')).toBeUndefined();
  });

  it('re-opens the forward arrow once the month is no longer the ceiling', async () => {
    const w = await mountTab();
    await w.get(PREV).trigger('click');
    await flushPromises();
    expect(w.get(NEXT).attributes('disabled')).toBeUndefined();
  });

  it('the stepper cannot reach a month the picker refuses to offer', async () => {
    const w = await mountTab();
    // Hammer forward; the clamp must hold at the current month.
    await w.get(NEXT).trigger('click');
    await w.get(NEXT).trigger('click');
    await flushPromises();
    expect(w.get(TRIGGER).text()).toBe('September 2026');

    await w.get(TRIGGER).trigger('click');
    expect(w.findAll(CELL)[9].attributes('disabled')).toBeDefined(); // Oct 2026
  });
});

/**
 * Regression: the recap window was built with `toISOString().slice(0, 10)`,
 * i.e. the UTC day. Two separate wrong answers came out of it in WIB,
 * and this tab is the report an admin uses to decide a student is absent.
 *
 * This block pins TZ to Asia/Jakarta so the assertions are about the
 * BUG, not about whatever timezone the runner happens to be in.
 */
describe('Rekap kehadiran · window end-date is a LOCAL day', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  it('asks for the last day of a past month, not the day before it', async () => {
    vi.setSystemTime(new Date('2026-09-15T05:00:00Z')); // 12:00 WIB
    const w = await mountTab();

    await w.get(TRIGGER).trigger('click');
    await w.findAll(CELL)[2].trigger('click'); // March 2026 — a 31-day month
    await flushPromises();

    // `new Date(2026, 3, 0)` is 31 Mar at LOCAL midnight; the UTC slice
    // rolled that back to the 30th and the recap lost a whole school day.
    expect(requestedEndDates().at(-1)).toBe('2026-03-31');
  });

  it('asks for TODAY at 01:30 WIB, when UTC still says yesterday', async () => {
    // 2026-09-14T18:30Z === 15 Sep 2026, 01:30 WIB. This is the original
    // MTs Muhammadiyah window: before 07:00 the UTC slice returns the
    // PREVIOUS day, hiding the day's check-ins from the report.
    vi.setSystemTime(new Date('2026-09-14T18:30:00Z'));

    // Premise guard — a spec that ran in UTC would be vacuous.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 10)).toBe('2026-09-14'); // the buggy form

    await mountTab();
    expect(requestedEndDates().at(-1)).toBe('2026-09-15'); // the correct one
  });
});
