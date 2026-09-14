/**
 * Contract spec for the Program + Tipe chips on the tutor's "Materi"
 * screen. Both were blind toggles with no menu, and both had a real bug
 * underneath the missing menu:
 *
 *   • PROGRAM sent a program NAME into the `program_id` parameter
 *     (`nextProgramFilter()` returned `contentItems[0].program_name`),
 *     so the server was asked to match a uuid column against a title
 *     and no row could come back. Only the first loaded material's
 *     program was reachable at all.
 *   • TIPE offered three of the five `MaterialKind` values — LINK and
 *     IMAGE were unreachable at any number of presses.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import MaterialsView from './TutorTutoring2MaterialsView.vue';
import { MaterialsService } from '@/services/tutoring2/materials';

vi.mock('@/services/tutoring2/materials', () => ({
  MaterialsService: { list: vi.fn(), destroy: vi.fn() },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

function makeMaterial(o = {}) {
  return {
    id: 'm-1',
    learning_group_id: null,
    learning_group_name: null,
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    title: 'Bab 1',
    description: null,
    file_url: null,
    file_name: null,
    file_size: null,
    file_mime: 'application/pdf',
    kind: 'PDF',
    uploaded_by_user_id: null,
    published_at: null,
    ...o,
  };
}

const ROWS = [
  makeMaterial(),
  makeMaterial({ id: 'm-2', program_id: 'pr-2', program_name: 'Reguler SMA', kind: 'LINK', file_mime: null }),
  makeMaterial({ id: 'm-3', program_id: 'pr-2', program_name: 'Reguler SMA', kind: 'IMAGE', file_mime: 'image/png' }),
];

const messages = {
  id: {
    tutoring2: {
      common: { all: 'Semua', program: 'Program', type: 'Tipe', filterNoOptions: 'Belum ada pilihan' },
      materialKind: { PDF: 'PDF', VIDEO: 'Video', DOC: 'Dokumen', IMAGE: 'Gambar', LINK: 'Tautan' },
    },
  },
};

async function mountView(rows = ROWS) {
  setActivePinia(createPinia());
  vi.mocked(MaterialsService.list).mockResolvedValue({ items: rows });
  const w = mount(MaterialsView, {
    global: {
      plugins: [createI18n({ legacy: false, locale: 'id', messages, missingWarn: false, fallbackWarn: false })],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        TutoringMaterialRow: { props: ['material'], template: '<li data-testid="row">{{ material.id }}</li>' },
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
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
  return w;
}

const chips = (w) => w.findAll('button.inline-flex');
const optionRows = (w) => w.findAll('.modal button');
const rowLabels = (w) => optionRows(w).map((b) => b.text());
const lastParams = () => {
  const calls = vi.mocked(MaterialsService.list).mock.calls;
  return calls[calls.length - 1]?.[0] ?? {};
};

beforeEach(() => vi.clearAllMocks());

describe('TutorTutoring2MaterialsView — Program filter', () => {
  it('lists every program by NAME and keys them by id', async () => {
    const w = await mountView();
    expect(optionRows(w)).toHaveLength(0);
    await chips(w)[0].trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'Intensif UTBK', 'Reguler SMA']);
  });

  it('sends an ID as program_id, not a name', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Reguler SMA').trigger('click');
    await flushPromises();
    expect(lastParams().program_id).toBe('pr-2');
    // the old code sent the NAME here — pin that it never comes back
    expect(lastParams().program_id).not.toBe('Reguler SMA');
    expect(chips(w)[0].text()).toContain('Reguler SMA');
  });

  it('reaches a program other than the first row’s — the old cycle could not', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Reguler SMA').trigger('click');
    await flushPromises();
    expect(lastParams().program_id).toBe('pr-2');
  });

  it('"Semua" drops the program_id parameter', async () => {
    const w = await mountView();
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Intensif UTBK').trigger('click');
    await flushPromises();
    expect(lastParams().program_id).toBe('pr-1');
    await chips(w)[0].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(lastParams().program_id).toBeUndefined();
  });
});

describe('TutorTutoring2MaterialsView — Tipe filter', () => {
  it('lists all five MaterialKind values', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    expect(rowLabels(w)).toEqual(['Semua', 'PDF', 'Video', 'Dokumen', 'Gambar', 'Tautan']);
  });

  it.each([
    ['PDF', 'PDF'],
    ['Video', 'VIDEO'],
    ['Dokumen', 'DOC'],
    ['Gambar', 'IMAGE'],
    ['Tautan', 'LINK'],
  ])('selecting %s asks the server for %s', async (label, wire) => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === label).trigger('click');
    await flushPromises();
    expect(lastParams().kind).toBe(wire);
  });

  it.each([
    ['Tautan', 'm-2'],
    ['Gambar', 'm-3'],
  ])('%s — previously unreachable — actually narrows the list', async (label, keptId) => {
    const w = await mountView();
    expect(w.findAll('[data-testid="row"]')).toHaveLength(3);
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === label).trigger('click');
    await flushPromises();
    const rows = w.findAll('[data-testid="row"]');
    expect(rows).toHaveLength(1);
    expect(rows[0].text()).toBe(keptId);
  });

  it('"Semua" restores the full list', async () => {
    const w = await mountView();
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Tautan').trigger('click');
    await flushPromises();
    expect(w.findAll('[data-testid="row"]')).toHaveLength(1);
    await chips(w)[1].trigger('click');
    await optionRows(w).find((b) => b.text() === 'Semua').trigger('click');
    await flushPromises();
    expect(w.findAll('[data-testid="row"]')).toHaveLength(3);
  });
});
