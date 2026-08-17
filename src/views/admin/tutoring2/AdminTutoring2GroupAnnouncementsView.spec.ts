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

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: () => true }),
}));

const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', program_name: 'Intensif UTBK', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-2', program_name: 'Reguler SMP', name: 'SMP Sore B', kind: 'group', capacity: 10, status: 'active' },
];

function makeAnnouncement(groupId: string, overrides = {}) {
  return {
    id: `an-${groupId}`,
    learning_group_id: groupId,
    title: `Pengumuman ${groupId}`,
    body: '<p>isi</p>',
    author_name: 'Admin Satu',
    published_at: '2026-08-11T09:00:00+07:00',
    created_at: '2026-08-10T09:00:00+07:00',
    ...overrides,
  };
}

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', group: 'Kelompok', status: 'Status' },
          status: { draft: 'Draft', published: 'Terbit', archived: 'Arsip' },
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
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringAnnouncementsService.list as any).mockImplementation((groupId: string) =>
      Promise.resolve({ items: [makeAnnouncement(groupId)] }),
    );
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
    (TutoringAnnouncementsService.list as any).mockImplementation((groupId: string) =>
      Promise.resolve({
        items: [
          makeAnnouncement(groupId),
          makeAnnouncement(`${groupId}-draft`, {
            learning_group_id: groupId,
            published_at: null,
          }),
        ],
      }),
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
