/**
 * Vitest contract spec for AdminTutoring2GroupAnnouncementsView.
 *
 * Pins the Kelompok / Status filter chips. Both handlers were
 * `@click="xFilter = ''"`, which only ever CLEARS:
 *
 *   - Status was INERT. Nothing on the page could put a value into it,
 *     so an admin could never narrow to Draft or Terbit.
 *   - Kelompok was reachable, but only via a strip of round buttons
 *     below the toolbar rendered `v-if="!groupFilter"` — it VANISHED the
 *     moment you used it, so the chip that looked like the control was a
 *     clear button and the real control disappeared after one click.
 *
 * Part of the "semua button/filter tdk berfungsi" report a bimbel admin
 * filed on prod.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body); the option rows clicked here
 * are the ones an admin clicks.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2GroupAnnouncementsView from './AdminTutoring2GroupAnnouncementsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringAnnouncementsService } from '@/services/tutoring2/announcements';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { listGroups: vi.fn() },
}));

vi.mock('@/services/tutoring2/announcements', () => ({
  TutoringAnnouncementsService: {
    list: vi.fn(),
    create: vi.fn(),
    publish: vi.fn(),
    destroy: vi.fn(),
    // Flat/tenant-wide surface (BE !856). `listAll` is what this screen
    // reads now — the per-group fan-out is gone.
    listAll: vi.fn(),
    createForTutors: vi.fn(),
    publishById: vi.fn(),
    destroyById: vi.fn(),
  },
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

vi.mock('@/composables/useConfirm', () => ({
  useConfirm: () => ({ confirm: vi.fn().mockResolvedValue(true) }),
}));

/**
 * Abilities are per-test. The compose gate is TWO keys server-side
 * (`tutoring.announcement.create` + the admin-only `tutoring.tutor.view`),
 * so a spec that hardcodes `() => true` cannot see a gate that checks
 * only the first.
 */
const abilities = new Set<string>();
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: (k: string) => abilities.has(k) }),
}));

function grantAllAbilities() {
  abilities.clear();
  abilities.add('tutoring.announcement.create');
  abilities.add('tutoring.tutor.view');
}

const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', program_name: 'Intensif UTBK', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-2', program_name: 'Reguler SMP', name: 'SMP Sore B', kind: 'group', capacity: 10, status: 'active' },
];

function makeAnnouncement(groupId: string, overrides = {}) {
  return {
    id: `an-${groupId}`,
    learning_group_id: groupId,
    audience: 'learning_group',
    audience_label: 'Kelompok belajar',
    title: `Pengumuman ${groupId}`,
    body: '<p>isi</p>',
    author_name: 'Admin Satu',
    published_at: '2026-08-11T09:00:00+07:00',
    created_at: '2026-08-10T09:00:00+07:00',
    ...overrides,
  };
}

/**
 * A tenant-wide broadcast: NO learning group at all.
 *
 * The null is the point. This row cannot be produced by any nested
 * `/learning-groups/{id}/announcements` response, so the fan-out loader
 * this screen used to run could never render one.
 */
function makeTutorBroadcast(overrides = {}) {
  return {
    id: 'an-tutor-1',
    learning_group_id: null,
    audience: 'tutor',
    audience_label: 'Semua tutor',
    title: 'Rapat koordinasi tutor',
    body: '<p>Senin 08.00.</p>',
    author_name: 'Admin Satu',
    published_at: '2026-08-12T09:00:00+07:00',
    created_at: '2026-08-12T08:00:00+07:00',
    ...overrides,
  };
}

/**
 * Default flat-list stub: one announcement per group. Honours
 * `learning_group_id` the way the server does — which necessarily
 * EXCLUDES the group-less broadcasts.
 */
