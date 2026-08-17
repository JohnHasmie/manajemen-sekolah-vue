/**
 * Vitest contract spec for TutorTutoring2GroupAnnouncementsView.
 *
 * Pins the Kelompok filter chip. Its handler was
 * `@click="groupFilter = ''"`, which only ever CLEARS. Setting a group
 * was possible, but only via a strip of round buttons below the toolbar
 * rendered `v-if="!groupFilter"` — it VANISHED the moment you used it, so
 * the chip that looked like the control was a clear button and the real
 * control disappeared after one click.
 *
 * Part of the "semua button/filter tdk berfungsi" report a bimbel admin
 * filed on prod; this is the tutor-side twin of the admin screen.
 *
 * The real <FilterFacetPickerModal> is mounted (only its <Modal> shell is
 * stubbed, because Modal teleports to body).
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import TutorTutoring2GroupAnnouncementsView from './TutorTutoring2GroupAnnouncementsView.vue';
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

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

vi.mock('@/composables/useConfirm', () => ({
  useConfirm: () => ({ confirm: vi.fn().mockResolvedValue(true) }),
}));

vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: () => true }),
}));

/** The tutor's own groups — BE scopes listGroups by tutor for this role. */
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
    author_name: 'Pak Rahmat',
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
          common: { all: 'Semua', group: 'Kelompok' },
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
  const w = mount(TutorTutoring2GroupAnnouncementsView, {
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
        Modal: { template: '<div data-testid="facet-modal"><slot /></div>' },
        Button: { template: '<button><slot /></button>' },
      },
    },
  });
  await flushPromises();
  return w;
}

function optionRows(w) {
  return w.findAll('[data-testid="facet-modal"] button');
}

function rows(w) {
  return w.findAll('[data-testid="async"] li').map((r) => r.text());
}

describe('TutorTutoring2GroupAnnouncementsView Kelompok chip', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    (TutoringAnnouncementsService.list as any).mockImplementation((groupId: string) =>
      Promise.resolve({ items: [makeAnnouncement(groupId)] }),
    );
  });

  it('the chip starts at "Semua" and is enabled once groups arrive', async () => {
    const w = await mountView();
    const chip = w.findAll('[data-testid="chip"]')[0];

    expect(chip.text()).toBe('Semua');
    expect(chip.attributes('disabled')).toBeUndefined();
  });

  it('clicking the chip OPENS a picker listing the tutor groups by name', async () => {
    const w = await mountView();
    // Nothing is open before the click — the old handler only cleared,
    // and the quick-pick strip hid itself once used.
    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(false);

    await w.findAll('[data-testid="chip"]')[0].trigger('click');

    expect(w.find('[data-testid="facet-modal"]').exists()).toBe(true);
    const labels = optionRows(w).map((b) => b.text());
    expect(labels[0]).toContain('Semua');
    expect(labels.join(' ')).toContain('UTBK Pagi A');
    expect(labels.join(' ')).toContain('SMP Sore B');
  });

  it('picking a group narrows the list and names the chip', async () => {
    const w = await mountView();
    expect(rows(w)).toHaveLength(2); // one per group, unfiltered

    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await optionRows(w)[2].trigger('click'); // row 0 = "Semua", row 2 = gr-2
    await flushPromises();

    const list = rows(w);
    expect(list).toHaveLength(1);
    expect(list[0]).toContain('gr-2');
    const chip = w.findAll('[data-testid="chip"]')[0];
    expect(chip.text()).toBe('SMP Sore B');
    expect(chip.text()).not.toContain('gr-2');
  });

  it('the picker stays reachable after a group is picked', async () => {
    // The regression the vanishing strip caused: once a group was set,
    // the only way to pick a DIFFERENT one was to clear first.
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await optionRows(w)[1].trigger('click'); // gr-1
    await flushPromises();
    expect(w.findAll('[data-testid="chip"]')[0].text()).toBe('UTBK Pagi A');

    // Straight from one group to another, no clearing step.
    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await optionRows(w)[2].trigger('click'); // gr-2
    await flushPromises();

    expect(w.findAll('[data-testid="chip"]')[0].text()).toBe('SMP Sore B');
    expect(rows(w)[0]).toContain('gr-2');
  });

  it('the "Semua" row clears the filter again', async () => {
    const w = await mountView();

    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await optionRows(w)[2].trigger('click');
    await flushPromises();
    expect(rows(w)).toHaveLength(1);

    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await optionRows(w)[0].trigger('click'); // "Semua"
    await flushPromises();

    expect(w.findAll('[data-testid="chip"]')[0].text()).toBe('Semua');
    expect(rows(w)).toHaveLength(2);
  });

  it('a tutor with no groups gets a disabled chip, not an empty menu', async () => {
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: [] });

    const w = await mountView();

    expect(w.findAll('[data-testid="chip"]')[0].attributes('disabled')).toBeDefined();
  });
});
