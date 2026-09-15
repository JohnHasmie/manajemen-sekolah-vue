/**
 * Contract spec for editing a material — the write side.
 *
 * Three things the screen could get wrong, and each has bitten this
 * codebase before:
 *
 *  1. SENDING A FIELD THE SERVER DROPS. `MaterialResource` returns
 *     seventeen fields; `UpdateMaterialRequest::rules()` accepts seven,
 *     and anything outside them is discarded while the request still
 *     answers 200 — a form that looks like it saved and did not. The
 *     payload assertion below is exact-keys, not `objectContaining`, so
 *     a stray `learning_group_id` or a round-tripped `file_url` fails
 *     it.
 *
 *  2. OFFERING A CONTROL THE SERVER WILL REFUSE. `update` authorizes on
 *     `tutoring.material.manage`. A tutor whose centre revoked it must
 *     see no edit affordance at all rather than a button that 403s.
 *
 *  3. RENDERING THE PUT RESPONSE. It comes back without the eager loads,
 *     so `learning_group_name` / `program_name` / `uploaded_by_name` are
 *     ABSENT from it — the screen has to re-read with `show()`. The
 *     "reflected back" test below checks the saved title AND that the
 *     group name survives.
 *
 * The service mock is a tiny fake server: `update` validates the id,
 * applies the patch to the stored row, and `show` answers from the same
 * store. A mock that ignored its arguments would make every assertion
 * here vacuous.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import MaterialDetail from './TutorTutoring2MaterialDetailView.vue';

const serviceMock = vi.hoisted(() => ({ show: vi.fn(), update: vi.fn() }));
const routeMock = vi.hoisted(() => ({ id: 'mat-7', query: {} as Record<string, string> }));
const abilityMock = vi.hoisted(() => ({ can: vi.fn(() => true) }));

vi.mock('@/services/tutoring2/materials', () => ({
  MaterialsService: {
    show: serviceMock.show,
    update: serviceMock.update,
    list: vi.fn(),
    create: vi.fn(),
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

/** The fake server's row store, reset for every test. */
let STORE: Record<string, Record<string, unknown>> = {};

function seed() {
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
          downloadFallback: 'Dibuka di tab baru.', noSource: 'Tidak ada berkas.',
          uploadedBy: 'Diunggah oleh', createdAt: 'Dibuat',
          shared: 'Terkirim ke wali', notShared: 'Belum dikirim',
          sendToGuardian: 'Kirim ke wali', withdrawFromGuardian: 'Tarik dari wali',
          draftHint: 'Belum dikirim.', editTitle: 'Ubah materi', saved: 'Perubahan materi tersimpan.',
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

  // A fake server, not a rubber stamp.
  serviceMock.show.mockImplementation(async (id: string) => {
    const row = STORE[id];
    if (!row) throw new Error('Request failed with status code 404');
    return { ...row };
  });
  serviceMock.update.mockImplementation(async (id: string, payload) => {
    const row = STORE[id];
    // `writableMaterialOrFail` re-applies the read scope before
    // findOrFail, so an unreachable id is a 404 here — never a 403.
    if (!row) throw new Error('Request failed with status code 404');
    Object.assign(row, payload);
    // What the controller really returns: the Action's `fresh()`, with
    // no eager loads, so the three `*_name` fields are ABSENT.
    const { learning_group_name, program_name, uploaded_by_name, ...rest } = row;
    return { ...rest };
  });
  vi.spyOn(window, 'open').mockImplementation(() => null);
});

afterEach(() => {
  vi.restoreAllMocks();
});

async function openForm(w) {
  await w.get('[data-testid="material-edit"]').trigger('click');
  await flushPromises();
  return w;
}

