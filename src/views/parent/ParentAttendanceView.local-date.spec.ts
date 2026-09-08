/**
 * Kehadiran (wali) — the KPI period must default to the LOCAL calendar
 * month.
 *
 * This is the `slice(0, 7)` sibling of the documented `slice(0, 10)`
 * rule, and it was live: `const month = ref(new Date().toISOString()
 * .slice(0, 7))` returns the UTC month, so between 00:00 and 06:59 WIB
 * on the 1st of any month a wali opened this screen and got LAST month
 * — its name in the period chip, its rows counted in the KPI ring, and
 * `previousMonth` shifted back in lockstep so the trend arrow compared
 * the two wrong months against each other.
 *
 * A month boundary makes this sharper than the daily case: the screen
 * is not one day stale, it is a whole reporting period out, and the
 * numbers next to the wrong name look perfectly plausible.
 *
 * The TZ is pinned to Asia/Jakarta and the OLD form's output asserted
 * before the new one's — in UTC the two agree and the spec would pass
 * against the unfixed code.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterAll, afterEach, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import { ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentAttendanceView from './ParentAttendanceView.vue';
import AttendanceRingKpi from '@/components/feature/AttendanceRingKpi.vue';
import idMessages from '@/locales/id.json';

/**
 * Three days in August, one in September. If the view lands on the
 * wrong month the ring does not merely mislabel itself — it counts a
 * different set of rows, which is what makes this a data bug.
 */
const ROWS = [
  { date: '2026-08-10', status: 'hadir' },
  { date: '2026-08-11', status: 'hadir' },
  { date: '2026-08-12', status: 'sakit' },
  { date: '2026-09-01', status: 'hadir' },
];

vi.mock('@/composables/useChildPicker', () => ({
  useChildPicker: () => ({
    children: ref([{ student_id: 'child-1', name: 'Rani', class_name: '7A' }]),
    activeChildId: ref('child-1'),
    hasOverdueBills: ref(false),
    activeChild: () => ({ student_id: 'child-1', name: 'Rani', class_name: '7A' }),
    setActive: vi.fn(),
    refresh: vi.fn(),
  }),
}));

vi.mock('@/composables/useParentAttendance', () => ({
  useParentAttendance: () => ({
    get: () => null,
    fetchYear: vi.fn().mockResolvedValue(ROWS),
    patch: vi.fn(),
    clearAll: vi.fn(),
  }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

vi.mock('@/stores/academic-year', () => ({
  useAcademicYearStore: () => ({ selectedYearId: 'ay-1', selectedYear: { year: '2026/2027' } }),
}));

vi.mock('@/services/parent.service', () => ({
  ParentService: {
    markAttendanceRead: vi.fn().mockResolvedValue(undefined),
    markPresenceAsRead: vi.fn().mockResolvedValue(undefined),
  },
}));

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
}));

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: { id: idMessages },
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(ParentAttendanceView, {
    global: {
      plugins: [makeI18n()],
      stubs: { teleport: true },
    },
  });
  await flushPromises();
  return w;
}

/** Props the KPI ring is actually rendered with. */
function ringProps(w: unknown) {
  return w.findComponent(AttendanceRingKpi).props();
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
});

describe('Kehadiran wali · KPI period is the LOCAL calendar month', () => {
  const REAL_TZ = process.env.TZ;

  beforeAll(() => {
    process.env.TZ = 'Asia/Jakarta';
  });
  afterAll(() => {
    process.env.TZ = REAL_TZ;
  });

  it('opens on September at 00:30 WIB on 1 Sep, not on August', async () => {
    // 2026-08-31T17:30Z === 1 Sep 2026, 00:30 WIB.
    vi.setSystemTime(new Date('2026-08-31T17:30:00Z'));

    // Premise guards — without these the spec is vacuous on a UTC runner.
    expect(new Date().getTimezoneOffset()).toBe(-420);
    expect(new Date().toISOString().slice(0, 7)).toBe('2026-08'); // the buggy form

    const w = await mountView();

    // The name the wali reads…
    expect(ringProps(w).periodLabel).toContain('September 2026');
    expect(ringProps(w).periodLabel).not.toContain('Agustus');

    // …and the rows behind it. September holds exactly one entry;
    // August's three must not be counted here.
    expect(ringProps(w).schoolDays).toBe(1);
    expect(ringProps(w).present).toBe(1);
    expect(ringProps(w).sakit).toBe(0);
  });

  it('still counts August when the local clock really is in August', async () => {
    // 31 Aug 2026, 23:30 WIB — one hour earlier, genuinely August.
    vi.setSystemTime(new Date('2026-08-31T16:30:00Z'));

    const w = await mountView();

    expect(ringProps(w).periodLabel).toContain('Agustus 2026');
    expect(ringProps(w).schoolDays).toBe(3);
    expect(ringProps(w).sakit).toBe(1);
  });

  it('rolls the year over at 00:30 WIB on 1 Jan', async () => {
    // 2026-12-31T17:30Z === 1 Jan 2027, 00:30 WIB. The UTC form reports
    // the wrong YEAR here, so the academic-year framing goes with it.
    vi.setSystemTime(new Date('2026-12-31T17:30:00Z'));
    expect(new Date().toISOString().slice(0, 7)).toBe('2026-12'); // the buggy form

    const w = await mountView();

    expect(ringProps(w).periodLabel).toContain('Januari 2027');
  });
});
