/**
 * Pressing a material must open the DETAIL screen, not the file.
 *
 * The list used to wire both row events to the same function:
 *
 *     const onDownload = openFile;
 *     const onOpen = openFile;
 *
 * so a title press called `window.open(material.file_url, …)` and threw
 * the tutor out of the app into a storage-bucket URL. There was no step
 * in between that could show the description, the group, the publication
 * state — or offer an edit.
 *
 * Own file rather than an addition to `…MaterialsView.filters.spec.ts`:
 * that spec STUBS `TutoringMaterialRow` down to `<li>{{ material.id }}</li>`,
 * so no row event is reachable from it at all. This one mounts the real
 * row, which is the only way the assertion below can be about the thing
 * a tutor actually presses.
 */
// @ts-nocheck — vitest types optional in this workspace
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import MaterialsView from './TutorTutoring2MaterialsView.vue';
import TutoringMaterialRow from '@/components/tutoring/TutoringMaterialRow.vue';

const routerMock = vi.hoisted(() => ({ push: vi.fn() }));
const serviceMock = vi.hoisted(() => ({ list: vi.fn(), destroy: vi.fn() }));
const abilityMock = vi.hoisted(() => ({ can: vi.fn(() => true) }));

vi.mock('@/services/tutoring2/materials', () => ({
  MaterialsService: {
    list: serviceMock.list,
    destroy: serviceMock.destroy,
  },
}));
vi.mock('vue-router', () => ({
  useRouter: () => ({ push: routerMock.push }),
  useRoute: () => ({ params: {}, query: {} }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));
vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: abilityMock.can, canAny: () => true }),
}));

const OPENED: string[] = [];

function makeMaterial(o = {}) {
  return {
    id: 'mat-1',
    learning_group_id: null,
    learning_group_name: null,
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    title: 'Ringkasan Vektor',
    description: null,
    file_url: 'https://bucket.example/signed/vektor.pdf?sig=abc',
    file_name: 'vektor.pdf',
    file_size: 1_258_291,
    file_mime: 'application/pdf',
    kind: 'PDF',
    uploaded_by_user_id: 'u-1',
    published_at: null,
    ...o,
  };
}

const ROWS = [
  makeMaterial(),
  makeMaterial({ id: 'mat-42', title: 'Soal Latihan Bab 2' }),
];

const messages = {
  id: {
    tutoring2: {
      common: {
        all: 'Semua', program: 'Program', type: 'Tipe', roleTutor: 'Tutor',
        filterNoOptions: 'Tidak ada pilihan', error: 'Gagal',
        open: 'Buka', download: 'Unduh', edit: 'Ubah', delete: 'Hapus',
      },
      materialKind: { PDF: 'PDF', VIDEO: 'Video', DOC: 'Dokumen', IMAGE: 'Gambar', LINK: 'Tautan' },
      tutor: {
        materials: {
          title: 'Materi',
          meta: '{count} materi',
          emptyTitle: 'Belum ada materi',
          emptyDescription: 'Unggah materi pertama.',
          uploadCta: 'Unggah materi',
          noFile: 'Materi ini tidak punya berkas.',
          deleted: 'Materi dihapus.',
          kpiTotal: 'Total', kpiPdf: 'PDF', kpiVideo: 'Video', kpiOther: 'Lainnya',
        },
      },
    },
  },
};

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(MaterialsView, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
        AppFilterChip: true,
        FilterFacetPickerModal: true,
        // The REAL row — the button under test lives in it.
        TutoringMaterialRow,
        AsyncView: {
          props: ['state'],
          template:
            '<div :data-status="state?.status">' +
            "<slot v-if=\"state?.status === 'content'\" :data=\"state.data\" /></div>",
        },
      },
    },
  });
  await flushPromises();
  return w;
}

/** The title element the tutor presses, for a given material title. */
function titleButton(w, title: string) {
  return w
    .findAllComponents(TutoringMaterialRow)
    .find((row) => row.props('material').title === title)
    .findAll('button')
    .find((b) => b.text().includes(title));
}

