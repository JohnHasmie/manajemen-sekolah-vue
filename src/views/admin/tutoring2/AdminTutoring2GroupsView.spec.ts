/**
 * Vitest contract spec for AdminTutoring2GroupsView.
 *
 * Pins the Program / Term / Tutor filter chips, which shipped inert: the
 * click handler was `@click="programFilter = ''"`, i.e. it only ever
 * CLEARED to the "Semua" default and no menu existed behind it, so a
 * bimbel admin on prod reported "semua button/filter tdk berfungsi".
 * The chip also rendered `shortId(programFilter)` — an id fragment — so
 * even a working filter would have read as gibberish.
 *
 * Each test below fails against that old template:
 *
 *   1. opens a picker      — clicking a chip must OPEN an option list.
 *                            Old code opened nothing.
 *   2. program / term /    — picking an option must re-call listGroups
 *      tutor apply           with the matching id param, proving the
 *                            list actually narrows.
 *   3. names, not UUIDs    — the chip must read the option's NAME.
 *   4. "Semua" clears      — the reset row must drop the param again.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body and would escape the wrapper);
 * the option rows clicked here are the ones an admin clicks.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2GroupsView from './AdminTutoring2GroupsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTermsService } from '@/services/tutoring2/terms';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listGroups: vi.fn(),
    listPrograms: vi.fn(),
    createGroup: vi.fn(),
  },
}));

/**
 * Ability the "+ Kelompok baru" CTA is gated on. Mutable so the
 * "hidden without the grant" case can flip it per test.
 */
let grantedAbilities: string[] = ['tutoring.group.manage'];

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (ability: string) => grantedAbilities.includes(ability),
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

const toastSuccess = vi.fn();
const toastError = vi.fn();
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: toastSuccess, error: toastError, info: vi.fn() }),
}));