describe('TutorTutoring2MaterialDetailView — editing', () => {
  /**
   * Batal must CLOSE, never SAVE.
   *
   * The cancel button existed only as a stub declaration until now — no
   * test ever pressed it. Rewiring `@secondary` to `submitEdit` left the
   * whole suite green, which means a Batal button that silently saves the
   * tutor's half-finished edit could have shipped. The stub emits the same
   * `secondary` event the real BottomSheetFooter does, so pressing it here
   * exercises the real handler binding.
   */
  it('Batal closes the editor WITHOUT saving', async () => {
    const w = await openForm(await mountView());

    await w.get('[data-testid="material-edit-title"]').setValue('Judul yang dibatalkan');
    await w.get('[data-testid="modal-cancel"]').trigger('click');
    await flushPromises();

    expect(serviceMock.update).not.toHaveBeenCalled();
    expect(w.find('[data-testid="material-edit-title"]').exists()).toBe(false);
  });

  it('sends ONLY the fields UpdateMaterialRequest::rules() accepts', async () => {
    const w = await openForm(await mountView());

    await w.get('[data-testid="material-edit-title"]').setValue('Ringkasan Vektor (revisi)');
    await w.get('[data-testid="material-edit-description"]').setValue('Diperbarui.');
    await w.get('[data-testid="material-edit-kind"]').setValue('DOC');
    await w.get('[data-testid="modal-save"]').trigger('click');
    await flushPromises();

    expect(serviceMock.update).toHaveBeenCalledTimes(1);
    const [id, payload] = serviceMock.update.mock.calls[0];
    expect(id).toBe('mat-7');
    // Exact keys. `file_url` in particular must NOT be round-tripped:
    // the GET value is a 30-minute signed URL, and writing it back would
    // store an expiring link permanently and lose the disk key.
    expect(Object.keys(payload).sort()).toEqual(['description', 'kind', 'title']);
    expect(payload).toEqual({
      title: 'Ringkasan Vektor (revisi)',
      description: 'Diperbarui.',
      kind: 'DOC',
    });
  });

  it('reflects a saved change back on screen, group name included', async () => {
    const w = await openForm(await mountView());

    await w.get('[data-testid="material-edit-title"]').setValue('Judul Baru');
    await w.get('[data-testid="modal-save"]').trigger('click');
    await flushPromises();

    expect(w.get('[data-testid="material-title"]').text()).toBe('Judul Baru');
    // The PUT response carries no `learning_group_name`; only a re-read
    // through `show()` brings it back. If the view spliced the response
    // in, this line would be gone.
    expect(w.text()).toContain('UTBK Pagi A');
    expect(serviceMock.show).toHaveBeenCalledTimes(2);
    expect(TOASTS).toContain('Perubahan materi tersimpan.');
  });

  it('turns an emptied description into null rather than an empty string', async () => {
    const w = await openForm(await mountView());

    await w.get('[data-testid="material-edit-description"]').setValue('   ');
    await w.get('[data-testid="modal-save"]').trigger('click');
    await flushPromises();

    expect(serviceMock.update.mock.calls[0][1].description).toBeNull();
  });

  it('prefills the form from the material rather than starting blank', async () => {
    const w = await openForm(await mountView());

    expect(w.get('[data-testid="material-edit-title"]').element.value).toBe('Ringkasan Vektor');
    expect(w.get('[data-testid="material-edit-description"]').element.value).toBe(
      'Rangkuman bab vektor.',
    );
    expect(w.get('[data-testid="material-edit-kind"]').element.value).toBe('PDF');
  });

  it('refuses a title shorter than the server minimum instead of eating the 422', async () => {
    const w = await openForm(await mountView());

    await w.get('[data-testid="material-edit-title"]').setValue('ab');
    expect(w.get('[data-testid="modal-save"]').attributes('disabled')).toBeDefined();

    await w.get('[data-testid="modal-save"]').trigger('click');
    await flushPromises();
    expect(serviceMock.update).not.toHaveBeenCalled();
  });

  it('shows NO edit action to a tutor without tutoring.material.manage', async () => {
    abilityMock.can.mockImplementation((key: string) => key !== 'tutoring.material.manage');

    const w = await mountView();

    expect(w.find('[data-testid="material-edit"]').exists()).toBe(false);
    // And the read side still works — it is a read-only screen, not a
    // bounce: `show` only needs `tutoring.material.view`.
    expect(w.get('[data-testid="material-title"]').text()).toBe('Ringkasan Vektor');
  });

  it('keeps the form open and surfaces the server message when the save fails', async () => {
    serviceMock.update.mockRejectedValueOnce(
      new Error('Request failed with status code 404'),
    );

    const w = await openForm(await mountView());
    await w.get('[data-testid="material-edit-title"]').setValue('Judul Baru');
    await w.get('[data-testid="modal-save"]').trigger('click');
    await flushPromises();

    expect(w.find('[data-testid="modal"]').exists()).toBe(true);
    expect(TOASTS).toContain('Request failed with status code 404');
    // Nothing on screen claims the change landed.
    expect(w.get('[data-testid="material-title"]').text()).toBe('Ringkasan Vektor');
  });

  it('opens the form straight away when the list row asked to edit (?edit=1)', async () => {
    routeMock.query = { edit: '1' };

    const w = await mountView();

    expect(w.find('[data-testid="modal"]').exists()).toBe(true);
    expect(w.get('[data-testid="material-edit-title"]').element.value).toBe('Ringkasan Vektor');
  });

  it('does not open the form from ?edit=1 for a tutor who may not edit', async () => {
    routeMock.query = { edit: '1' };
    abilityMock.can.mockImplementation((key: string) => key !== 'tutoring.material.manage');

    const w = await mountView();

    expect(w.find('[data-testid="modal"]').exists()).toBe(false);
  });
});