describe('TutorTutoring2MaterialsView — pressing a material', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    abilityMock.can.mockImplementation(() => true);
    OPENED.length = 0;
    // Records what would have left the app. The old implementation
    // called this on a title press; the new one must not.
    vi.spyOn(window, 'open').mockImplementation((url) => {
      OPENED.push(String(url));
      return null;
    });
    // Faithful: answers with the rows, and records the query it was asked.
    serviceMock.list.mockImplementation(async () => ({
      items: ROWS,
      pagination: undefined,
    }));
  });

  it('navigates to the detail route carrying THAT row id', async () => {
    const w = await mountView();

    await titleButton(w, 'Soal Latihan Bab 2').trigger('click');

    expect(routerMock.push).toHaveBeenCalledWith({
      name: 'teacher.tutoring2.material-detail',
      params: { id: 'mat-42' },
    });
  });

  it('does not jump straight out to the file', async () => {
    const w = await mountView();

    await titleButton(w, 'Ringkasan Vektor').trigger('click');

    // The signed bucket URL is exactly what the old handler opened.
    expect(OPENED).toEqual([]);
  });

  it('sends the id of the row that was pressed, not the first one', async () => {
    const w = await mountView();

    await titleButton(w, 'Ringkasan Vektor').trigger('click');
    expect(routerMock.push).toHaveBeenLastCalledWith(
      expect.objectContaining({ params: { id: 'mat-1' } }),
    );

    await titleButton(w, 'Soal Latihan Bab 2').trigger('click');
    expect(routerMock.push).toHaveBeenLastCalledWith(
      expect.objectContaining({ params: { id: 'mat-42' } }),
    );
  });

  it('keeps the row "Unduh" shortcut going straight to the file', async () => {
    const w = await mountView();

    const row = w
      .findAllComponents(TutoringMaterialRow)
      .find((r) => r.props('material').id === 'mat-1');
    await row.find('[aria-label="Unduh Ringkasan Vektor"]').trigger('click');

    expect(OPENED).toEqual(['https://bucket.example/signed/vektor.pdf?sig=abc']);
  });

  it('offers "Ubah" on a row and carries ?edit=1 so the button really edits', async () => {
    const w = await mountView();

    const row = w
      .findAllComponents(TutoringMaterialRow)
      .find((r) => r.props('material').id === 'mat-42');
    await row.find('[aria-label="Ubah Soal Latihan Bab 2"]').trigger('click');

    expect(routerMock.push).toHaveBeenCalledWith({
      name: 'teacher.tutoring2.material-detail',
      params: { id: 'mat-42' },
      query: { edit: '1' },
    });
  });

  it('offers neither Ubah nor Hapus without tutoring.material.manage', async () => {
    // Both writes authorize on that one key server-side, so a tutor
    // whose centre revoked it must see no control that would 403.
    abilityMock.can.mockImplementation((key: string) => key !== 'tutoring.material.manage');

    const w = await mountView();

    expect(w.find('[aria-label="Ubah Ringkasan Vektor"]').exists()).toBe(false);
    expect(w.find('[aria-label="Hapus Ringkasan Vektor"]').exists()).toBe(false);
    // The read side is untouched.
    expect(w.find('[aria-label="Unduh Ringkasan Vektor"]').exists()).toBe(true);
  });

  it('labels the row action "Buka" for a pasted link, not "Unduh"', async () => {
    // Nothing for this app to save — the bytes live on someone else's
    // host. The null file_name/file_size/file_mime triple is what
    // identifies it; `kind` says PDF because the upload form has no LINK
    // chip.
    serviceMock.list.mockImplementation(async () => ({
      items: [
        makeMaterial({
          id: 'mat-link',
          title: 'Video pembahasan',
          file_url: 'https://drive.google.com/file/d/xyz/view',
          file_name: null,
          file_size: null,
          file_mime: null,
        }),
      ],
      pagination: undefined,
    }));

    const w = await mountView();

    expect(w.find('[aria-label="Buka Video pembahasan"]').exists()).toBe(true);
    expect(w.find('[aria-label="Unduh Video pembahasan"]').exists()).toBe(false);
  });
});
