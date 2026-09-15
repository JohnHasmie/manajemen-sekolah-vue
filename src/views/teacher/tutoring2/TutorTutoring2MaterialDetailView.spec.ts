/**
 * Contract spec for the tutor's material detail screen — the read side.
 *
 * Four things are pinned, and each of them is a way the screen could
 * lie:
 *
 *  1. it fetches THE material by route id, so the answer cannot be a
 *     stale row from a page of the list;
 *  2. a LINK renders an anchor to the actual target, carrying `noopener`
 *     — an external href without it hands the destination a handle on
 *     `window.opener`;
 *  3. a FILE's open and download both point at the URL the SERVER gave,
 *     and the download falls back to opening rather than dead-ending
 *     when the bucket refuses a cross-origin read;
 *  4. a 404 lands on the error branch, not a blank panel.
 *
 * The service mock RESPECTS ITS ARGUMENT: `show` looks the id up in a
 * fixture table and rejects with a 404 for anything else. A mock that
 * returned the same object whatever it was handed would make test 1
 * vacuous, which is exactly how two sibling specs went green over a
 * broken fetch this week.
 */
// @ts-nocheck — vitest types optional in this workspace
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import MaterialDetail from './TutorTutoring2MaterialDetailView.vue';

const serviceMock = vi.hoisted(() => ({ show: vi.fn() }));
const routeMock = vi.hoisted(() => ({ id: 'mat-7' }));

vi.mock('@/services/tutoring2/materials', () => ({
  MaterialsService: {
    show: serviceMock.show,
    list: vi.fn(),
    create: vi.fn(),
    uploadFile: vi.fn(),
    destroy: vi.fn(),
  },
}));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: routeMock.id }, query: {} }),
  useRouter: () => ({ push: vi.fn(), back: vi.fn() }),
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));

const TOASTS: Array<{ tone: string; msg: string }> = [];
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({
    success: (m: string) => TOASTS.push({ tone: 'success', msg: m }),
    error: (m: string) => TOASTS.push({ tone: 'error', msg: m }),
    info: (m: string) => TOASTS.push({ tone: 'info', msg: m }),
  }),
}));

/** The signed bucket URL the backend hands back for an uploaded file. */
const SIGNED_URL =
  'https://r2.example.com/bimbel/materials/sch-1/abc.pdf?X-Amz-Signature=deadbeef';
/** A tutor's pasted Drive link, which the backend returns verbatim. */
const EXTERNAL_URL = 'https://drive.google.com/file/d/xyz/view';

function makeMaterial(o = {}) {
  return {
    id: 'mat-7',
    learning_group_id: 'grp-3',
    learning_group_name: 'UTBK Pagi A',
    program_id: 'pr-1',
    program_name: 'Intensif UTBK',
    title: 'Ringkasan Vektor',
    description: 'Rangkuman bab vektor untuk pertemuan ke-3.',
    file_url: SIGNED_URL,
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
    ...o,
  };
}

/**
 * The fixture table the mock answers from. Anything not in it 404s,
 * exactly as `MaterialController@show` does for an id outside the
 * caller's read scope.
 */
const FIXTURES: Record<string, unknown> = {
  'mat-7': makeMaterial(),
  // A pasted link. The three file_* columns are null because the upload
  // step that fills them never ran — and `kind` is 'PDF' because the web
  // upload form has no LINK chip and defaults to PDF. Both halves of
  // that are real, and the screen must still call it a link.
  'mat-link': makeMaterial({
    id: 'mat-link',
    title: 'Video pembahasan',
    kind: 'PDF',
    file_url: EXTERNAL_URL,
    file_name: null,
    file_size: null,
    file_mime: null,
  }),
  // A link that DOES declare itself.
  'mat-link-declared': makeMaterial({
    id: 'mat-link-declared',
    kind: 'LINK',
    file_url: EXTERNAL_URL,
    file_name: null,
    file_size: null,
    file_mime: null,
  }),
};

