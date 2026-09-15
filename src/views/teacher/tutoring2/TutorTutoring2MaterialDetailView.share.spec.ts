/**
 * "Kirim ke wali" on the material detail — the control that was missing.
 *
 * ── The defect this covers ──
 *
 * `CreateMaterialAction` does not set `published_at`, so every material
 * is born a DRAFT, and that is deliberate: a tutor's lesson prep should
 * not land in a parent's app the moment it is uploaded.
 * `MaterialController@index` then hides drafts from anyone without
 * `tutoring.material.manage`. Put together, and with no publish route
 * until MR !867, the consequence was absolute: no wali and no siswa had
 * ever seen a single teaching material.
 *
 * ── What is pinned here ──
 *
 *  1. The send press calls `publish` with THIS material's id.
 *  2. The withdraw press calls `unpublish` — a separate verb, not a
 *     second `publish` and not a PUT with a flag. `published_at` is not
 *     in `UpdateMaterialRequest::rules()` at all, so a form-shaped
 *     implementation would answer 200 and change nothing.
 *  3. Neither control is offered without `tutoring.material.manage`,
 *     which is what both routes authorize. Read through `useMe().can`,
 *     scoped to the ACTIVE role by `X-Active-Role` — never
 *     `roles[].permission_keys`, which is unscoped.
 *  4. The state renders from `is_published`, the boolean the resource
 *     sends, NOT from a client-side truthiness test on the nullable
 *     `published_at`. The two drift, and the fixture in
 *     `renders the SENT state from is_published…` below is exactly that
 *     drift made visible.
 *  5. The screen re-reads after the call, so the badge cannot keep
 *     showing the pre-press value.
 *
 * The service mock is a small fake server: publish/unpublish mutate the
 * stored row and `show` answers from the same store, so a view that
 * failed to reload would visibly fail assertion 5 rather than passing on
 * a stale render.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import MaterialDetail from './TutorTutoring2MaterialDetailView.vue';

const serviceMock = vi.hoisted(() => ({
  show: vi.fn(),
  publish: vi.fn(),
  unpublish: vi.fn(),
}));
const routeMock = vi.hoisted(() => ({ id: 'mat-7', query: {} as Record<string, string> }));
const abilityMock = vi.hoisted(() => ({ can: vi.fn(() => true) }));

vi.mock('@/services/tutoring2/materials', () => ({
  MaterialsService: {
    show: serviceMock.show,
    publish: serviceMock.publish,
    unpublish: serviceMock.unpublish,
    list: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    uploadFile: vi.fn(),
    destroy: vi.fn(),
  },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: routeMock.id }, query: routeMock.query }),
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: abilityMock.can, canAny: () => true }),
}));

const TOASTS: string[] = [];
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({
    success: (m: string) => TOASTS.push(m),
    error: (m: string) => TOASTS.push(m),
    info: (m: string) => TOASTS.push(m),
  }),
}));

let STORE: Record<string, Record<string, unknown>> = {};

function seed(overrides: Record<string, unknown> = {}) {
  STORE = {
    'mat-7': {
      id: 'mat-7',
      learning_group_id: 'grp-3',
      learning_group_name: 'UTBK Pagi A',
      program_id: 'pr-1',
      program_name: 'Intensif UTBK',
      title: 'Ringkasan Vektor',
      description: 'Rangkuman bab vektor.',
      file_url: 'https://r2.example.com/x.pdf?X-Amz-Signature=deadbeef',
      file_name: 'ringkasan-vektor.pdf',
      file_size: 1_258_291,
      file_mime: 'application/pdf',
      kind: 'PDF',
      uploaded_by_user_id: 'u-9',
      uploaded_by_name: 'Bu Sinta',
      published_at: null,
      is_published: false,
      created_at: '2026-08-20T09:00:00+07:00',
      updated_at: '2026-08-20T09:00:00+07:00',
      ...overrides,
    },
  };
}

const messages = {
  id: {
    common: { loading: 'Memuat…', errorTitle: 'Gagal memuat', errorMessage: 'Terjadi kesalahan', emptyTitle: 'Kosong' },
    tutoring2: {
      common: {
        roleTutor: 'Tutor', title: 'Judul', kind: 'Jenis', program: 'Program',
        group: 'Kelompok', description: 'Deskripsi', file: 'Berkas',
        edit: 'Ubah', save: 'Simpan', cancel: 'Batal', saveFailed: 'Gagal menyimpan.',
        loading: 'Memuat…',
      },
      materialKind: { PDF: 'PDF', VIDEO: 'Video', DOC: 'Dokumen', IMAGE: 'Gambar', LINK: 'Tautan' },
      tutor: {
        materialDetail: {
          title: 'Detail materi', notFound: 'Materi tidak ditemukan', notFoundHint: 'Sudah dihapus.',
          linkLabel: 'Tautan', openLink: 'Buka tautan', openFile: 'Buka berkas', download: 'Unduh',
          downloadFallback: 'Dibuka di tab baru.', downloadBlocked: 'Popup diblokir.',
          noSource: 'Tidak ada berkas.',
          uploadedBy: 'Diunggah oleh', createdAt: 'Dibuat',
          shared: 'Terkirim ke wali', notShared: 'Belum dikirim',
          sendToGuardian: 'Kirim ke wali',
          withdrawFromGuardian: 'Tarik dari wali',
          sentAt: 'Dikirim',
          draftHint: 'Belum dikirim — hanya Anda yang bisa melihat materi ini.',
          sharedHint: 'Sudah bisa dibuka wali dan siswa.',
          sendSuccess: 'Materi dikirim ke wali.',
          withdrawSuccess: 'Materi ditarik dari wali.',
          editTitle: 'Ubah materi', saved: 'Perubahan materi tersimpan.',
          editReadOnlyNote: 'Berkas tidak bisa diubah di sini.',
        },
      },
    },
  },
};

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(MaterialDetail, {
    global: {
      plugins: [
        createI18n({ legacy: false, locale: 'id', messages, missingWarn: false, fallbackWarn: false }),
      ],
      stubs: {
        BrandPageHeader: true,
        StatusBadge: { props: ['label'], template: '<span>{{ label }}</span>' },
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        Modal: { template: '<div data-testid="modal"><slot /></div>' },
        BottomSheetFooter: {
          props: ['primaryLabel', 'secondaryLabel', 'primaryDisabled', 'primaryLoading'],
          emits: ['primary', 'secondary'],
          template:
            '<div><button data-testid="modal-save" :disabled="primaryDisabled" @click="$emit(\'primary\')">{{ primaryLabel }}</button>' +
            '<button data-testid="modal-cancel" @click="$emit(\'secondary\')">{{ secondaryLabel }}</button></div>',
        },
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
  TOASTS.length = 0;
  seed();
  routeMock.id = 'mat-7';
  routeMock.query = {};
  abilityMock.can.mockImplementation(() => true);

  serviceMock.show.mockImplementation(async (id: string) => {
    const row = STORE[id];
    if (!row) throw new Error('Request failed with status code 404');
    return { ...row };
  });
  // A fake server that really flips the row, so a missing reload shows up.
  serviceMock.publish.mockImplementation(async (id: string) => {
    const row = STORE[id];
    if (!row) throw new Error('Request failed with status code 404');
    row.published_at = '2026-09-15T02:00:00+07:00';
    row.is_published = true;
    return { ...row };
  });
  serviceMock.unpublish.mockImplementation(async (id: string) => {
    const row = STORE[id];
    if (!row) throw new Error('Request failed with status code 404');
    row.published_at = null;
    row.is_published = false;
    return { ...row };
  });
  vi.spyOn(window, 'open').mockImplementation(() => null);
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('TutorTutoring2MaterialDetailView — kirim ke wali', () => {
  it('the send action calls publish with this material id', async () => {
    const w = await mountView();

    await w.get('[data-testid="material-send-to-guardian"]').trigger('click');
    await flushPromises();

    expect(serviceMock.publish).toHaveBeenCalledTimes(1);
    expect(serviceMock.publish).toHaveBeenCalledWith('mat-7');
    // Never the other direction, and never a PUT-with-a-flag: the
    // column is not writable through `update`.
    expect(serviceMock.unpublish).not.toHaveBeenCalled();
  });

  it('carries the id from the route, not a hardcoded one', async () => {
    routeMock.id = 'mat-99';
    STORE['mat-99'] = { ...STORE['mat-7'], id: 'mat-99' };

    const w = await mountView();
    await w.get('[data-testid="material-send-to-guardian"]').trigger('click');
    await flushPromises();

    expect(serviceMock.publish).toHaveBeenCalledWith('mat-99');
  });

  it('the withdraw action calls unpublish', async () => {
    seed({ published_at: '2026-09-10T02:00:00+07:00', is_published: true });

    const w = await mountView();

    await w.get('[data-testid="material-withdraw-from-guardian"]').trigger('click');
    await flushPromises();

    expect(serviceMock.unpublish).toHaveBeenCalledTimes(1);
    expect(serviceMock.unpublish).toHaveBeenCalledWith('mat-7');
    expect(serviceMock.publish).not.toHaveBeenCalled();
  });

  it('offers only the opposite action for the current state', async () => {
    const draft = await mountView();
    expect(draft.find('[data-testid="material-send-to-guardian"]').exists()).toBe(true);
    expect(draft.find('[data-testid="material-withdraw-from-guardian"]').exists()).toBe(false);

    seed({ published_at: '2026-09-10T02:00:00+07:00', is_published: true });
    const sent = await mountView();
    expect(sent.find('[data-testid="material-send-to-guardian"]').exists()).toBe(false);
    expect(sent.find('[data-testid="material-withdraw-from-guardian"]').exists()).toBe(true);
  });

  it('hides the control from a tutor without tutoring.material.manage', async () => {
    abilityMock.can.mockImplementation((key: string) => key !== 'tutoring.material.manage');

    const w = await mountView();

    expect(w.find('[data-testid="material-send-to-guardian"]').exists()).toBe(false);
    expect(w.find('[data-testid="material-withdraw-from-guardian"]').exists()).toBe(false);
    // The read side still works — `show` only needs `.view`.
    expect(w.get('[data-testid="material-title"]').text()).toBe('Ringkasan Vektor');
  });

  it('shows the control to a tutor who holds tutoring.material.manage', async () => {
    abilityMock.can.mockImplementation((key: string) => key === 'tutoring.material.manage');

    const w = await mountView();

    expect(w.find('[data-testid="material-send-to-guardian"]').exists()).toBe(true);
  });

  /**
   * The state is the `is_published` boolean, full stop.
   *
   * This fixture deliberately contradicts itself — `published_at` is a
   * non-null timestamp while `is_published` is false — because that is
   * the only way to tell the two implementations apart. A view deriving
   * the state from `Boolean(published_at)` renders SENT here and fails.
   */
  it('renders the SENT state from is_published, not from published_at', async () => {
    seed({ published_at: '2026-09-10T02:00:00+07:00', is_published: false });

    const w = await mountView();

    expect(w.get('[data-testid="material-publication"]').text()).toBe('Belum dikirim');
    expect(w.find('[data-testid="material-send-to-guardian"]').exists()).toBe(true);
    expect(w.find('[data-testid="material-draft-notice"]').exists()).toBe(true);
  });

  it('labels a sent material as reachable by wali', async () => {
    seed({ published_at: '2026-09-10T02:00:00+07:00', is_published: true });

    const w = await mountView();

    expect(w.get('[data-testid="material-publication"]').text()).toBe('Terkirim ke wali');
    // The privacy warning belongs to the draft state only.
    expect(w.find('[data-testid="material-draft-notice"]').exists()).toBe(false);
  });

  it('spells out that an unsent material stays private to the tutor', async () => {
    const w = await mountView();

    const notice = w.get('[data-testid="material-draft-notice"]').text();
    expect(notice).toContain('hanya Anda');
  });

  it('re-reads after sending so the badge cannot show a stale state', async () => {
    const w = await mountView();
    expect(w.get('[data-testid="material-publication"]').text()).toBe('Belum dikirim');

    await w.get('[data-testid="material-send-to-guardian"]').trigger('click');
    await flushPromises();

    expect(serviceMock.show).toHaveBeenCalledTimes(2);
    expect(w.get('[data-testid="material-publication"]').text()).toBe('Terkirim ke wali');
    expect(w.find('[data-testid="material-withdraw-from-guardian"]').exists()).toBe(true);
    expect(TOASTS).toContain('Materi dikirim ke wali.');
  });

  it('re-reads after withdrawing too', async () => {
    seed({ published_at: '2026-09-10T02:00:00+07:00', is_published: true });

    const w = await mountView();
    await w.get('[data-testid="material-withdraw-from-guardian"]').trigger('click');
    await flushPromises();

    expect(w.get('[data-testid="material-publication"]').text()).toBe('Belum dikirim');
    expect(w.find('[data-testid="material-send-to-guardian"]').exists()).toBe(true);
    expect(TOASTS).toContain('Materi ditarik dari wali.');
  });

  it('surfaces the server message and claims nothing when the send fails', async () => {
    serviceMock.publish.mockRejectedValueOnce(
      new Error('Request failed with status code 404'),
    );

    const w = await mountView();
    await w.get('[data-testid="material-send-to-guardian"]').trigger('click');
    await flushPromises();

    expect(TOASTS).toContain('Request failed with status code 404');
    // Still a draft on screen — nothing pretends the send landed.
    expect(w.get('[data-testid="material-publication"]').text()).toBe('Belum dikirim');
  });
});
