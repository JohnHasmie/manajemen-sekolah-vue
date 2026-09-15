/**
 * Vitest spec for AdminTutoring2VoucherRecipientsSheet — the admin panel
 * that aims a promo code at named students.
 *
 * Why each block earns its place:
 *
 *   • THE ATTACH PAYLOAD. `AttachVoucherRecipientsRequest` validates
 *     `student_ids => required|array|min:1|max:500` with each entry a
 *     distinct uuid. Nothing in TypeScript checks that the ids reaching
 *     the service are the STUDENT ids the admin picked, so these
 *     assertions are the only thing holding the wire together.
 *
 *   • MIN:1 IS ENFORCED LOCALLY. An empty array is a 422, not a way to
 *     clear the list — detaching is its own verb. The sheet must refuse
 *     to submit rather than send one and read the rejection back.
 *
 *   • DETACH SENDS student_id, NOT THE ROW ID. The route is
 *     `…/recipients/{studentId}` and the action deletes by `student_id`.
 *     Sending `recipient.id` would delete nothing and report a cheerful
 *     `detached_count: 0`, i.e. a control that silently does nothing.
 *
 *   • THE READ AND THE WRITES DO NOT SHARE A KEY. `recipients` gates on
 *     `tutoring.voucher.view`, attach/detach on
 *     `tutoring.voucher.manage`. The gate test must therefore show the
 *     LIST surviving while the controls disappear — a test that only
 *     proves "nothing renders without manage" would be satisfied by a
 *     panel that hides the list too, which is the regression.
 *
 *   • GENERAL VS PERSONAL. Zero recipients is a general promo anyone
 *     with the code can spend; one or more makes it personal. An admin
 *     who cannot tell them apart hands out the wrong code.
 *
 *   • THE TWO WARNINGS ARE NOT SYMMETRIC. Attaching the first recipient
 *     NARROWS a circulating code; detaching the last WIDENS it back to
 *     general. The second is the one a reader would not expect from the
 *     button label, so it must be on screen before the click.
 */
// @ts-nocheck — mount stubs are structurally typed, not worth pinning
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2VoucherRecipientsSheet from './AdminTutoring2VoucherRecipientsSheet.vue';
import BottomSheetFooter from '@/components/ui/BottomSheetFooter.vue';
import { VouchersService } from '@/services/tutoring2/vouchers';
import { TutoringStudentsService } from '@/services/tutoring2/students';

vi.mock('@/services/tutoring2/vouchers', () => ({
  VouchersService: {
    listRecipients: vi.fn(),
    attachRecipients: vi.fn(),
    detachRecipient: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { list: vi.fn() },
}));

const toasts = vi.hoisted(() => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }));
vi.mock('@/composables/useToast', () => ({ useToast: () => toasts }));

const VOUCHER_ID = 'v-1';
const STUDENT_A = 'st-a';
const STUDENT_B = 'st-b';

const VOUCHER = {
  id: VOUCHER_ID,
  school_id: 'sc-1',
  code: 'HEMAT10',
  kind: 'percent',
  value: 10,
  status: 'active',
  recipient_count: 0,
  is_targeted: false,
};

const STUDENTS = [
  { id: STUDENT_A, school_id: 'sc-1', name: 'Andi Wijaya', student_number: '2401' },
  { id: STUDENT_B, school_id: 'sc-1', name: 'Budi Santoso', student_number: '2402' },
  { id: 'st-c', school_id: 'sc-1', name: 'Citra Dewi', student_number: '2403' },
];

function recipient(studentId, overrides = {}) {
  return {
    id: `vr-${studentId}`,
    voucher_id: VOUCHER_ID,
    student_id: studentId,
    student_name: studentId === STUDENT_A ? 'Andi Wijaya' : 'Budi Santoso',
    student_number: studentId === STUDENT_A ? '2401' : '2402',
    ...overrides,
  };
}