const messages = {
  id: {
    common: { loading: 'Memuat…', errorTitle: 'Gagal memuat', errorMessage: 'Terjadi kesalahan', emptyTitle: 'Kosong' },
    tutoring2: {
      common: {
        roleTutor: 'Tutor', title: 'Judul', kind: 'Jenis', program: 'Program',
        group: 'Kelompok', description: 'Deskripsi', file: 'Berkas', loading: 'Memuat…',
      },
      materialKind: { PDF: 'PDF', VIDEO: 'Video', DOC: 'Dokumen', IMAGE: 'Gambar', LINK: 'Tautan' },
      tutor: {
        materialDetail: {
          title: 'Detail materi',
          notFound: 'Materi tidak ditemukan',
          notFoundHint: 'Materi mungkin sudah dihapus.',
          linkLabel: 'Tautan',
          openLink: 'Buka tautan',
          openFile: 'Buka berkas',
          download: 'Unduh',
          downloadFallback: 'Berkas dibuka di tab baru — simpan dari sana.',
          downloadBlocked:
            'Peramban memblokir tab baru, jadi berkasnya belum terbuka. Izinkan popup untuk situs ini, atau pakai tombol "Buka berkas".',
          noSource: 'Materi ini belum punya berkas maupun tautan.',
          uploadedBy: 'Diunggah oleh',
          createdAt: 'Dibuat',
          shared: 'Terkirim ke wali',
          notShared: 'Belum dikirim',
          draftHint: 'Materi ini belum dikirim — hanya Anda yang bisa melihatnya.',
          sharedHint: 'Wali dan siswa bisa membukanya.',
          sendToGuardian: 'Kirim ke wali',
          withdrawFromGuardian: 'Tarik dari wali',
          sentAt: 'Dikirim',
          sendSuccess: 'Materi dikirim ke wali.',
          withdrawSuccess: 'Materi ditarik dari wali.',
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
        // Fallthrough attrs win over the stub's own, so the badge keeps
        // the view's `data-testid` — assert on that one.
        StatusBadge: { props: ['label'], template: '<span>{{ label }}</span>' },
        AsyncView: {
          props: ['state'],
          template:
            '<div :data-status="state?.status" :data-error="state?.error ?? \'\'">' +
            "<slot v-if=\"state?.status === 'content'\" :data=\"state.data\" /></div>",
        },
      },
    },
  });
  await flushPromises();
  return w;
}

const OPENED: string[] = [];
const FETCHED: string[] = [];
let clickedAnchor: { href: string; download: string } | null = null;