function stubListAll(items: any[]) {
  (TutoringAnnouncementsService.listAll as any).mockImplementation(
    (params: any = {}) =>
      Promise.resolve({
        items: params.learning_group_id
          ? items.filter((a) => a.learning_group_id === params.learning_group_id)
          : items,
      }),
  );
}

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
            status: 'Status',
            // Used by the preview-footer block at the bottom of this file.
            detail: 'Detail',
            back: 'Kembali',
            cancel: 'Batal',
            delete: 'Hapus',
            title: 'Judul',
          },
          status: { draft: 'Draft', published: 'Terbit', archived: 'Arsip' },
          admin: {
            groupAnnouncements: {
              audience: 'Tujuan',
              audienceGroup: 'Kelompok belajar',
              audienceTutor: 'Semua tutor',
              audienceHelp: 'Pilih siapa yang menerima pengumuman ini',
              composeCta: 'Tulis',
              composeTitle: 'Buat pengumuman',
              composeSubtitle: 'Kirim ke semua siswa + wali di kelompok',
              composeSubtitleTutor: 'Kirim ke seluruh tutor di lembaga ini',
              publishCta: 'Terbitkan',
              saveDraftCta: 'Simpan draft',
              validationLen: 'Judul dan isi minimal 3 karakter',
              pickGroupFirst: 'Pilih kelompok dulu',
            },
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
  const w = mount(AdminTutoring2GroupAnnouncementsView, {
    global: {
      plugins: [i18n],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        AppRichTextEditor: true,
        BottomSheetFooter: true,
        PageFilterToolbar: {
          template: '<div data-testid="toolbar"><slot name="chips" /></div>',
        },
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
        // renders into. This view also uses Modal for compose/preview,
        // but neither is open during these tests.
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

/** Chips render in template order: group, status. */
const CHIP = { group: 0, status: 1 };

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function rowTitles(w) {
  return w.findAll('[data-testid="async"] tbody tr').map((r) => r.text());
}

describe('AdminTutoring2GroupAnnouncementsView filter chips', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantAllAbilities();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    stubListAll(GROUPS.map((g) => makeAnnouncement(g.id)));
  });

  it('chips start at "Semua"', async () => {
    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips).toHaveLength(2);
    expect(chips[CHIP.group].text()).toBe('Semua');
    expect(chips[CHIP.status].text()).toBe('Semua');
  });

  it('clicking the Kelompok chip OPENS a picker listing groups by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — the old handler only cleared,
    // and the only real control was a strip that hid itself once used.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('UTBK Pagi A');
    expect(labels.join(' ')).toContain('SMP Sore B');
  });

  it('picking a group narrows the list to that group and names the chip', async () => {
    const w = await mountView();
    expect(rowTitles(w)).toHaveLength(2); // one per group, unfiltered

    await w.findAll('[data-testid="chip"]')[CHIP.group].trigger('click');
    await optionRows(w)[2].trigger('click'); // row 0 = "Semua", row 2 = gr-2
    await flushPromises();

    const rows = rowTitles(w);
    expect(rows).toHaveLength(1);
    expect(rows[0]).toContain('gr-2');
    // The chip must read the NAME, never an id fragment.
    const chip = w.findAll('[data-testid="chip"]')[CHIP.group];
    expect(chip.text()).toBe('SMP Sore B');
    expect(chip.text()).not.toContain('gr-2');
  });

  it('the Status chip OPENS a picker — it could not be set at all before', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.status].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('Draft');
    expect(labels.join(' ')).toContain('Terbit');
    expect(labels.join(' ')).toContain('Arsip');
  });

  it('picking a status actually narrows the rows', async () => {
    // One published, one draft — a working status filter must split them.
    stubListAll(
      GROUPS.flatMap((g) => [
        makeAnnouncement(g.id),
        makeAnnouncement(`${g.id}-draft`, {
          learning_group_id: g.id,
          published_at: null,
        }),
      ]),
    );

    const w = await mountView();
    expect(rowTitles(w)).toHaveLength(4); // 2 groups × 2 announcements

    await w.findAll('[data-testid="chip"]')[CHIP.status].trigger('click');
    // Rows: 0 "Semua", 1 draft, 2 published, 3 archived.
    await optionRows(w)[1].trigger('click');
    await flushPromises();

    expect(rowTitles(w)).toHaveLength(2); // the two drafts only
    expect(w.findAll('[data-testid="chip"]')[CHIP.status].text()).toBe('Draft');
  });

  it('the "Semua" row clears a picked status again', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[CHIP.status].trigger('click');
    await optionRows(w)[1].trigger('click'); // draft
    await flushPromises();
    expect(w.findAll('[data-testid="chip"]')[CHIP.status].text()).toBe('Draft');

    await w.findAll('[data-testid="chip"]')[CHIP.status].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(w.findAll('[data-testid="chip"]')[CHIP.status].text()).toBe('Semua');
    expect(rowTitles(w)).toHaveLength(2); // unfiltered again
  });

  it('an empty group list disables the Kelompok chip but not Status', async () => {
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: [] });

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.group].attributes('disabled')).toBeDefined();
    // Status options are a fixed vocabulary — no fetch, never disabled.
    expect(chips[CHIP.status].attributes('disabled')).toBeUndefined();
  });

  it('a failing groups endpoint leaves Status usable', async () => {
    (TutoringBimbelService.listGroups as any).mockRejectedValue(new Error('403'));

    const w = await mountView();
    const chips = w.findAll('[data-testid="chip"]');

    expect(chips[CHIP.group].attributes('disabled')).toBeDefined();
    expect(chips[CHIP.status].attributes('disabled')).toBeUndefined();
  });
});

