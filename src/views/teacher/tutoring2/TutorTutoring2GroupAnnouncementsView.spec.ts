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
    // Flat/tenant-wide surface (BE !856) — the only list that can carry
    // a group-less, tutor-addressed row.
    listAll: vi.fn(),
    createForTutors: vi.fn(),
    publishById: vi.fn(),
    destroyById: vi.fn(),
  },
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

vi.mock('@/composables/useConfirm', () => ({
  useConfirm: () => ({ confirm: vi.fn().mockResolvedValue(true) }),
}));

/**
 * A TUTOR's abilities. `tutoring.announcement.create` yes (their own
 * groups); the admin-only `tutoring.tutor.view` deliberately NOT — that
 * is the key that separates "may write announcements" from "may act on a
 * tenant-wide broadcast".
 */
const abilities = new Set<string>(['tutoring.announcement.create']);
vi.mock('@/stores/auth', () => ({
  useAuthStore: () => ({ hasAbility: (k: string) => abilities.has(k) }),
}));

/** The tutor's own groups — BE scopes listGroups by tutor for this role. */
const GROUPS = [
  { id: 'gr-1', program_id: 'pr-1', program_name: 'Intensif UTBK', name: 'UTBK Pagi A', kind: 'group', capacity: 12, status: 'active' },
  { id: 'gr-2', program_id: 'pr-2', program_name: 'Reguler SMP', name: 'SMP Sore B', kind: 'group', capacity: 10, status: 'active' },
];

/**
 * Default flat-list stub. Honours `learning_group_id` the way the server
 * does, which necessarily excludes the group-less broadcasts.
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

/**
 * An admin's tenant-wide broadcast, as a tutor receives it: no group,
 * and always already published (the server pins the tutor read arm to
 * `published_at IS NOT NULL`, so a tutor never sees an admin's draft).
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

function makeAnnouncement(groupId: string, overrides = {}) {
  return {
    id: `an-${groupId}`,
    learning_group_id: groupId,
    audience: 'learning_group',
    audience_label: 'Kelompok belajar',
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
          common: {
            all: 'Semua',
            group: 'Kelompok',
            // Used by the preview-footer block at the bottom of this file.
            detail: 'Detail',
            back: 'Kembali',
            cancel: 'Batal',
            delete: 'Hapus',
          },
          status: { draft: 'Draft', published: 'Terbit', archived: 'Arsip' },
          tutor: {
            groupAnnouncements: {
              audienceGroup: 'Kelompok belajar',
              audienceTutor: 'Semua tutor',
              publishCta: 'Terbitkan',
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
    stubListAll(GROUPS.map((g) => makeAnnouncement(g.id)));
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

/**
 * ── Preview modal footer ────────────────────────────────────────────
 *
 * Tutor-side twin of the admin fix. A bimbel admin reported a stray "Batal"
 * on the announcement detail dialog (Slack 1788511561.654479); all three
 * announcement screens carried the identical footer.
 *
 * The dialog is READ-ONLY, so the call site binds no `@secondary`, yet
 * BottomSheetFooter rendered its cancel button anyway with the hardcoded
 * 'Batal' default — a visible, enabled control whose click went nowhere.
 *
 * The block above stubs `BottomSheetFooter`, which is why no test ever saw
 * those buttons. These mount it for real.
 */
