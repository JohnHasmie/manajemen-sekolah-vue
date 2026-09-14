/**
 * AdminClassActivityView — filter chips must LOOK applied once they ARE
 * applied.
 *
 * ── The defect this pins ──
 *
 * The Kelas / Mapel / Guru chips passed `:is-active="!!classFilter"`.
 * `AppFilterChip` declares the prop as `active`, never `isActive`, so
 * Vue did not match the binding as a prop at all: it fell through
 * `$attrs` onto the chip's root <button> as a literal, unstyled
 * `is-active="true"` DOM attribute, while the real `active` prop sat at
 * its `withDefaults` value of `false`. The filter applied and refetched
 * correctly — only the styling never rendered, so an admin could not
 * tell a filtered list from an unfiltered one.
 *
 * `vue-tsc --build --force` is blind to this: the repo sets no
 * `vueCompilerOptions`, so Volar's `checkUnknownProps` defaults off and
 * an undeclared attribute is legal by design (it is indistinguishable
 * from deliberate fall-through). The baseline type-check passes with
 * all ten misspellings present. A test is therefore the only guard.
 *
 * ── Anti-vacuity notes ──
 *
 * 1. <AppFilterChip> and <PageFilterToolbar> are REAL. This is the
 *    whole point: ~30 specs in this repo stub AppFilterChip, and every
 *    stub swallows `:is-active` exactly the way the real component
 *    does, so a stubbed spec is structurally incapable of catching
 *    this. The richest stub in the repo even declares `active` but
 *    never renders it into a class.
 * 2. The filter is applied through the DOM — click the chip, click the
 *    option inside the real <Modal> — never by poking `w.vm`.
 * 3. Both directions are asserted (inert before, active after), so a
 *    chip hardcoded to `:active="true"` would fail the "before" half.
 * 4. `.classes()` returns exact tokens, so 'border-brand-cobalt' cannot
 *    accidentally match the idle branch's 'hover:border-brand-cobalt'.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminClassActivityView from './AdminClassActivityView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import { ClassActivityService } from '@/services/class-activity.service';
import { ClassroomService } from '@/services/classrooms.service';
import { SubjectService } from '@/services/subjects.service';
import { TeacherService } from '@/services/teachers.service';
import idMessages from '@/locales/id.json';

vi.mock('@/services/class-activity.service', () => ({
  ClassActivityService: {
    getAdminSummary: vi.fn(),
    getDetail: vi.fn(),
    listSubmissions: vi.fn(),
  },
}));
vi.mock('@/services/classrooms.service', () => ({
  ClassroomService: { list: vi.fn() },
}));
vi.mock('@/services/subjects.service', () => ({
  SubjectService: { list: vi.fn() },
}));
vi.mock('@/services/teachers.service', () => ({
  TeacherService: { list: vi.fn() },
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

/** The four classes AppFilterChip's active branch adds. */
const ACTIVE_CLASSES = [
  'bg-role-admin-soft',
  'border-brand-cobalt',
  'ring-2',
  'ring-brand-cobalt/30',
];

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

  vi.mocked(ClassActivityService.getAdminSummary).mockResolvedValue({
    items: [],
    kpi: { total: 0, this_week: 0, pending_submissions: 0 },
  });
  vi.mocked(ClassroomService.list).mockResolvedValue({
    items: [
      { id: 'cl-1', name: '7A' },
      { id: 'cl-2', name: '8B' },
    ],
  });
  vi.mocked(SubjectService.list).mockResolvedValue({
    items: [{ id: 'sb-1', name: 'Matematika' }],
  });
  vi.mocked(TeacherService.list).mockResolvedValue({
    items: [{ id: 'tc-1', name: 'Pak Rahmat' }],
  });

  const w = mount(AdminClassActivityView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        // `teleport: true` renders <Modal>'s <Teleport to="body">
        // inline so its option buttons are queryable. AppFilterChip and
        // PageFilterToolbar are deliberately NOT stubbed.
        teleport: true,
        BrandPageHeader: true,
        KpiStripCards: true,
        ActivityCard: true,
        ActivityDetailModal: true,
        SegmentedControl: true,
        Toast: true,
        NavIcon: true,
        AsyncView: { props: ['state'], template: '<div><slot /></div>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Look chips up by label so a chip reorder cannot fool the test. */
function chipByLabel(w, label) {
  const chip = w
    .findAllComponents(AppFilterChip)
    .find((c) => c.props('label') === label);
  expect(chip, `no chip labelled "${label}"`).toBeTruthy();
  return chip;
}

const chipClasses = (chip) => chip.find('button').classes();

describe('AdminClassActivityView filter chips reflect the applied filter', () => {
  beforeEach(() => vi.clearAllMocks());

  it('KELAS chip goes from inert to cobalt-ringed when a class is picked', async () => {
    const w = await mountView();

    // ── before ──
    const before = chipClasses(chipByLabel(w, 'KELAS'));
    expect(before).toContain('border-slate-200');
    expect(before).not.toContain('border-brand-cobalt');

    // ── apply the filter entirely through the DOM ──
    await chipByLabel(w, 'KELAS').find('button').trigger('click');
    await flushPromises();

    const option = w
      .findAll('button')
      .find((b) => b.text() === '7A');
    expect(option, 'class picker did not offer "7A"').toBeTruthy();
    await option.trigger('click');
    await flushPromises();

    // ── after ──
    const chip = chipByLabel(w, 'KELAS');
    // Sanity: the filter really did apply, so a failure below is about
    // styling alone and not about a picker that silently did nothing.
    expect(chip.props('value')).toBe('7A');

    const after = chipClasses(chip);
    for (const c of ACTIVE_CLASSES) expect(after).toContain(c);
    expect(after).not.toContain('border-slate-200');
  });

  it('leaves the untouched MAPEL and GURU chips inert', async () => {
    const w = await mountView();

    await chipByLabel(w, 'KELAS').find('button').trigger('click');
    await flushPromises();
    await w
      .findAll('button')
      .find((b) => b.text() === '7A')
      .trigger('click');
    await flushPromises();

    for (const label of ['MAPEL', 'GURU']) {
      const classes = chipClasses(chipByLabel(w, label));
      expect(classes, `${label} chip should still be inert`).toContain(
        'border-slate-200',
      );
      expect(classes).not.toContain('ring-2');
    }
  });

  it('binds `active` as a prop, not as a stray DOM attribute', async () => {
    // Direct pin on the root cause. With `:is-active` the prop stayed
    // false and the button carried a dead is-active="..." attribute;
    // both halves below fail in that world.
    const w = await mountView();

    await chipByLabel(w, 'KELAS').find('button').trigger('click');
    await flushPromises();
    await w
      .findAll('button')
      .find((b) => b.text() === '7A')
      .trigger('click');
    await flushPromises();

    const chip = chipByLabel(w, 'KELAS');
    expect(chip.props('active')).toBe(true);
    expect(chip.find('button').attributes('is-active')).toBeUndefined();
  });
});