beforeEach(() => {
  vi.clearAllMocks();
  TOASTS.length = 0;
  OPENED.length = 0;
  FETCHED.length = 0;
  clickedAnchor = null;
  routeMock.id = 'mat-7';

  // Faithful: the id decides the answer, and an unknown one 404s the way
  // the scoped `findOrFail` on the server does.
  serviceMock.show.mockImplementation(async (id: string) => {
    const hit = FIXTURES[id];
    if (!hit) throw new Error('Request failed with status code 404');
    return hit;
  });

  vi.spyOn(window, 'open').mockImplementation((url) => {
    OPENED.push(String(url));
    return null;
  });
  // jsdom implements neither of these; a real browser does.
  URL.createObjectURL = vi.fn(() => 'blob:mock-object-url');
  URL.revokeObjectURL = vi.fn();
  vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(function () {
    clickedAnchor = { href: this.href, download: this.download };
  });
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe('TutorTutoring2MaterialDetailView — loading one material', () => {
  it('asks the server for the route id', async () => {
    await mountView();
    expect(serviceMock.show).toHaveBeenCalledTimes(1);
    expect(serviceMock.show).toHaveBeenCalledWith('mat-7');
  });

  it('renders the fields the detail payload carries', async () => {
    const w = await mountView();

    expect(w.get('[data-status]').attributes('data-status')).toBe('content');
    expect(w.get('[data-testid="material-title"]').text()).toBe('Ringkasan Vektor');
    expect(w.get('[data-testid="material-description"]').text()).toContain(
      'Rangkuman bab vektor',
    );
    expect(w.get('[data-testid="material-kind"]').text()).toBe('PDF');
    // Group, programme and uploader only reach the DOM through `show` —
    // the list rows do not always carry them.
    expect(w.text()).toContain('UTBK Pagi A');
    expect(w.text()).toContain('Intensif UTBK');
    expect(w.text()).toContain('Bu Sinta');
    expect(w.get('[data-testid="material-source"]').text()).toContain(
      'ringkasan-vektor.pdf',
    );
  });

  it('shows an unsent material as private to the tutor, with the reason', async () => {
    const w = await mountView();
    // The badge answers "who can open this", which is the tutor's
    // actual question — "Draf" named a lifecycle bucket instead.
    expect(w.get('[data-testid="material-publication"]').text()).toBe('Belum dikirim');
    expect(w.find('[data-testid="material-draft-notice"]').exists()).toBe(true);
    expect(w.get('[data-testid="material-draft-notice"]').text()).toContain('hanya Anda');
  });

  it('renders the ERROR branch for an out-of-scope or deleted id, not a blank screen', async () => {
    routeMock.id = 'mat-not-mine';
    const w = await mountView();

    const host = w.get('[data-status]');
    expect(host.attributes('data-status')).toBe('error');
    expect(host.attributes('data-error')).toContain('404');
    // And nothing pretends to be a material.
    expect(w.find('[data-testid="material-title"]').exists()).toBe(false);
  });
});

describe('TutorTutoring2MaterialDetailView — opening a LINK', () => {
  it('renders an anchor to the target with a safe rel', async () => {
    routeMock.id = 'mat-link-declared';
    const w = await mountView();

    const a = w.get('[data-testid="material-open-link"]');
    expect(a.attributes('href')).toBe(EXTERNAL_URL);
    expect(a.attributes('target')).toBe('_blank');
    expect(a.attributes('rel')).toContain('noopener');
  });

  it('treats a pasted link as a link even when `kind` says PDF', async () => {
    // The web upload form has no LINK chip, so every link it writes is
    // stored under a file kind. The null file_name/file_size/file_mime
    // triple is what actually identifies it.
    routeMock.id = 'mat-link';
    const w = await mountView();

    expect(w.get('[data-testid="material-open-link"]').attributes('href')).toBe(
      EXTERNAL_URL,
    );
    // No "Unduh" on something the centre does not hold.
    expect(w.find('[data-testid="material-download"]').exists()).toBe(false);
    expect(w.get('[data-testid="material-source"]').text()).toContain(EXTERNAL_URL);
  });
});

describe('TutorTutoring2MaterialDetailView — opening and downloading a FILE', () => {
  it('points "Buka berkas" at the URL the server gave', async () => {
    const w = await mountView();

    const a = w.get('[data-testid="material-open-file"]');
    expect(a.attributes('href')).toBe(SIGNED_URL);
    expect(a.attributes('target')).toBe('_blank');
    expect(a.attributes('rel')).toContain('noopener');
    // A link control must not appear for a file.
    expect(w.find('[data-testid="material-open-link"]').exists()).toBe(false);
  });

  it('saves the bytes under the server file name when the fetch is allowed', async () => {
    vi.stubGlobal('fetch', async (url: string) => {
      FETCHED.push(String(url));
      return { ok: true, status: 200, blob: async () => new Blob(['pdf']) };
    });

    const w = await mountView();
    await w.get('[data-testid="material-download"]').trigger('click');
    await flushPromises();

    expect(FETCHED).toEqual([SIGNED_URL]);
    expect(clickedAnchor?.download).toBe('ringkasan-vektor.pdf');
    expect(clickedAnchor?.href).toBe('blob:mock-object-url');
    // A real save must NOT also spawn a tab.
    expect(OPENED).toEqual([]);
  });

  it('falls back to opening the file when the bucket refuses a cross-origin read', async () => {
    // What actually happens today: the storage bucket sets no CORS
    // headers, so `fetch` rejects. The button must still do something.
    vi.stubGlobal('fetch', async (url: string) => {
      FETCHED.push(String(url));
      throw new TypeError('Failed to fetch');
    });

    const w = await mountView();
    await w.get('[data-testid="material-download"]').trigger('click');
    await flushPromises();

    expect(FETCHED).toEqual([SIGNED_URL]);
    expect(OPENED).toEqual([SIGNED_URL]);
    // The default `window.open` stub returns null — a BLOCKED popup — so
    // the honest message here is the blocked one. An earlier version of
    // this test asserted "dibuka di tab baru" against that same null:
    // it asserted a claim the harness was simultaneously proving false.
    // Splitting the two outcomes is the whole point of this pair.
    expect(TOASTS.map((x) => x.msg)).toContain(
      'Peramban memblokir tab baru, jadi berkasnya belum terbuka. Izinkan popup untuk situs ini, atau pakai tombol "Buka berkas".',
    );
  });

  it('says the file opened ONLY when a tab actually opened', async () => {
    vi.stubGlobal('fetch', async (url: string) => {
      FETCHED.push(String(url));
      throw new TypeError('Failed to fetch');
    });
    // A permitted popup: window.open returns a handle rather than null.
    vi.spyOn(window, 'open').mockImplementation((url) => {
      OPENED.push(String(url));
      return {} as Window;
    });

    const w = await mountView();
    await w.get('[data-testid="material-download"]').trigger('click');
    await flushPromises();

    expect(OPENED).toEqual([SIGNED_URL]);
    expect(TOASTS.map((x) => x.msg)).toContain(
      'Berkas dibuka di tab baru — simpan dari sana.',
    );
  });

  it('opens the file rather than failing silently on an expired signature', async () => {
    vi.stubGlobal('fetch', async (url: string) => {
      FETCHED.push(String(url));
      return { ok: false, status: 403, blob: async () => new Blob([]) };
    });

    const w = await mountView();
    await w.get('[data-testid="material-download"]').trigger('click');
    await flushPromises();

    expect(OPENED).toEqual([SIGNED_URL]);
  });
});