async function mountViewWithFooter() {
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

/** The per-row "Detail" button in the announcement list. */
function detailButton(w) {
  return w.findAll('[data-testid="async"] li button').find((b) => b.text() === 'Detail');
}

describe('TutorTutoring2GroupAnnouncementsView preview footer', () => {
  beforeEach(() => {
    vi.clearAllMocks();
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
    // Scope guard: the editable compose sheet binds `@secondary` and must
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
 * This screen used to load the tutor's groups and fire one nested
 * `GET /learning-groups/{id}/announcements` per group. That loader could
 * not show an admin's tenant-wide broadcast at ALL — the nested route
 * filters `where('learning_group_id', {groupId})`, and a broadcast has
 * no group — so the feature Luay asked for had a write path and no
 * reader on the tutor side.
 *
 * It now makes one flat call, which the server scopes to the tutor's own
 * groups PLUS published tutor-addressed rows.
 */
describe('TutorTutoring2GroupAnnouncementsView tutor-addressed rows', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: GROUPS });
    stubListAll([...GROUPS.map((g) => makeAnnouncement(g.id)), makeTutorBroadcast()]);
  });

  it('loads in ONE flat call — the per-group fan-out is gone', async () => {
    await mountView();

    expect(TutoringAnnouncementsService.listAll).toHaveBeenCalledTimes(1);
    expect(TutoringAnnouncementsService.list).not.toHaveBeenCalled();
  });

  it('shows the tenant-wide broadcast ALONGSIDE the group announcements', async () => {
    const w = await mountView();
    const list = rows(w);

    expect(list).toHaveLength(3); // 2 group rows + 1 broadcast
    expect(list.join(' ')).toContain('Rapat koordinasi tutor');
    // Group rows must keep working — this is a superset, not a swap.
    expect(list.join(' ')).toContain('Pengumuman gr-1');
    expect(list.join(' ')).toContain('Pengumuman gr-2');
  });

  it('labels the broadcast with the server label instead of a group name', async () => {
    const w = await mountView();
    const broadcast = w
      .findAll('[data-testid="async"] li')
      .find((r) => r.text().includes('Rapat koordinasi tutor'));

    expect(broadcast!.text()).toContain('Semua tutor');
    // Never the literal null a group-name lookup would have produced.
    expect(broadcast!.text()).not.toContain('null');
  });

  it('a group row still reads its group name', async () => {
    const w = await mountView();
    const groupRow = w
      .findAll('[data-testid="async"] li')
      .find((r) => r.text().includes('Pengumuman gr-1'));

    expect(groupRow!.text()).toContain('UTBK Pagi A');
  });

  it('offers NO delete on a broadcast — a tutor cannot act on one', async () => {
    const w = await mountView();
    const broadcast = w
      .findAll('[data-testid="async"] li')
      .find((r) => r.text().includes('Rapat koordinasi tutor'));

    // The server pins a non-admin to `audience = 'learning_group'` and
    // answers anything else with a 404. Rendering Hapus here would be a
    // control advertising an action it cannot perform.
    expect(broadcast!.text()).not.toContain('Hapus');

    // The tutor's OWN group announcements keep their actions — the gate
    // is per row, not a blanket read-only mode.
    const groupRow = w
      .findAll('[data-testid="async"] li')
      .find((r) => r.text().includes('Pengumuman gr-1'));
    expect(groupRow!.text()).toContain('Hapus');
  });

  it('deletes a group row through the id-only route', async () => {
    (TutoringAnnouncementsService.destroyById as any).mockResolvedValue(undefined);
    const w = await mountView();

    const groupRow = w
      .findAll('[data-testid="async"] li')
      .find((r) => r.text().includes('Pengumuman gr-1'));
    await groupRow!.findAll('button').find((b) => b.text() === 'Hapus')!.trigger('click');
    await flushPromises();

    expect(TutoringAnnouncementsService.destroyById).toHaveBeenCalledWith('an-gr-1');
    expect(TutoringAnnouncementsService.destroy).not.toHaveBeenCalled();
  });

  it('a tutor with no groups still receives the broadcast', async () => {
    // The old loader iterated groups, so zero groups meant zero rows —
    // and a tenant-wide announcement is addressed to the tutor whatever
    // they currently teach.
    (TutoringBimbelService.listGroups as any).mockResolvedValue({ items: [] });
    stubListAll([makeTutorBroadcast()]);

    const w = await mountView();

    expect(rows(w).join(' ')).toContain('Rapat koordinasi tutor');
  });

  it('picking a group narrows server-side and drops the group-less rows', async () => {
    const w = await mountView();
    expect(rows(w)).toHaveLength(3);

    await w.findAll('[data-testid="chip"]')[0].trigger('click');
    await optionRows(w)[2].trigger('click'); // row 0 = "Semua", row 2 = gr-2
    await flushPromises();

    expect(TutoringAnnouncementsService.listAll).toHaveBeenLastCalledWith(
      expect.objectContaining({ learning_group_id: 'gr-2' }),
    );
    const list = rows(w);
    expect(list).toHaveLength(1);
    expect(list[0]).toContain('gr-2');
    // "Show me this group" cannot also mean "and the tenant-wide posts".
    expect(list.join(' ')).not.toContain('Rapat koordinasi tutor');
  });
});
