/**
 * Contract spec for the Kelompok + Jenis chips on the tutor's
 * "Aktivitas" screen. Both were blind cycles with no menu behind them.
 *
 * The GROUP chip was the worst instance of the family in the tutor
 * shell: it cycled over however many groups the tutor has, so reaching
 * the tenth meant nine presses — and each press fired a real request
 * for a group nobody wanted to look at.
 *
 * The group picker deliberately hides its "Semua" reset: the endpoint
 * is `/learning-groups/{groupId}/activities`, so there is no request
 * that means "all groups" and a reset row would only blank the screen.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ActivitiesView from './TutorTutoring2ActivitiesView.vue';
import { ActivitiesService } from '@/services/tutoring2/activities';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring2/activities', () => ({
  ActivitiesService: {
    listByGroup: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    publish: vi.fn(),
    delete: vi.fn(),
  },
}));
vi.mock('@/services/tutoring-bimbel.service', async (importOriginal) => ({
  ...(await importOriginal()),
  TutoringBimbelService: { listGroups: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/stores/me', () => ({
  useMeStore: () => ({ can: () => true }),
}));

const GROUPS = [
  { id: 'g-1', name: 'UTBK Pagi A' },
  { id: 'g-2', name: 'UTBK Siang B' },
  { id: 'g-3', name: 'Reguler SMA' },
];

function makeActivity(o = {}) {
  return {
    id: 'a-1',
    learning_group_id: 'g-1',
    kind: 'tugas',
    title: 'PR Aljabar',
    published_at: null,
    submissions_count: 0,
    ...o,
  };
}

const messages = {
  id: {
    tutoring2: {
      common: { all: 'Semua', group: 'Kelompok', kind: 'Jenis', filterNoOptions: 'Belum ada pilihan' },
      tutor: {
        activities: {
          kindTugas: 'Tugas',
          kindKuis: 'Kuis',
          kindMateriBaca: 'Materi baca',
        },
      },
    },
  },
};

async function mountView(groups = GROUPS) {
  setActivePinia(createPinia());
  vi.mocked(TutoringBimbelService.listGroups).mockResolvedValue({ items: groups });
  vi.mocked(ActivitiesService.listByGroup).mockResolvedValue({ items: [makeActivity()] });
  const w = mount(ActivitiesView, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'id', messages, missingWarn: false, fallbackWarn: false })],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        NavIcon: true,
        AppRichTextEditor: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        PageFilterToolbar: {
          props: ['search', 'searchPlaceholder'],
          template: '<div><slot name="chips" /></div>',
        },
        Modal: { template: '<div class="modal"><slot /></div>' },
        AsyncView: {
          props: ['state'],
          template:
            '<div data-testid="async">' +
            "<slot v-if=\"state?.status === 'content' || state?.status === 'empty'\" />" +
            '</div>',
        },
      },
    },
  });
  await flushPromises();
  await flushPromises();
  return w;
}

const chips = (w) => w.findAll('button.inline-flex');
const optionRows = (w) => w.findAll('.modal button');
const rowLabels = (w) => optionRows(w).map((b) => b.text());
const lastCall = () => {
  const calls = vi.mocked(ActivitiesService.listByGroup).mock.calls;
  return calls[calls.length - 1] ?? [];
};

beforeEach(() => vi.clearAllMocks());

describe('TutorTutoring2ActivitiesView — Kelompok filter', () => {
  it('opens a picker listing every group the tutor can reach', async () => {
    const w = await mountView();
    expect(optionRows(w)).toHaveLength(0);
    await chips(w)[0].trigger('click');
    expect(rowLabels(w)).toEqual(['UTBK Pagi A', 'UTBK Siang B', 'Reguler SMA']);
  });

  it('offers no "Semua" row — no request means "all groups"', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    // Guard against a vacuous pass: the picker must actually be open.
    expect(rowLabels(w).length).toBe(GROUPS.length);
    expect(rowLabels(w)).not.toContain('Semua');
  });

  it('jumps straight to the LAST group in one press', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Reguler SMA').trigger('click');
    await flushPromises();
    // the old cycle needed two presses to get here, each one a request
    expect(lastCall()[0]).toBe('g-3');
    expect(chips(w)[0].text()).toContain('Reguler SMA');
  });

  it.each(GROUPS)('$name is reachable and loads its own activities', async (g) => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === g.name).trigger('click');
    await flushPromises();
    expect(lastCall()[0]).toBe(g.id);
  });

  it('disables the chip when the tutor has no groups', async () => {
    const w = await mountView([]);
    expect(chips(w)[0].attributes('disabled')).toBeDefined();
  });
});

describe('TutorTutoring2ActivitiesView — Jenis filter', () => {
  it('opens a picker listing every activity kind', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'Tugas', 'Kuis', 'Materi baca']);
  });

  it.each([
    ['Tugas', 'tugas'],
    ['Kuis', 'kuis'],
    ['Materi baca', 'materi_baca'],
  ])('selecting %s asks the server for %s', async (label, wire) => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === label).trigger('click');
    await flushPromises();
    expect(lastCall()[1]?.kind).toBe(wire);
    expect(chips(w)[1].text()).toContain(label);
  });

  it('"Semua" drops the kind parameter', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Kuis').trigger('click');
    await flushPromises();
    expect(lastCall()[1]?.kind).toBe('kuis');
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(lastCall()[1]?.kind).toBeUndefined();
  });
});