/**
 * ── Preview modal footer ────────────────────────────────────────────
 *
 * A bimbel admin reported that the detail dialog on this screen carries a
 * "Batal" button that should not be there (Slack 1788511561.654479). It was
 * worse than redundant: the dialog is READ-ONLY, so the call site binds no
 * `@secondary`, and BottomSheetFooter rendered its cancel button anyway with
 * the hardcoded 'Batal' default. Clicking it did nothing at all.
 *
 * The block above stubs `BottomSheetFooter`, which is exactly why no test
 * ever saw those buttons. These mount it for real.
 */
async function mountViewWithFooter() {
  setActivePinia(createPinia());
  const i18n = makeI18n();
  const w = mount(AdminTutoring2GroupAnnouncementsView, {
    global: {
      plugins: [i18n],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        AppRichTextEditor: true,
        // BottomSheetFooter is deliberately NOT stubbed here.
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        AppFilterChip: true,
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
      },
    },
  });
  await flushPromises();
  return w;
}

const CANCEL = '[data-testid="sheet-cancel"]';
const SUBMIT = '[data-testid="sheet-submit"]';

/** The per-row "Detail" button — first action in the row's action cell. */
function detailButton(w) {
  return w
    .findAll('[data-testid="async"] tbody tr button')
    .find((b) => b.text() === 'Detail');
}

describe('AdminTutoring2GroupAnnouncementsView preview footer', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantAllAbilities();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    stubListAll(GROUPS.map((g) => makeAnnouncement(g.id)));
  });

  it('the detail dialog ends in ONE button, and it is "Kembali"', async () => {
    const w = await mountViewWithFooter();

    await detailButton(w).trigger('click');

    const modal = w.find('[data-testid="modal"]');
    expect(modal.exists()).toBe(true);
    expect(modal.find(SUBMIT).text()).toBe('Kembali');
    expect(modal.find(CANCEL).exists()).toBe(false);
  });

  it('renders no "Batal" anywhere in the detail dialog', async () => {
    const w = await mountViewWithFooter();

    await detailButton(w).trigger('click');

    expect(w.find('[data-testid="modal"]').text()).not.toContain('Batal');
  });

  it('"Kembali" still closes the dialog', async () => {
    const w = await mountViewWithFooter();

    await detailButton(w).trigger('click');
    expect(w.find('[data-testid="modal"]').exists()).toBe(true);

    await w.find(`[data-testid="modal"] ${SUBMIT}`).trigger('click');

    expect(w.find('[data-testid="modal"]').exists()).toBe(false);
  });

  it('the COMPOSE dialog on this same screen keeps its working Batal', async () => {
    // Scope guard: the fix suppresses the cancel button on the read-only
    // preview only. The editable compose sheet binds `@secondary` and must
    // still render both buttons.
    const w = await mountViewWithFooter();

    await w.find('button.fixed').trigger('click');

    const modal = w.find('[data-testid="modal"]');
    expect(modal.find(CANCEL).exists()).toBe(true);
    expect(modal.find(CANCEL).text()).toBe('Batal');
    expect(modal.find(SUBMIT).exists()).toBe(true);
  });
});