vi.mock('@/services/tutoring2/terms', () => ({
  TutoringTermsService: { list: vi.fn() },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

const routerPush = vi.fn();
vi.mock('vue-router', () => ({ useRouter: () => ({ push: routerPush }) }));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

function makeGroup(overrides = {}) {
  return {
    id: 'gr-1',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    term_id: 'tm-1',
    term_name: 'Gelombang 1',
    tutor_id: 'tu-1',
    tutor_name: 'Pak Rahmat',
    name: 'UTBK Pagi A',
    kind: 'group',
    kind_label: 'Grup',
    capacity: 12,
    room: null,
    status: 'active',
    status_label: 'Aktif',
    seated_count: 8,
    ...overrides,
  };
}

const PROGRAMS = [
  { id: 'pr-1', name: 'Intensif UTBK', grade_level: '12', status: 'active' },
  { id: 'pr-2', name: 'Reguler SMP', grade_level: '8', status: 'active' },
];
const TERMS = [
  { id: 'tm-1', name: 'Gelombang 1', start_date: null, end_date: null, is_current: true, status: 'active', status_label: 'Aktif' },
  { id: 'tm-2', name: 'Gelombang 2', start_date: null, end_date: null, is_current: false, status: 'draft', status_label: 'Draf' },
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
            program: 'Program',
            term: 'Term',
            tutor: 'Tutor',
            gradeLevel: 'Jenjang',
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
  const w = mount(AdminTutoring2GroupsView, {
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
        // `disabled`, emits `click`. Keeping `value` in the DOM is what
        // lets the "names, not UUIDs" assertions read the chip.
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
  return w;
}

/** Chips render in template order: program, term, tutor. */
const CHIP = { program: 0, term: 1, tutor: 2 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function lastListGroupsArg() {
  const calls = (TutoringBimbelService.listGroups as any).mock.calls;
  return calls[calls.length - 1][0];
}

describe('AdminTutoring2GroupsView filter chips', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({
      items: [makeGroup()],
      pagination: undefined,
    });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
    (TutoringTermsService.list as any).mockResolvedValue({ items: TERMS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('loads all three option lists on mount', async () => {
    await mountView();

    expect(TutoringBimbelService.listPrograms).toHaveBeenCalledTimes(1);
    expect(TutoringTermsService.list).toHaveBeenCalledTimes(1);
    expect(TutoringTutorsService.list).toHaveBeenCalledTimes(1);
  });

  it('chips start at "Semua" and are enabled once options arrive', async () => {
    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips).toHaveLength(3);
    for (const chip of chips) {
      expect(chip.text()).toBe('Semua');
      expect(chip.attributes('disabled')).toBeUndefined();
    }
  });

  it('clicking a chip OPENS a picker listing the options by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — this is the regression: the old
    // handler set the filter to '' and opened nothing at all.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    // "Semua" reset row + one row per program, by NAME.
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('Intensif UTBK');
    expect(labels.join(' ')).toContain('Reguler SMP');
  });

  it('picking a program re-queries with program_id and shows its name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');

    // Row 0 is the "Semua" reset; row 2 is the second program.
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListGroupsArg().program_id).toBe('pr-2');
    // The chip must read the NAME, never a UUID fragment.
    const chip = w.findAll('[data-testid="chip"]')[CHIP.program];
    expect(chip.text()).toBe('Reguler SMP');
    expect(chip.text()).not.toContain('pr-2');
  });

  it('picking a term re-queries with term_id and shows its name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.term].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListGroupsArg().term_id).toBe('tm-2');
    expect(w.findAll('[data-testid="chip"]')[CHIP.term].text()).toBe('Gelombang 2');
  });

  it('picking a tutor re-queries with tutor_id and shows their name', async () => {
    const w = await mountView();
    await w.findAll('[data-testid="chip"]')[CHIP.tutor].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();

    expect(lastListGroupsArg().tutor_id).toBe('tu-2');
    expect(w.findAll('[data-testid="chip"]')[CHIP.tutor].text()).toBe('Bu Sinta');
  });

  it('the "Semua" row clears the filter back off the query', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(lastListGroupsArg().program_id).toBe('pr-2');

    await w.findAll('[data-testid="chip"]')[CHIP.program].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(lastListGroupsArg().program_id).toBeUndefined();
    expect(w.findAll('[data-testid="chip"]')[CHIP.program].text()).toBe('Semua');
  });

  it('a facet whose list came back empty disables its own chip only', async () => {
    (TutoringTutorsService.list as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.tutor].attributes('disabled')).toBeDefined();
    // The other two must stay usable — one dead endpoint must not take
    // the whole toolbar down with it.
    expect(chips[CHIP.program].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.term].attributes('disabled')).toBeUndefined();
  });

  it('one failing option endpoint does not blank the other two chips', async () => {
    (TutoringTermsService.list as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.term].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.program].attributes('disabled')).toBeUndefined();
    expect(chips[CHIP.tutor].attributes('disabled')).toBeUndefined();
  });
});

/**
 * ── "+ Kelompok baru" ────────────────────────────────────────────────
 *
 * The same class of bug as the chips above, one layer down: the floating
 * CTA rendered a styled button with its i18n label in place and NO
 * `@click` at all, so prod reported "tombol diklik tidak terjadi
 * apa-apa".
 *
 * Every test below fails against that template — there is no create
 * surface to find and `createGroup` is never called. The sheet mounted
 * here is the real <AdminTutoring2GroupCreateSheet>; only the
 * teleporting <Modal> shell is stubbed, so the fields filled below are
 * the fields an admin fills and the payload asserted is the payload the
 * browser would POST.
 */