/** The refreshed voucher both writes hand back. */
function mutation(count, changed) {
  return {
    voucher: { ...VOUCHER, recipient_count: count, is_targeted: count > 0 },
    changedCount: changed,
  };
}

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
          common: {
            student: 'Siswa',
            loading: 'Memuat…',
            retry: 'Coba lagi',
            delete: 'Hapus',
            cancel: 'Batal',
            back: 'Kembali',
          },
          admin: {
            voucherRecipients: {
              title: 'Penerima voucher',
              subtitle: 'Kode {code}',
              natureGeneral: 'Promo umum — siapa pun yang punya kodenya bisa memakainya.',
              naturePersonal:
                'Voucher personal — hanya {count} siswa di bawah ini yang bisa memakainya.',
              empty: 'Belum ada penerima. Voucher ini masih promo umum.',
              loadError: 'Gagal memuat penerima voucher. Coba lagi.',
              removeLastWarning: 'Ini penerima terakhir.',
              addTitle: 'Tambah penerima',
              searchLabel: 'Cari siswa',
              searchPh: 'Nama…',
              studentPh: 'Pilih siswa',
              studentsNone: 'Tidak ada siswa yang bisa ditambahkan.',
              studentsError: 'Gagal memuat daftar siswa.',
              studentsTruncated: 'Baru {count} siswa pertama yang ditampilkan.',
              firstRecipientWarning: 'Voucher ini masih promo umum.',
              attachSubmit: 'Simpan penerima',
              attachSuccess: '{count} penerima ditambahkan.',
              attachNoop: 'Siswa tersebut sudah terdaftar sebagai penerima.',
              attachFailed: 'Gagal menambahkan penerima. Coba lagi.',
              detachSuccess: 'Penerima dihapus dari voucher.',
              detachNoop: 'Siswa tersebut bukan penerima voucher ini.',
              detachFailed: 'Gagal menghapus penerima. Coba lagi.',
              readOnlyNote: 'Anda hanya bisa melihat daftar ini.',
              snapshotAbsent: 'Baris di tabel belum membawa jumlah penerima.',
              unnamed: 'Tanpa nama',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  // Only the teleporting shell. FormField and BottomSheetFooter stay
  // real — the submit button's disabled state is part of the contract.
  Modal: { template: '<div data-testid="sheet"><slot /></div>' },
};

async function mountSheet(props = {}) {
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2VoucherRecipientsSheet, {
    props: { voucher: VOUCHER, canManage: true, ...props },
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const field = (w, name) => w.find(`[data-testid="field-${name}"]`);
const footer = (w) => w.findComponent(BottomSheetFooter);

async function stage(w, studentId) {
  await field(w, 'recipient_student_id').setValue(studentId);
  await flushPromises();
}

async function submit(w) {
  footer(w).vm.$emit('primary');
  await flushPromises();
}

beforeEach(() => {
  vi.clearAllMocks();
  VouchersService.listRecipients.mockResolvedValue([]);
  VouchersService.attachRecipients.mockResolvedValue(mutation(1, 1));
  VouchersService.detachRecipient.mockResolvedValue(mutation(0, 1));
  TutoringStudentsService.list.mockResolvedValue({
    items: STUDENTS,
    pagination: undefined,
  });
});

// ─── Reading the list ────────────────────────────────────────────────

describe('AdminTutoring2VoucherRecipientsSheet · listing', () => {
  it('asks the recipients endpoint for THAT voucher id on mount', async () => {
    await mountSheet();

    expect(VouchersService.listRecipients).toHaveBeenCalledTimes(1);
    expect(VouchersService.listRecipients).toHaveBeenCalledWith(VOUCHER_ID);
  });

  it('renders one row per recipient, with the denormalised student label', async () => {
    VouchersService.listRecipients.mockResolvedValue([
      recipient(STUDENT_A),
      recipient(STUDENT_B),
    ]);

    const w = await mountSheet();
    const rows = w.findAll('[data-testid="recipient-row"]');

    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('Andi Wijaya');
    expect(rows[0].text()).toContain('2401');
  });

  it('a failed read says so and offers a retry, rather than reading as "general promo"', async () => {
    VouchersService.listRecipients.mockRejectedValueOnce(new Error('boom'));

    const w = await mountSheet();

    expect(w.find('[data-testid="recipients-error"]').exists()).toBe(true);
    // The crucial half: a load failure must NOT render the
    // zero-recipients state, which would say the voucher is a general
    // promo anyone may spend.
    expect(w.find('[data-testid="recipients-nature"]').exists()).toBe(false);
    expect(w.find('[data-testid="recipients-empty"]').exists()).toBe(false);
  });
});

// ─── General vs personal ─────────────────────────────────────────────

describe('AdminTutoring2VoucherRecipientsSheet · general vs personal', () => {
  it('ZERO recipients reads as a general promo', async () => {
    VouchersService.listRecipients.mockResolvedValue([]);

    const w = await mountSheet();

    expect(w.find('[data-testid="recipients-nature"]').text()).toContain(
      'Promo umum',
    );
    expect(w.find('[data-testid="recipients-empty"]').exists()).toBe(true);
    expect(w.find('[data-testid="recipients-list"]').exists()).toBe(false);
  });

  it('NON-ZERO recipients reads as personal, and names the count', async () => {
    VouchersService.listRecipients.mockResolvedValue([
      recipient(STUDENT_A),
      recipient(STUDENT_B),
    ]);

    const w = await mountSheet();

    const nature = w.find('[data-testid="recipients-nature"]').text();
    expect(nature).toContain('Voucher personal');
    expect(nature).toContain('2');
    expect(nature).not.toContain('Promo umum');
  });

  it('warns BEFORE the first attach that the code is about to narrow', async () => {
    const w = await mountSheet();
    expect(w.find('[data-testid="recipients-first-warning"]').exists()).toBe(false);

    await stage(w, STUDENT_A);

    expect(w.find('[data-testid="recipients-first-warning"]').exists()).toBe(true);
  });

  it('warns while ONE recipient is left that removing it widens the voucher', async () => {
    VouchersService.listRecipients.mockResolvedValue([recipient(STUDENT_A)]);

    const w = await mountSheet();

    expect(w.find('[data-testid="recipients-last-warning"]').exists()).toBe(true);
  });

  it('does not warn about widening while two recipients remain', async () => {
    VouchersService.listRecipients.mockResolvedValue([
      recipient(STUDENT_A),
      recipient(STUDENT_B),
    ]);

    const w = await mountSheet();

    expect(w.find('[data-testid="recipients-last-warning"]').exists()).toBe(false);
  });
});

// ─── Attaching ───────────────────────────────────────────────────────

describe('AdminTutoring2VoucherRecipientsSheet · attach', () => {
  it('THE PAYLOAD: sends the picked STUDENT ids for that voucher', async () => {
    const w = await mountSheet();

    await stage(w, STUDENT_B);
    await submit(w);

    expect(VouchersService.attachRecipients).toHaveBeenCalledTimes(1);
    expect(VouchersService.attachRecipients).toHaveBeenCalledWith(VOUCHER_ID, [
      STUDENT_B,
    ]);
  });

  it('batches several picks into ONE call — the endpoint takes an array', async () => {
    const w = await mountSheet();

    await stage(w, STUDENT_A);
    await stage(w, STUDENT_B);
    await submit(w);

    expect(VouchersService.attachRecipients).toHaveBeenCalledTimes(1);
    expect(VouchersService.attachRecipients.mock.calls[0][1]).toEqual([
      STUDENT_A,
      STUDENT_B,
    ]);
  });

  it('MIN:1 — refuses to submit an empty selection instead of posting a 422', async () => {
    const w = await mountSheet();

    expect(footer(w).props('primaryDisabled')).toBe(true);
    await submit(w);

    expect(VouchersService.attachRecipients).not.toHaveBeenCalled();
  });

  it('re-reads the recipient list afterwards, so the panel cannot show stale', async () => {
    const w = await mountSheet();
    expect(VouchersService.listRecipients).toHaveBeenCalledTimes(1);

    await stage(w, STUDENT_A);
    await submit(w);

    expect(VouchersService.listRecipients).toHaveBeenCalledTimes(2);
  });

  it('emits the refreshed voucher so the list behind the sheet can refresh too', async () => {
    const w = await mountSheet();

    await stage(w, STUDENT_A);
    await submit(w);

    const emitted = w.emitted('changed');
    expect(emitted).toHaveLength(1);
    expect(emitted[0][0].recipient_count).toBe(1);
    expect(emitted[0][0].is_targeted).toBe(true);
  });

  it('a 0-changed answer is reported as already-done, not as a failure', async () => {
    VouchersService.attachRecipients.mockResolvedValue(mutation(1, 0));

    const w = await mountSheet();
    await stage(w, STUDENT_A);
    await submit(w);

    expect(toasts.error).not.toHaveBeenCalled();
    expect(toasts.success).toHaveBeenCalledWith(
      'Siswa tersebut sudah terdaftar sebagai penerima.',
    );
  });

  it('carries the server sentence through on a rejection', async () => {
    VouchersService.attachRecipients.mockRejectedValueOnce({
      response: {
        status: 422,
        data: { message: 'Sebagian siswa tidak ditemukan di lembaga ini.' },
      },
    });

    const w = await mountSheet();
    await stage(w, STUDENT_A);
    await submit(w);

    expect(toasts.error).toHaveBeenCalledWith(
      'Sebagian siswa tidak ditemukan di lembaga ini.',
    );
  });
});

// ─── Detaching ───────────────────────────────────────────────────────

describe('AdminTutoring2VoucherRecipientsSheet · detach', () => {
  it('THE ID: sends the STUDENT id, not the recipient row id', async () => {
    VouchersService.listRecipients.mockResolvedValue([recipient(STUDENT_A)]);

    const w = await mountSheet();
    await w.find('[data-testid="recipient-remove"]').trigger('click');
    await flushPromises();

    expect(VouchersService.detachRecipient).toHaveBeenCalledTimes(1);
    expect(VouchersService.detachRecipient).toHaveBeenCalledWith(
      VOUCHER_ID,
      STUDENT_A,
    );
    // The row id would look just as plausible on the wire and delete
    // nothing.
    expect(VouchersService.detachRecipient).not.toHaveBeenCalledWith(
      VOUCHER_ID,
      `vr-${STUDENT_A}`,
    );
  });

  it('removes the row the admin clicked, not the first one', async () => {
    VouchersService.listRecipients.mockResolvedValue([
      recipient(STUDENT_A),
      recipient(STUDENT_B),
    ]);

    const w = await mountSheet();
    await w.findAll('[data-testid="recipient-remove"]')[1].trigger('click');
    await flushPromises();

    expect(VouchersService.detachRecipient).toHaveBeenCalledWith(
      VOUCHER_ID,
      STUDENT_B,
    );
  });

  it('re-reads the list and emits the refreshed voucher', async () => {
    VouchersService.listRecipients.mockResolvedValue([recipient(STUDENT_A)]);

    const w = await mountSheet();
    expect(VouchersService.listRecipients).toHaveBeenCalledTimes(1);

    await w.find('[data-testid="recipient-remove"]').trigger('click');
    await flushPromises();

    expect(VouchersService.listRecipients).toHaveBeenCalledTimes(2);
    expect(w.emitted('changed')).toHaveLength(1);
    expect(w.emitted('changed')[0][0].is_targeted).toBe(false);
  });

  it('a 0-changed answer is reported as already-done, not as a failure', async () => {
    VouchersService.listRecipients.mockResolvedValue([recipient(STUDENT_A)]);
    VouchersService.detachRecipient.mockResolvedValue(mutation(1, 0));

    const w = await mountSheet();
    await w.find('[data-testid="recipient-remove"]').trigger('click');
    await flushPromises();

    expect(toasts.error).not.toHaveBeenCalled();
    expect(toasts.success).toHaveBeenCalledWith(
      'Siswa tersebut bukan penerima voucher ini.',
    );
  });
});

// ─── Ability gating ──────────────────────────────────────────────────

describe('AdminTutoring2VoucherRecipientsSheet · ability gates', () => {
  it('WITH manage: the add form and the per-row remove controls are there', async () => {
    VouchersService.listRecipients.mockResolvedValue([recipient(STUDENT_A)]);

    const w = await mountSheet({ canManage: true });

    expect(w.find('[data-testid="recipients-add"]').exists()).toBe(true);
    expect(w.find('[data-testid="recipient-remove"]').exists()).toBe(true);
    expect(field(w, 'recipient_student_id').exists()).toBe(true);
  });

  it('WITHOUT manage: every write control is gone — but the LIST survives', async () => {
    VouchersService.listRecipients.mockResolvedValue([recipient(STUDENT_A)]);

    const w = await mountSheet({ canManage: false });

    expect(w.find('[data-testid="recipients-add"]').exists()).toBe(false);
    expect(w.find('[data-testid="recipient-remove"]').exists()).toBe(false);
    expect(field(w, 'recipient_student_id').exists()).toBe(false);
    // The half a pure-absence assertion would miss: `recipients` gates
    // on `tutoring.voucher.view`, a DIFFERENT key, so read-only staff
    // must still see who holds the promo.
    expect(w.findAll('[data-testid="recipient-row"]')).toHaveLength(1);
    expect(w.find('[data-testid="recipients-nature"]').text()).toContain(
      'Voucher personal',
    );
    expect(w.find('[data-testid="recipients-readonly"]').exists()).toBe(true);
  });

  it('WITHOUT manage: never even fetches the student picker list', async () => {
    await mountSheet({ canManage: false });

    // `StudentController::index` authorizes `tutoring.student.view`.
    // Calling it to populate a dropdown nobody can see is a guaranteed
    // wasted request and a possible 403 toast.
    expect(TutoringStudentsService.list).not.toHaveBeenCalled();
  });
});

// ─── The picker is a page, and says so ───────────────────────────────

describe('AdminTutoring2VoucherRecipientsSheet · picker honesty', () => {
  it('says the list is partial when the server filled the whole page', async () => {
    // `StudentController::index` caps `per_page` at 100 server-side; the
    // sheet asks for 50 and must not present a full page as the roster.
    TutoringStudentsService.list.mockResolvedValue({
      items: Array.from({ length: 50 }, (_, i) => ({
        id: `st-${i}`,
        school_id: 'sc-1',
        name: `Siswa ${i}`,
        student_number: String(2400 + i),
      })),
      pagination: undefined,
    });

    const w = await mountSheet();

    expect(w.find('[data-testid="students-truncated"]').exists()).toBe(true);
  });

  it('stays quiet when the page came back short', async () => {
    const w = await mountSheet();

    expect(w.find('[data-testid="students-truncated"]').exists()).toBe(false);
  });

  it('asks the server to search rather than filtering the page in memory', async () => {
    const w = await mountSheet();
    expect(TutoringStudentsService.list).toHaveBeenCalledTimes(1);
    expect(TutoringStudentsService.list.mock.calls[0][0]).toMatchObject({
      per_page: 50,
      active: true,
    });
  });

  it('drops students who are ALREADY recipients from the picker', async () => {
    VouchersService.listRecipients.mockResolvedValue([recipient(STUDENT_A)]);

    const w = await mountSheet();
    const values = field(w, 'recipient_student_id')
      .findAll('option')
      .map((o) => o.attributes('value'))
      .filter((v) => v !== '');

    expect(values).not.toContain(STUDENT_A);
    expect(values).toContain(STUDENT_B);
  });

  it('a student staged once cannot be staged twice', async () => {
    const w = await mountSheet();

    await stage(w, STUDENT_A);
    await stage(w, STUDENT_A);

    expect(w.findAll('[data-testid="staged-chip"]')).toHaveLength(1);
  });

  it('a failed student fetch names the reason instead of reading as "no students"', async () => {
    TutoringStudentsService.list.mockRejectedValueOnce({
      response: { status: 403, data: { message: 'Akses ditolak.' } },
    });

    const w = await mountSheet();

    expect(w.find('[data-testid="students-error"]').exists()).toBe(true);
    expect(w.find('[data-testid="students-none"]').exists()).toBe(false);
  });
});
