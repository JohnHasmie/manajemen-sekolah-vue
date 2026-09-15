/**
 * Vitest spec for AdminTutoring2GroupCreateSheet — the ONE create
 * surface for a learning group.
 *
 * Why each block earns its place:
 *
 *   • TUTOR IS ON THE WIRE NOW. `StoreLearningGroupRequest` has always
 *     carried `tutor_id => ['nullable','uuid']`, and
 *     `CreateLearningGroupAction` has always written it. The FORM never
 *     asked, so every group was born tutorless and the Tutor column on
 *     AdminTutoring2GroupsView read "—" for rows that had a tutor in
 *     everything but the database. These assertions are what keep the
 *     key on the payload.
 *
 *   • ABSENT ≠ EMPTY. `createGroup` is typed `Partial<BimbelLearningGroup>`,
 *     so TypeScript checks nothing about the field set — what is sent is
 *     a runtime-only contract. A blank picker must leave the key OFF the
 *     body entirely. `toMatchObject` cannot see the difference between
 *     "not sent" and "sent as ''", so these tests assert on
 *     `'tutor_id' in payload` directly.
 *
 *     (For the record, and contrary to the sibling `package_id` note in
 *     AdminTutoring2GroupAddStudentSheet.spec.ts: Laravel 12 keeps
 *     `ConvertEmptyStringsToNull` in its default global middleware
 *     stack, which this app does not override, so a `''` would arrive as
 *     `null` and PASS `nullable|uuid` rather than 422. Omitting the key
 *     is still the only spelling that cannot be misread — on UPDATE the
 *     same `''` means "unassign this group's tutor", which is a real and
 *     very different instruction.)
 *
 *   • THE GATE IS `tutoring.group.manage`. That is the key
 *     `LearningGroupController::store` authorizes — not
 *     `tutoring.tutor.view`, which only lets the picker's option list be
 *     read. An admin without it sees no tutor field at all rather than
 *     one whose only possible outcome is a 403.
 *
 *   • THE OPTION LIST IS FETCHED, NOT INVENTED. It comes from
 *     `TutoringTutorsService.list`, the same source the Tutor filter
 *     chip on AdminTutoring2GroupsView uses, restricted to ACTIVE
 *     tutors — a deactivated tutor is not someone to hand a new group.
 */
// @ts-nocheck — mount stubs are structurally typed, not worth pinning
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2GroupCreateSheet from './AdminTutoring2GroupCreateSheet.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { createGroup: vi.fn() },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

const toasts = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }));
vi.mock('@/composables/useToast', () => ({ useToast: () => toasts }));

/**
 * Ability the tutor field is gated on. Mutable so the without-the-grant
 * case can flip it per test — the same shape
 * AdminTutoring2GroupDetailView.add-student.spec.ts uses.
 */
let grantedAbilities: string[] = ['tutoring.group.manage'];

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({
    can: (ability: string) => grantedAbilities.includes(ability),
    canAny: (abilities: Iterable<string>) =>
      [...abilities].some((a) => grantedAbilities.includes(a)),
  }),
}));

const PROGRAMS = [
  { id: 'pr-1', name: 'Intensif UTBK', grade_level: '12', status: 'active' },
  { id: 'pr-2', name: 'Matematika Dasar', grade_level: '10', status: 'active' },
];

