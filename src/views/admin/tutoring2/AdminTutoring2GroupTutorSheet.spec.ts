/**
 * Vitest spec for AdminTutoring2GroupTutorSheet — "Ubah tutor" on the
 * admin group drill-in.
 *
 * Why each block earns its place:
 *
 *   • THE PUT CARRIES `tutor_id`. `updateGroup` is typed
 *     `Partial<BimbelLearningGroup>`, so TypeScript checks nothing
 *     about the field set — what reaches `UpdateLearningGroupRequest`
 *     is a runtime-only contract. This is the assertion that keeps the
 *     key on the body.
 *
 *   • ONE FIELD, NOT A GROUP EDITOR. `sometimes` rules mean an absent
 *     key is an untouched field, so this sheet must send `tutor_id`
 *     and NOTHING else. A stray `name` or `capacity` here would drag a
 *     second column along with every tutor change — `capacity` in
 *     particular has server-side guards that would start 422-ing a
 *     save the admin thinks is about the tutor.
 *
 *   • "TANPA TUTOR" IS `null`, NOT OMISSION AND NOT `''`. Detaching a
 *     tutor is a real instruction and the only spelling that carries
 *     it is an explicit null: omitting the key means "I did not touch
 *     this", which is the opposite. (`''` would be converted to null by
 *     Laravel's default `ConvertEmptyStringsToNull`, but that is the
 *     middleware stack's behaviour, not the form's intent.)
 *
 *   • THE CURRENT TUTOR IS ALWAYS PICKABLE. The option list is ACTIVE
 *     tutors only, so a group whose tutor was since deactivated holds
 *     an id no option matches — and a `<select>` with an unmatched
 *     value renders the placeholder, i.e. the screen would say "Tanpa
 *     tutor" about a group that has one. The prepended row is what
 *     stops the control from lying.
 *
 *   • NOTHING TO SAVE IS NOT SAVEABLE. Save stays disabled until the
 *     choice differs from the row, so opening and closing the sheet
 *     cannot fire a PUT that changes nothing.
 */
// @ts-nocheck — mount stubs are structurally typed, not worth pinning
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2GroupTutorSheet from './AdminTutoring2GroupTutorSheet.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { updateGroup: vi.fn() },
}));

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { list: vi.fn() },
}));

const toasts = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }));
vi.mock('@/composables/useToast', () => ({ useToast: () => toasts }));

