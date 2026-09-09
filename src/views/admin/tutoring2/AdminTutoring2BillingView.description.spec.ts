/**
 * Read-back spec for the bill "Keterangan" on AdminTutoring2BillingView.
 *
 * WHY THIS FILE EXISTS. `description` was a write-only field on web for
 * as long as it existed on the wire: the Tambah Tagihan sheet posts it,
 * `BillResource` returns it on index and show, and NOTHING on web
 * rendered it. An admin could type a note explaining why a one-off bill
 * was raised, save it, and then never see that note again from any
 * screen — which is only marginally better than the discarded-input bug
 * the sheet's own docblock was written to avoid.
 *
 * This is the surface where the person who TYPED the note reads it
 * back, so it is the one that earns a spec of its own.
 *
 * What is locked:
 *
 *   • A manual bill's note is rendered in the row.
 *   • A generated bill — the enrollment hook's and the monthly cron's,
 *     which carry no note — renders NO empty line. `null` and `''`
 *     both count as "no note"; the second matters because a bill
 *     created before the sheet stopped sending `''` can still be in
 *     the table.
 *   • The student name is still the row's primary text. The note is a
 *     second line beneath it, not a replacement for it.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import AdminTutoring2BillingView from './AdminTutoring2BillingView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: {
    listBills: vi.fn(),
    getBillsSummary: vi.fn(),
    createBill: vi.fn(),
    listPaymentTypes: vi.fn(),
    listEnrollments: vi.fn(),
  },
}));

vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { list: vi.fn() },
}));

vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn() }),
}));

vi.mock('@/composables/useMe', () => ({
  useMe: () => ({ can: () => false }),
}));

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
            all: 'Semua', source: 'Sumber', status: 'Status', period: 'Periode',
            roleAdmin: 'Admin', loading: 'Memuat', metaBills: '{count} tagihan',
            student: 'Siswa', dueDate: 'Jatuh tempo', amount: 'Nominal',
            billNote: 'Keterangan',
          },
          admin: {
            billing: {
              title: 'Keuangan',
              newCta: 'Buat tagihan',
              emptyTitle: 'Belum ada tagihan',
              emptyDesc: 'Belum ada tagihan.',
              searchPh: 'Cari siswa…',
              kpiBilled: 'Tertagih', kpiPaid: 'Terbayar',
              kpiOverdue: 'Menunggak', kpiOverdueCount: 'Overdue',
              dayPrefix: 'Tgl {day}',
            },
          },
        },
      },
    },
  });
}

const STUBS = {
  BrandPageHeader: true,
  KpiStripCards: true,
  StatusBadge: true,
  MonthPickerModal: true,
  PageFilterToolbar: { template: '<div><slot name="chips" /></div>' },
  AppFilterChip: {
    props: ['label', 'value', 'iconName', 'active'],
    emits: ['click'],
    template: '<button @click="$emit(\'click\')">{{ value }}</button>',
  },
  AsyncView: { template: '<div><slot /></div>' },
  AdminTutoring2BillCreateSheet: true,
};

/** A row as `BillResource` actually serialises one. */
function bill(over = {}) {
  return {
    id: 'bi-1',
    school_id: 'sc-1',
    student_id: 'st-1',
    student_name: 'Aisyah Putri',
    payment_type_id: 'pt-1',
    amount: 350_000,
    status: 'unpaid',
    source_type: 'TUTORING_PREPAID',
    source_label: 'Prabayar',
    due_date: '2026-09-30',
    description: null,
    ...over,
  };
}

async function mountView(rows) {
  TutoringBimbelService.listBills.mockResolvedValue({
    items: rows,
    pagination: undefined,
  });
  setActivePinia(createPinia());
  const w = mount(AdminTutoring2BillingView, {
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const NOTES = '[data-testid="bill-description"]';

beforeEach(() => {
  vi.clearAllMocks();
  TutoringBimbelService.getBillsSummary.mockResolvedValue({
    tertagih: 0, terbayar: 0, menunggak: 0, overdue_count: 0,
  });
});

describe("a manual bill's Keterangan is read back in the list", () => {
  it('renders the note the admin typed', async () => {
    const w = await mountView([
      bill({ description: 'Tambahan sesi privat 5 Sep' }),
    ]);

    const notes = w.findAll(NOTES);
    expect(notes).toHaveLength(1);
    expect(notes[0].text()).toBe('Tambahan sesi privat 5 Sep');
  });

  it('keeps the student name as the row\'s primary text', async () => {
    const w = await mountView([
      bill({ description: 'Tambahan sesi privat 5 Sep' }),
    ]);

    // The note is an ADDITION to the row, not a replacement — a table
    // whose first column stopped naming the student would be worse
    // than one that never showed the note.
    expect(w.text()).toContain('Aisyah Putri');
    expect(w.text()).toContain('Tambahan sesi privat 5 Sep');
  });

  it('renders one note per row, on the right row', async () => {
    const w = await mountView([
      bill({ id: 'bi-1', student_name: 'Aisyah Putri', description: 'Modul cetak' }),
      bill({ id: 'bi-2', student_name: 'Bagus Pratama', description: null }),
      bill({ id: 'bi-3', student_name: 'Citra Dewi', description: 'Denda telat' }),
    ]);

    expect(w.findAll(NOTES).map((n) => n.text())).toEqual([
      'Modul cetak',
      'Denda telat',
    ]);
  });
});

describe('a bill with no Keterangan renders no empty line', () => {
  it('shows nothing for a cron-raised bill (description null)', async () => {
    const w = await mountView([bill({ description: null })]);

    expect(w.findAll(NOTES)).toHaveLength(0);
  });

  it('shows nothing when the key is absent altogether', async () => {
    const row = bill();
    delete row.description;
    const w = await mountView([row]);

    expect(w.findAll(NOTES)).toHaveLength(0);
  });

  it("shows nothing for a stored empty string", async () => {
    // The sheet no longer sends `''`, but rows written before it stopped
    // can still be in the table, and an empty grey line under a name
    // reads as a rendering bug.
    const w = await mountView([bill({ description: '' })]);

    expect(w.findAll(NOTES)).toHaveLength(0);
  });
});