/**
 * ── Tutor-addressed announcements (BE !856) ─────────────────────────
 *
 * Luay: a bimbel admin had no way to post an announcement aimed at
 * TUTORS. The backend gained a flat `/tutoring-v2/announcements` whose
 * rows carry `audience` + `audience_label` and a NULLABLE
 * `learning_group_id`.
 *
 * Three things had to be true on this screen, and the third is the one
 * that makes the other two visible at all:
 *
 *   1. an admin can compose one, and it posts to the FLAT endpoint;
 *   2. the list renders both audiences, including the null-group row;
 *   3. the loader no longer fans out per group — a group-less row can
 *      never appear in a per-group fan-out, so without the collapse the
 *      new rows exist in the database and on no screen.
 */
async function mountComposable(open = true) {
  setActivePinia(createPinia());
  const i18n = makeI18n();
  const w = mount(AdminTutoring2GroupAnnouncementsView, {
    global: {
      plugins: [i18n],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        AppFilterChip: true,
        AsyncView: {
          props: ['state'],
          template: '<div data-testid="async"><slot :data="state?.data ?? []" /></div>',
        },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
        // Real v-model:html seam so the body can actually be typed.
        AppRichTextEditor: {
          props: ['html'],
          emits: ['update:html'],
          template:
            '<textarea data-testid="body" :value="html" @input="$emit(\'update:html\', $event.target.value)" />',
        },
      },
    },
  });
  await flushPromises();
  if (open) {
    await w.find('button.fixed').trigger('click');
  }
  return w;
}

const AUDIENCE = '[data-testid="compose-audience"]';

