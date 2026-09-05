/**
 * Vitest contract spec for AdminTutoring2ProgramsView's
 * "+ Program baru" CTA.
 *
 * ── History this file pins ───────────────────────────────────────────
 *
 * The CTA first shipped with NO `@click` and no handler — a fully styled
 * button carrying a real i18n label that could not do anything. Prod
 * reported it as "tombol diklik tidak terjadi apa-apa". It was then made
 * `disabled` with a stated reason, because web-vue genuinely had no
 * program create surface: `TutoringBimbelService.createProgram` wrapped
 * the live `POST /tutoring-v2/programs` with zero call sites.
 *
 * That surface now exists (<AdminTutoring2ProgramCreateSheet>), so this
 * file no longer asserts the honest-placeholder behaviour — it asserts
 * the working one. Every test below fails against BOTH earlier shapes:
 * a disabled button opens nothing, and an unbound one opens nothing
 * either.
 *
 * The sheet mounted here is the REAL one; only the teleporting <Modal>
 * shell is stubbed. So the fields filled below are the fields an admin
 * fills, and the payload asserted is the payload the browser would POST.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2ProgramsView from './AdminTutoring2ProgramsView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listPrograms: vi.fn(),
    createProgram: vi.fn(),
  },
}));

/**
 * Ability the CTA is gated on, read off the /me snapshot via `useMe`.
 * Mutable so the "no grant" case can flip it per test.
 *
 * `roles[].permission_keys` is deliberately NOT modelled here: it is
 * unscoped and exists only for the role switcher, so a view that gated
 * on it would pass a test built on it and still be wrong on prod.
 */
let grantedAbilities: string[] = ['tutoring.program.manage'];

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (ability: string) => grantedAbilities.includes(ability),
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

const toastSuccess = vi.fn();
const toastError = vi.fn();
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: toastSuccess, error: toastError, info: vi.fn() }),
}));

vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: (_fn: () => void) => {
    /* noop in tests */
  },
}));

const PROGRAMS = [
  {
    id: 'pr-1',
    name: 'Intensif UTBK',
    grade_level: 'SMA',
    status: 'active',
    packages_count: 3,
    min_price: 500000,
  },
];