const GROUP = {
  id: 'gr-1',
  program_id: 'pr-1',
  program_name: 'Intensif UTBK',
  name: 'UTBK Pagi A',
  kind: 'group',
  capacity: 12,
  status: 'active',
  tutor_id: null,
  tutor_name: null,
};

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
          admin: {
            groupTutor: {
              title: 'Tutor kelompok',
              subtitle: 'Tentukan tutor yang mengajar {group}.',
              label: 'Tutor',
              placeholder: 'Tanpa tutor',
              currentUnnamed: 'Tutor saat ini',
              submit: 'Simpan tutor',
              loading: 'Memuat daftar tutor…',
              none: 'Belum ada tutor aktif di bimbel ini.',
              failed: 'Daftar tutor tidak bisa dimuat.',
              truncated: 'Daftar dibatasi 100 tutor pertama.',
              unassignHint: 'Pilih "Tanpa tutor" untuk melepas tutor.',
              success: 'Tutor kelompok diperbarui.',
              errorGeneric: 'Gagal memperbarui tutor kelompok.',
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
  BottomSheetFooter: {
    props: ['primaryLabel', 'primaryLoading', 'primaryDisabled'],
    template: '<div data-testid="footer"></div>',
  },
};

async function mountSheet(group = GROUP) {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2GroupTutorSheet, {
    props: { group },
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const field = (w) => w.find('[data-testid="field-tutor_id"]');
const optionValues = (w) =>
  field(w)
    .findAll('option')
    .map((o) => o.attributes('value'));

async function submit(w) {
  await w.find('form').trigger('submit');
  await flushPromises();
}

const lastPayload = () => TutoringBimbelService.updateGroup.mock.calls.at(-1);

beforeEach(() => {
  vi.clearAllMocks();
  TutoringTutorsService.list.mockResolvedValue({ items: TUTORS, pagination: undefined });
  TutoringBimbelService.updateGroup.mockResolvedValue({ ...GROUP, tutor_id: 'tu-2' });
});

describe('AdminTutoring2GroupTutorSheet · the PUT', () => {
  it('calls updateGroup with the chosen tutor_id', async () => {
    const w = await mountSheet();

    await field(w).setValue('tu-2');
    await flushPromises();
    await submit(w);

    expect(TutoringBimbelService.updateGroup).toHaveBeenCalledTimes(1);
    expect(lastPayload()[0]).toBe('gr-1');
    expect(lastPayload()[1]).toEqual({ tutor_id: 'tu-2' });
  });

  it('sends tutor_id and NOTHING else — `sometimes` keys left off stay untouched', async () => {
    const w = await mountSheet();

    await field(w).setValue('tu-1');
    await flushPromises();
    await submit(w);

    expect(Object.keys(lastPayload()[1])).toEqual(['tutor_id']);
  });

  it('sends an explicit null when the tutor is detached — not "" and not omission', async () => {
    const w = await mountSheet({ ...GROUP, tutor_id: 'tu-1', tutor_name: 'Rina Kartika' });

    await field(w).setValue('');
    await flushPromises();
    await submit(w);

    const body = lastPayload()[1];
    expect('tutor_id' in body).toBe(true);
    expect(body.tutor_id).toBeNull();
  });

  it('emits saved with the server row, then close, and toasts success', async () => {
    const w = await mountSheet();

    await field(w).setValue('tu-2');
    await flushPromises();
    await submit(w);

    expect(w.emitted('saved')[0][0]).toMatchObject({ id: 'gr-1', tutor_id: 'tu-2' });
    expect(w.emitted('close')).toHaveLength(1);
    expect(toasts.success).toHaveBeenCalledWith('Tutor kelompok diperbarui.');
  });

  it('surfaces the server’s own message on a refused write and stays open', async () => {
    TutoringBimbelService.updateGroup.mockRejectedValue({
      response: { status: 403, data: { message: 'Anda tidak memiliki akses.' } },
    });
    const w = await mountSheet();

    await field(w).setValue('tu-2');
    await flushPromises();
    await submit(w);

    expect(w.find('[data-testid="group-tutor-error"]').text()).toBe(
      'Anda tidak memiliki akses.',
    );
    expect(w.emitted('close')).toBeUndefined();
  });
});

describe('AdminTutoring2GroupTutorSheet · option list', () => {
  it('reads the ACTIVE tutors off TutoringTutorsService', async () => {
    await mountSheet();

    expect(TutoringTutorsService.list).toHaveBeenCalledWith(
      expect.objectContaining({ active: true }),
    );
  });

  it('opens on the group’s current tutor, not on the placeholder', async () => {
    const w = await mountSheet({ ...GROUP, tutor_id: 'tu-1', tutor_name: 'Rina Kartika' });

    expect(field(w).element.value).toBe('tu-1');
  });

  it('keeps a DEACTIVATED current tutor pickable, so the field cannot lie', async () => {
    const w = await mountSheet({
      ...GROUP,
      tutor_id: 'tu-gone',
      tutor_name: 'Sari Lestari',
    });

    // Prepended ahead of the active rows, and still the selected value.
    expect(optionValues(w)).toEqual(['', 'tu-gone', 'tu-1', 'tu-2']);
    expect(field(w).element.value).toBe('tu-gone');
    expect(field(w).text()).toContain('Sari Lestari');
  });

  it('says so when the tenant has no active tutors', async () => {
    TutoringTutorsService.list.mockResolvedValue({ items: [], pagination: undefined });
    const w = await mountSheet();

    expect(w.find('[data-testid="group-tutor-list-empty"]').exists()).toBe(true);
  });

  it('says so when the tutor list was refused', async () => {
    TutoringTutorsService.list.mockRejectedValue(new Error('403'));
    const w = await mountSheet();

    expect(w.find('[data-testid="group-tutor-list-failed"]').exists()).toBe(true);
  });
});

describe('AdminTutoring2GroupTutorSheet · nothing to save', () => {
  it('does not PUT when the choice still matches the row', async () => {
    const w = await mountSheet({ ...GROUP, tutor_id: 'tu-1', tutor_name: 'Rina Kartika' });

    await submit(w);

    expect(TutoringBimbelService.updateGroup).not.toHaveBeenCalled();
  });

  it('treats a null tutor_id and an untouched placeholder as equal', async () => {
    const w = await mountSheet();

    await submit(w);

    expect(TutoringBimbelService.updateGroup).not.toHaveBeenCalled();
  });
});