describe('AdminTutoring2GroupAnnouncementsView tutor audience', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantAllAbilities();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    stubListAll([...GROUPS.map((g) => makeAnnouncement(g.id)), makeTutorBroadcast()]);
    (TutoringAnnouncementsService.createForTutors as any).mockResolvedValue(
      makeTutorBroadcast(),
    );
    (TutoringAnnouncementsService.create as any).mockResolvedValue(makeAnnouncement('gr-1'));
  });

  // ── The collapse ────────────────────────────────────────────────

  it('loads the list in ONE flat call, not one per group', async () => {
    await mountComposable(false);

    expect(TutoringAnnouncementsService.listAll).toHaveBeenCalledTimes(1);
    // The per-group fan-out must be gone entirely. It is not a slower
    // route to the same data — it cannot carry a group-less row at all.
    expect(TutoringAnnouncementsService.list).not.toHaveBeenCalled();
  });

  it('renders BOTH audiences, including the null-group broadcast', async () => {
    const w = await mountComposable(false);
    const rows = w.findAll('[data-testid="async"] tbody tr');

    expect(rows).toHaveLength(3); // 2 group rows + 1 tenant-wide
    const broadcast = rows.find((r) => r.text().includes('Rapat koordinasi tutor'));
    expect(broadcast).toBeDefined();
    // The audience column reads the SERVER's label, not a re-derived one.
    expect(broadcast!.text()).toContain('Semua tutor');
    // …and the group column is an honest dash, not "null" or a blank.
    expect(broadcast!.text()).toContain('—');
  });

  it('a group-addressed row still names its group', async () => {
    const w = await mountComposable(false);
    const row = w
      .findAll('[data-testid="async"] tbody tr')
      .find((r) => r.text().includes('Pengumuman gr-1'));

    expect(row!.text()).toContain('UTBK Pagi A');
    expect(row!.text()).toContain('Kelompok belajar');
  });

  // ── Compose ─────────────────────────────────────────────────────

  it('composing to tutors posts the FLAT payload and never the nested one', async () => {
    const w = await mountComposable();

    await w.find(AUDIENCE).setValue('tutor');
    await w.find('input[type="text"]').setValue('Rapat koordinasi tutor');
    await w.find('[data-testid="body"]').setValue('<p>Senin 08.00.</p>');
    await w.find('[data-testid="sheet-submit"]').trigger('click');
    await flushPromises();

    expect(TutoringAnnouncementsService.createForTutors).toHaveBeenCalledWith({
      title: 'Rapat koordinasi tutor',
      body: '<p>Senin 08.00.</p>',
      publish: false,
    });
    // The flat POST refuses `audience: 'learning_group'` with a 422, and
    // the nested route is the only door for a group announcement — so a
    // tutor broadcast must not travel through it.
    expect(TutoringAnnouncementsService.create).not.toHaveBeenCalled();
  });

  it('the group picker disappears once the audience is "tutor"', async () => {
    const w = await mountComposable();
    // A group announcement still picks a group.
    expect(w.find('[data-testid="modal"] select[class]').exists()).toBe(true);

    await w.find(AUDIENCE).setValue('tutor');

    // Exactly one select remains: the audience one. A broadcast has no
    // group, so offering the picker would imply a choice that is ignored.
    const selects = w.findAll('[data-testid="modal"] select');
    expect(selects).toHaveLength(1);
    expect(selects[0].attributes('data-testid')).toBe('compose-audience');
  });

  it('composing to a group still uses the NESTED endpoint', async () => {
    const w = await mountComposable();

    await w.find('input[type="text"]').setValue('Perubahan jadwal');
    await w.find('[data-testid="body"]').setValue('<p>Rabu ke Kamis.</p>');
    await w.find('[data-testid="sheet-submit"]').trigger('click');
    await flushPromises();

    expect(TutoringAnnouncementsService.create).toHaveBeenCalledWith('gr-1', {
      title: 'Perubahan jadwal',
      body: '<p>Rabu ke Kamis.</p>',
      publish: false,
    });
    expect(TutoringAnnouncementsService.createForTutors).not.toHaveBeenCalled();
  });

  // ── The gate ────────────────────────────────────────────────────

  it('without tutoring.tutor.view the audience selector is not rendered', async () => {
    // The server gate is TWO keys. This actor holds the create key — and
    // a screen that gated on that alone would show the control and let
    // the admin write a post the server answers with 403.
    abilities.clear();
    abilities.add('tutoring.announcement.create');

    const w = await mountComposable();

    expect(w.find(AUDIENCE).exists()).toBe(false);
    // …but the group compose flow they DO hold is untouched.
    expect(w.find('[data-testid="modal"] select').exists()).toBe(true);
  });

  it('a tutor-addressed row offers no delete without tutoring.tutor.view', async () => {
    abilities.clear();
    abilities.add('tutoring.announcement.create');

    const w = await mountComposable(false);
    const broadcast = w
      .findAll('[data-testid="async"] tbody tr')
      .find((r) => r.text().includes('Rapat koordinasi tutor'));

    // Server pins a non-admin to `audience = 'learning_group'` and 404s
    // anything else, so a Hapus here would be a button that cannot work.
    expect(broadcast!.text()).not.toContain('Hapus');
    // The group rows keep theirs — the gate is per row, not per page.
    const groupRow = w
      .findAll('[data-testid="async"] tbody tr')
      .find((r) => r.text().includes('Pengumuman gr-1'));
    expect(groupRow!.text()).toContain('Hapus');
  });

  it('publish/delete go through the id-only routes, never a null group URL', async () => {
    (TutoringAnnouncementsService.destroyById as any).mockResolvedValue(undefined);
    const w = await mountComposable(false);

    const broadcast = w
      .findAll('[data-testid="async"] tbody tr')
      .find((r) => r.text().includes('Rapat koordinasi tutor'));
    await broadcast!.findAll('button').find((b) => b.text() === 'Hapus')!.trigger('click');
    await flushPromises();

    expect(TutoringAnnouncementsService.destroyById).toHaveBeenCalledWith('an-tutor-1');
    // The nested twin takes a groupId first. On this row that is null,
    // which would build `/learning-groups/null/announcements/…`.
    expect(TutoringAnnouncementsService.destroy).not.toHaveBeenCalled();
  });
});