const TUTORS = [
  { id: 'tu-1', user_id: 'us-1', name: 'Rina Kartika', is_active: true, active_group_count: 1 },
  { id: 'tu-2', user_id: 'us-2', name: 'Bayu Pratama', is_active: true, active_group_count: 0 },
];

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    missingWarn: false,
    fallbackWarn: false,
    messages: {
      id: {
        tutoring2: {
          common: { program: 'Program', tutor: 'Tutor' },
          admin: {
            groupCreate: {
              title: 'Kelompok baru',
              subtitle: 'Buat kelompok belajar untuk sebuah program.',
              programPh: 'Pilih program…',
              noPrograms: 'Belum ada program.',
              nameLabel: 'Nama kelompok',
              namePh: 'Contoh: UTBK Pagi A',
              capacityLabel: 'Kapasitas',
              capacityPh: 'Jumlah kursi',
              tutorLabel: 'Tutor (opsional)',
              tutorPh: 'Belum ditentukan',
              tutorsLoading: 'Memuat tutor…',
              tutorsNone: 'Belum ada tutor aktif.',
              tutorsFailed: 'Daftar tutor tidak bisa dimuat.',
              tutorsTruncated: 'Daftar dibatasi 100 tutor pertama.',
              submit: 'Buat kelompok',
              errName: 'Nama kelompok minimal 3 karakter.',
              errProgram: 'Pilih program terlebih dahulu.',
              success: 'Kelompok dibuat.',
              errorGeneric: 'Gagal membuat kelompok.',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  // Only the teleporting shell — FormField and FormSheet stay real.
  Modal: { template: '<div data-testid="sheet"><slot /></div>' },
  BottomSheetFooter: true,
};

async function mountSheet(props = {}, held = ['tutoring.group.manage']) {
  grantedAbilities = held;
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2GroupCreateSheet, {
    props: { programs: PROGRAMS, ...props },
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const sel = (w, name) => w.find(`[data-testid="field-${name}"]`);

async function submit(w) {
  await w.find('form').trigger('submit');
  await flushPromises();
}

const lastPayload = () => TutoringBimbelService.createGroup.mock.calls.at(-1)[0];

/** Fill the two fields the sheet refuses to submit without. */
async function fillRequired(w, programId = 'pr-1') {
  await sel(w, 'program_id').setValue(programId);
  await sel(w, 'name').setValue('UTBK Pagi A');
  await flushPromises();
}

beforeEach(() => {
  vi.clearAllMocks();
  TutoringTutorsService.list.mockResolvedValue({ items: TUTORS, pagination: undefined });
  TutoringBimbelService.createGroup.mockResolvedValue({
    id: 'gr-new',
    program_id: 'pr-1',
    name: 'UTBK Pagi A',
    kind: 'group',
    capacity: 10,
    status: 'draft',
  });
});

describe('AdminTutoring2GroupCreateSheet · tutor_id on the payload', () => {
  it('sends tutor_id when a tutor is picked', async () => {
    const w = await mountSheet();

    await fillRequired(w);
    await sel(w, 'tutor_id').setValue('tu-2');
    await flushPromises();
    await submit(w);

    expect(TutoringBimbelService.createGroup).toHaveBeenCalledTimes(1);
    expect(lastPayload()).toMatchObject({
      program_id: 'pr-1',
      name: 'UTBK Pagi A',
      tutor_id: 'tu-2',
    });
  });

  it('OMITS tutor_id entirely when no tutor is picked', async () => {
    const w = await mountSheet();

    await fillRequired(w);
    await submit(w);

    const payload = lastPayload();
    // `in`, not a value check: "chose not to send" and "sent empty"
    // are indistinguishable through toMatchObject.
    expect('tutor_id' in payload).toBe(false);
  });

  it('OMITS tutor_id again when a picked tutor is cleared back to blank', async () => {
    const w = await mountSheet();

    await fillRequired(w);
    await sel(w, 'tutor_id').setValue('tu-1');
    await flushPromises();
    await sel(w, 'tutor_id').setValue('');
    await flushPromises();
    await submit(w);

    expect('tutor_id' in lastPayload()).toBe(false);
  });

  it('still creates the group — a tutorless group is legitimate', async () => {
    const w = await mountSheet();

    await fillRequired(w);
    await submit(w);

    expect(TutoringBimbelService.createGroup).toHaveBeenCalledTimes(1);
    expect(w.emitted('saved')).toHaveLength(1);
    expect(toasts.success).toHaveBeenCalledWith('Kelompok dibuat.');
  });
});

describe('AdminTutoring2GroupCreateSheet · tutor option list', () => {
  it('reads the ACTIVE tutors off TutoringTutorsService', async () => {
    await mountSheet();

    expect(TutoringTutorsService.list).toHaveBeenCalledWith(
      expect.objectContaining({ active: true }),
    );
  });

  it('renders one option per tutor, plus the "no tutor" placeholder', async () => {
    const w = await mountSheet();

    const options = sel(w, 'tutor_id')
      .findAll('option')
      .map((o) => o.attributes('value'));

    expect(options).toEqual(['', 'tu-1', 'tu-2']);
  });

  it('says so when the tenant has no active tutors, instead of an empty dropdown', async () => {
    TutoringTutorsService.list.mockResolvedValue({ items: [], pagination: undefined });
    const w = await mountSheet();

    expect(w.find('[data-testid="tutors-none"]').exists()).toBe(true);
  });

  it('survives a refused tutor list — the group can still be created without one', async () => {
    TutoringTutorsService.list.mockRejectedValue(new Error('403'));
    const w = await mountSheet();

    expect(w.find('[data-testid="tutors-failed"]').exists()).toBe(true);

    await fillRequired(w);
    await submit(w);

    expect(TutoringBimbelService.createGroup).toHaveBeenCalledTimes(1);
    expect('tutor_id' in lastPayload()).toBe(false);
  });
});

describe('AdminTutoring2GroupCreateSheet · ability gate', () => {
  it('shows the tutor field for an admin holding tutoring.group.manage', async () => {
    const w = await mountSheet();
    expect(sel(w, 'tutor_id').exists()).toBe(true);
  });

  it('hides the tutor field — and does not fetch tutors — without it', async () => {
    const w = await mountSheet({}, ['tutoring.group.view']);

    expect(sel(w, 'tutor_id').exists()).toBe(false);
    expect(TutoringTutorsService.list).not.toHaveBeenCalled();
  });
});
