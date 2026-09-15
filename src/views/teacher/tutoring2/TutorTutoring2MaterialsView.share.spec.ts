/**
 * Which materials can wali actually open? Answerable from the LIST.
 *
 * Materials are created as drafts and `MaterialController@index` filters
 * unsent rows out for anyone without `tutoring.material.manage`, so two
 * rows that look identical to a tutor can differ on the one thing that
 * matters: whether a parent sees them at all. Before this badge the only
 * way to find out was to open each material in turn.
 *
 * Mounts the REAL `TutoringMaterialRow` — a stubbed row could not show
 * the badge, and the assertion would be about nothing.
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
    publish: vi.fn(),
    unpublish: vi.fn(),
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
    is_published: false,
    ...o,
  };
}

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
          sharedBadge: 'Terkirim ke wali',
          notSharedBadge: 'Belum dikirim',
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

beforeEach(() => {
  vi.clearAllMocks();
  abilityMock.can.mockImplementation(() => true);
});

describe('TutorTutoring2MaterialsView — shared-vs-draft at a glance', () => {
  it('labels each row from is_published', async () => {
    serviceMock.list.mockResolvedValue({
      items: [
        makeMaterial({ id: 'mat-draft', title: 'Prep Bab 4' }),
        makeMaterial({
          id: 'mat-sent',
          title: 'Soal Latihan Bab 2',
          published_at: '2026-09-10T02:00:00+07:00',
          is_published: true,
        }),
      ],
      pagination: undefined,
    });

    const w = await mountView();
    const badges = w.findAll('[data-testid="material-share-state"]');

    expect(badges).toHaveLength(2);
    expect(badges[0].text()).toBe('Belum dikirim');
    expect(badges[1].text()).toBe('Terkirim ke wali');
  });

  /**
   * The same drift fixture the detail spec uses: a non-null
   * `published_at` next to `is_published: false`. A row deriving the
   * state from the timestamp announces this draft as sent — telling the
   * tutor that parents can read something only the tutor can.
   */
  it('trusts is_published over a stale published_at', async () => {
    serviceMock.list.mockResolvedValue({
      items: [
        makeMaterial({ published_at: '2026-09-10T02:00:00+07:00', is_published: false }),
      ],
      pagination: undefined,
    });

    const w = await mountView();

    expect(w.get('[data-testid="material-share-state"]').text()).toBe('Belum dikirim');
  });
});