const COPY = {
  newCta: 'Program baru',
  title: 'Program baru',
  submit: 'Buat program',
  errName: 'Nama program minimal 3 karakter.',
  errDuplicate: 'Nama program itu sudah dipakai di bimbel ini. Pakai nama lain.',
  errorGeneric: 'Gagal membuat program.',
};

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    messages: {
      id: {
        tutoring2: {
          common: { all: 'Semua', status: 'Status', gradeLevel: 'Jenjang' },
          status: { draft: 'Draft', active: 'Aktif' },
          admin: {
            programs: { newCta: COPY.newCta },
            programCreate: {
              title: COPY.title,
              subtitle: 'Buat program bimbel yang bisa dijual ke siswa.',
              nameLabel: 'Nama program',
              namePh: 'Contoh: Intensif UTBK Saintek',
              gradeLevelPh: 'Contoh: SD, SMP, SMA, Umum',
              statusLabel: 'Status awal',
              statusHint: 'Draft belum bisa dijual; Aktif langsung bisa dipakai pendaftaran.',
              descriptionLabel: 'Deskripsi',
              descriptionPh: 'Ringkasan singkat isi program (opsional).',
              submit: COPY.submit,
              errName: COPY.errName,
              errNameTooLong: 'Nama program maksimal 120 karakter.',
              errGradeLevelTooLong: 'Jenjang maksimal 16 karakter.',
              errDescriptionTooLong: 'Deskripsi maksimal 2000 karakter.',
              errDuplicate: COPY.errDuplicate,
              success: 'Program dibuat.',
              errorGeneric: COPY.errorGeneric,
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
  const w = mount(AdminTutoring2ProgramsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        BrandPageHeader: true,
        KpiStripCards: true,
        StatusBadge: true,
        PageFilterToolbar: true,
        AppFilterChip: true,
        AsyncView: {
          props: ['state'],
          template: '<div><slot :data="state?.data ?? []" /></div>',
        },
        // Modal teleports to body, which would escape the wrapper. The
        // stub forwards `testid` so FormSheet's own id survives, and
        // renders `title` the way the real Modal does so the sheet's
        // heading is assertable.
        Modal: {
          props: ['title', 'subtitle', 'size', 'testid'],
          template:
            '<div :data-testid="testid || \'modal\'"><h2>{{ title }}</h2><slot /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

const ctaOf = (w) => w.find('[data-testid="programs-new-cta"]');
const sheetOf = (w) => w.find('[data-testid="form-sheet"]');

/** Fill the sheet the way an admin would, by field name. */
async function fill(w, values: Record<string, string>) {
  for (const [field, value] of Object.entries(values)) {
    await sheetOf(w).find(`[data-testid="field-${field}"]`).setValue(value);
  }
}

async function submitSheet(w) {
  await sheetOf(w).find('[data-testid="sheet-submit"]').trigger('click');
  await flushPromises();
}

describe('AdminTutoring2ProgramsView "+ Program baru" CTA', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    grantedAbilities = ['tutoring.program.manage'];
    (TutoringBimbelService.listPrograms as any).mockResolvedValue({
      items: PROGRAMS,
      pagination: undefined,
    });
    (TutoringBimbelService.createProgram as any).mockResolvedValue({
      id: 'pr-new',
      name: 'Intensif UTBK Saintek',
      grade_level: 'SMA',
      status: 'active',
    });
  });

  it('renders the CTA, enabled, for an admin who may manage programs', async () => {
    const w = await mountView();
    const cta = ctaOf(w);

    expect(cta.exists()).toBe(true);
    expect(cta.text()).toContain(COPY.newCta);
    // The placeholder era: it rendered `disabled` with a stated reason.
    expect(cta.attributes('disabled')).toBeUndefined();
  });

  it('clicking the CTA OPENS a create surface', async () => {
    const w = await mountView();
    // Nothing is open before the click — neither of the earlier shapes
    // (no handler, then disabled) could get past this line.
    expect(sheetOf(w).exists()).toBe(false);

    await ctaOf(w).trigger('click');

    expect(sheetOf(w).exists()).toBe(true);
    expect(sheetOf(w).text()).toContain(COPY.title);
  });

  it('submitting POSTs the program and refreshes the list', async () => {
    const w = await mountView();
    await ctaOf(w).trigger('click');

    await fill(w, {
      name: 'Intensif UTBK Saintek',
      grade_level: 'SMA',
      status: 'active',
    });

    const listCallsBefore = (TutoringBimbelService.listPrograms as any).mock.calls.length;
    await submitSheet(w);

    expect(TutoringBimbelService.createProgram).toHaveBeenCalledTimes(1);
    // Exactly the four fields StoreProgramRequest accepts — empty
    // optionals go out as null, matching its `nullable` rules.
    expect((TutoringBimbelService.createProgram as any).mock.calls[0][0]).toEqual({
      name: 'Intensif UTBK Saintek',
      grade_level: 'SMA',
      description: null,
      status: 'active',
    });
    // Sheet closes and the list re-queries so the new row appears.
    expect(sheetOf(w).exists()).toBe(false);
    expect((TutoringBimbelService.listPrograms as any).mock.calls.length).toBeGreaterThan(
      listCallsBefore,
    );
  });

  it('defaults the new program to Draft, the server default', async () => {
    const w = await mountView();
    await ctaOf(w).trigger('click');
    await fill(w, { name: 'Reguler SMP' });
    await submitSheet(w);

    expect((TutoringBimbelService.createProgram as any).mock.calls[0][0]).toMatchObject({
      status: 'draft',
      grade_level: null,
    });
  });

  it('refuses a too-short name, and says why, without POSTing', async () => {
    const w = await mountView();
    await ctaOf(w).trigger('click');
    await fill(w, { name: 'AB' });
    await submitSheet(w);

    expect(TutoringBimbelService.createProgram).not.toHaveBeenCalled();
    // A refusal the admin can READ — not a silent no-op.
    expect(sheetOf(w).exists()).toBe(true);
    expect(sheetOf(w).text()).toContain(COPY.errName);
  });

  it('shows a failed POST inside the form and keeps it open', async () => {
    (TutoringBimbelService.createProgram as any).mockRejectedValue({
      response: { status: 500, data: { message: 'Server Error' } },
    });

    const w = await mountView();
    await ctaOf(w).trigger('click');
    await fill(w, { name: 'Intensif UTBK Saintek' });
    await submitSheet(w);

    // Not swallowed, and not thrown away with the form either.
    expect(sheetOf(w).exists()).toBe(true);
    expect(sheetOf(w).find('[data-testid="program-create-error"]').text()).toBe(
      'Server Error',
    );
    // What the admin typed survives the failure.
    expect(
      sheetOf(w).find('[data-testid="field-name"]').element.value,
    ).toBe('Intensif UTBK Saintek');
  });

  it('maps a 422 onto the field that failed', async () => {
    (TutoringBimbelService.createProgram as any).mockRejectedValue({
      response: {
        status: 422,
        data: {
          message: 'Data tidak valid.',
          errors: { name: ['Nama program sudah dipakai.'] },
        },
      },
    });

    const w = await mountView();
    await ctaOf(w).trigger('click');
    await fill(w, { name: 'Intensif UTBK' });
    await submitSheet(w);

    expect(sheetOf(w).exists()).toBe(true);
    expect(sheetOf(w).text()).toContain('Nama program sudah dipakai.');
  });

  it('translates the duplicate-name 23505 into words an admin can act on', async () => {
    // `bimbel_programs` has a partial unique index on
    // (school_id, LOWER(name)) but StoreProgramRequest has no `unique`
    // rule, so a duplicate arrives as a 500 carrying SQL, not a 422.
    (TutoringBimbelService.createProgram as any).mockRejectedValue({
      response: {
        status: 500,
        data: {
          message:
            'SQLSTATE[23505]: Unique violation: duplicate key value violates unique constraint "bimbel_programs_school_name_uniq"',
        },
      },
    });

    const w = await mountView();
    await ctaOf(w).trigger('click');
    await fill(w, { name: 'Intensif UTBK' });
    await submitSheet(w);

    expect(sheetOf(w).text()).toContain(COPY.errDuplicate);
    expect(sheetOf(w).text()).not.toContain('SQLSTATE');
  });

  it('hides the CTA entirely when the admin lacks tutoring.program.manage', async () => {
    grantedAbilities = [];

    const w = await mountView();

    // Hidden, not inert: an admin never sees a button that would refuse.
    expect(ctaOf(w).exists()).toBe(false);
    expect(sheetOf(w).exists()).toBe(false);
    expect(TutoringBimbelService.createProgram).not.toHaveBeenCalled();
  });
});