function makeCtaI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', program: 'Program', term: 'Term', tutor: 'Tutor' },
          admin: {
            groups: { newCta: 'Kelompok baru' },
            groupCreate: {
              title: 'Kelompok baru',
              subtitle: 'Buat kelompok belajar untuk sebuah program.',
              programPh: 'Pilih program…',
              noPrograms: 'Belum ada program.',
              nameLabel: 'Nama kelompok',
              namePh: 'Contoh: UTBK Pagi A',
              capacityLabel: 'Kapasitas',
              capacityPh: 'Jumlah kursi',
              submit: 'Buat kelompok',
              errName: 'Nama kelompok minimal 3 karakter.',
              errProgram: 'Pilih program terlebih dahulu.',
              success: 'Kelompok dibuat.',
              errorGeneric: 'Gagal membuat kelompok.',
            },
          },
        },
      },
    },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountForCta() {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2GroupsView, {
    global: {
      plugins: [makeCtaI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: true,
        AppFilterChip: true,
        FilterFacetPickerModal: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot :data="state?.data ?? []" /></div>',
        },
        // Modal teleports to body, which would escape the wrapper. The
        // stub forwards `testid` so FormSheet's own id survives.
        Modal: {
          props: ['title', 'subtitle', 'size', 'testid'],
          template: '<div :data-testid="testid || \'modal\'"><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

const sheetOf = (w) => w.find('[data-testid="form-sheet"]');
const ctaOf = (w) => w.find('[data-testid="groups-new-cta"]');

describe('AdminTutoring2GroupsView "+ Kelompok baru" CTA', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantedAbilities = ['tutoring.group.manage'];
    (TutoringBimbelService.listGroups as any).mockResolvedValue({
      items: [makeGroup()],
      pagination: undefined,
    });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
    (TutoringBimbelService.createGroup as any).mockResolvedValue(
      makeGroup({ id: 'gr-new', name: 'UTBK Sore C' }),
    );
    (TutoringTermsService.list as any).mockResolvedValue({ items: TERMS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('renders the CTA for an admin who may manage groups', async () => {
    const w = await mountForCta();

    expect(ctaOf(w).exists()).toBe(true);
    expect(ctaOf(w).text()).toContain('Kelompok baru');
  });

  it('clicking the CTA OPENS a create surface', async () => {
    const w = await mountForCta();
    // The regression: nothing was bound, so nothing opened.
    expect(sheetOf(w).exists()).toBe(false);

    await ctaOf(w).trigger('click');

    expect(sheetOf(w).exists()).toBe(true);
  });

  it('the sheet offers the programs the list already loaded', async () => {
    const w = await mountForCta();
    await ctaOf(w).trigger('click');

    const labels = sheetOf(w)
      .findAll('option')
      .map((o) => o.text());
    expect(labels).toContain('Intensif UTBK');
    expect(labels).toContain('Reguler SMP');
    // No extra round-trip — the picker reuses the filter-chip fetch.
    expect(TutoringBimbelService.listPrograms).toHaveBeenCalledTimes(1);
  });

  it('submitting POSTs the group and refreshes the list', async () => {
    const w = await mountForCta();
    await ctaOf(w).trigger('click');

    await sheetOf(w).find('select').setValue('pr-2');
    await sheetOf(w).find('input[type="text"]').setValue('UTBK Sore C');
    await sheetOf(w).find('input[type="number"]').setValue(15);

    const listCallsBefore = (TutoringBimbelService.listGroups as any).mock.calls.length;
    await sheetOf(w).find('[data-testid="sheet-submit"]').trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.createGroup).toHaveBeenCalledTimes(1);
    expect((TutoringBimbelService.createGroup as any).mock.calls[0][0]).toEqual({
      program_id: 'pr-2',
      name: 'UTBK Sore C',
      capacity: 15,
    });
    // Sheet closes and the list re-queries so the new row appears.
    expect(sheetOf(w).exists()).toBe(false);
    expect((TutoringBimbelService.listGroups as any).mock.calls.length).toBeGreaterThan(
      listCallsBefore,
    );
  });

  it('refuses to POST without a program, and says why', async () => {
    const w = await mountForCta();
    await ctaOf(w).trigger('click');

    await sheetOf(w).find('input[type="text"]').setValue('UTBK Sore C');
    await sheetOf(w).find('[data-testid="sheet-submit"]').trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.createGroup).not.toHaveBeenCalled();
    // A refusal the admin can READ — not a silent no-op.
    expect(sheetOf(w).exists()).toBe(true);
    expect(sheetOf(w).text()).toContain('Pilih program terlebih dahulu.');
  });

  it('refuses a too-short name, and says why', async () => {
    const w = await mountForCta();
    await ctaOf(w).trigger('click');

    await sheetOf(w).find('select').setValue('pr-1');
    await sheetOf(w).find('input[type="text"]').setValue('AB');
    await sheetOf(w).find('[data-testid="sheet-submit"]').trigger('click');
    await flushPromises();

    expect(TutoringBimbelService.createGroup).not.toHaveBeenCalled();
    expect(sheetOf(w).text()).toContain('Nama kelompok minimal 3 karakter.');
  });

  it('hides the CTA entirely when the admin lacks tutoring.group.manage', async () => {
    grantedAbilities = [];

    const w = await mountForCta();

    // Hidden, not inert: an admin never sees a button that would refuse.
    expect(ctaOf(w).exists()).toBe(false);
  });
});


/**
 * Third guard on this file, for the third incarnation of the same bug.
 *
 * The chips (describe #1) shipped inert, the CTA (describe #2) shipped
 * with no `@click` at all, and the table rows shipped the same way:
 * `hover:bg-slate-50` with no handler behind it, so a bimbel admin on
 * prod reported that clicking a kelompok belajar did nothing. The
 * destination route `admin.tutoring2.group-detail` already existed and
 * was already reached from two other screens; only this list, which the
 * detail view's own docblock names as its list side, never linked.
 *
 * Each test fails against the old template: with no `@click` on the
 * `<tr>`, `routerPush` is never called.
 */
describe('AdminTutoring2GroupsView row drill-in', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantedAbilities = ['tutoring.group.manage'];
    (TutoringBimbelService.listGroups as any).mockResolvedValue({
      items: [makeGroup(), makeGroup({ id: 'gr-2', name: 'UTBK Siang B' })],
      pagination: undefined,
    });
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({ items: PROGRAMS });
    (TutoringTermsService.list as any).mockResolvedValue({ items: TERMS });
    (TutoringTutorsService.list as any).mockResolvedValue({ items: TUTORS });
  });

  it('clicking a row opens THAT group detail', async () => {
    const w = await mountForCta();
    const rows = w.findAll('tbody tr');
    expect(rows.length).toBe(2);

    await rows[0].trigger('click');

    expect(routerPush).toHaveBeenCalledTimes(1);
    expect(routerPush).toHaveBeenCalledWith({
      name: 'admin.tutoring2.group-detail',
      params: { groupId: 'gr-1' },
    });
  });

  it('carries the id of the row actually clicked, not the first row', async () => {
    const w = await mountForCta();

    await w.findAll('tbody tr')[1].trigger('click');

    // A handler hard-wired to the first row would still pass the test
    // above; this is what pins the per-row binding.
    expect(routerPush).toHaveBeenCalledWith({
      name: 'admin.tutoring2.group-detail',
      params: { groupId: 'gr-2' },
    });
  });

  it('advertises the row as clickable', async () => {
    const w = await mountForCta();

    // The original bug was a row that LOOKED clickable (hover tint) and
    // was not. Hover tint and cursor must now travel together.
    const cls = w.findAll('tbody tr')[0].classes();
    expect(cls).toContain('cursor-pointer');
    expect(cls).toContain('hover:bg-slate-50');
  });

  it('stays reachable for an admin who may not manage groups', async () => {
    // Read-only drill-in: gated on the list route's own access, never on
    // `tutoring.group.manage` (that ability guards the create CTA only).
    grantedAbilities = [];
    const w = await mountForCta();

    await w.findAll('tbody tr')[0].trigger('click');

    expect(ctaOf(w).exists()).toBe(false);
    expect(routerPush).toHaveBeenCalledWith({
      name: 'admin.tutoring2.group-detail',
      params: { groupId: 'gr-1' },
    });
  });
});
