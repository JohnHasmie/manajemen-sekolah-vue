/**
 * Read-back spec for the bill "Keterangan" on the siswa bill detail.
 *
 * The admin billing table is where the person who TYPED the note reads
 * it back; this is where the person being BILLED reads it. A one-off
 * bill with an amount and no explanation is exactly the row a siswa or
 * wali queries, and `BillResource` has been returning `description` on
 * `GET /tutoring-v2/bills/:id` with nothing on web rendering it.
 *
 * The empty case is the other half: bills raised by the enrollment hook
 * and the monthly cron carry no note at all, and they are the vast
 * majority of rows. A "Keterangan:" label with nothing after it would
 * appear on almost every bill in the system.
 */
// @ts-nocheck — vitest types not installed yet
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import StudentTutoring2BillDetailView from './StudentTutoring2BillDetailView.vue';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

vi.mock('@/services/tutoring-bimbel.service', () => ({
  TutoringBimbelService: { getBill: vi.fn() },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { id: 'bi-1' } }),
  useRouter: () => ({ push: vi.fn() }),
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
            roleStudent: 'Siswa',
            student: 'Siswa',
            billNote: 'Keterangan',
            billingMode: 'Mode',
            notAvailable: '—',
          },
          status: { paid: 'Lunas', overdue: 'Terlambat', unpaid: 'Belum bayar' },
          bills: {
            detail: {
              title: 'Detail tagihan',
              meta: 'Tagihan',
              emptyTitle: 'Tagihan tidak ditemukan',
              emptyDesc: 'Tagihan tidak ditemukan.',
              paymentsSection: 'Riwayat pembayaran',
              noPayments: 'Belum ada pembayaran.',
            },
          },
          student: { bills: { dueOn: 'Jatuh tempo {date}', payCta: 'Bayar sekarang' } },
        },
      },
    },
  });
}

const STUBS = {
  BrandPageHeader: true,
  StatusBadge: true,
  Button: true,
  AsyncView: { template: '<div><slot /></div>' },
};

function bill(over = {}) {
  return {
    id: 'bi-1',
    school_id: 'sc-1',
    student_id: 'st-1',
    student_name: 'Aisyah Putri',
    student_number: 'B-001',
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

async function mountView(row) {
  TutoringBimbelService.getBill.mockResolvedValue(row);
  setActivePinia(createPinia());
  const w = mount(StudentTutoring2BillDetailView, {
    global: { plugins: [makeI18n()], stubs: STUBS },
  });
  await flushPromises();
  return w;
}

const NOTE = '[data-testid="bill-description"]';

beforeEach(() => vi.clearAllMocks());

describe('the bill detail shows why the bill exists', () => {
  it("renders the admin's Keterangan, under its own label", async () => {
    const w = await mountView(bill({ description: 'Tambahan sesi privat 5 Sep' }));

    expect(w.find(NOTE).exists()).toBe(true);
    expect(w.find(NOTE).text()).toContain('Keterangan');
    expect(w.find(NOTE).text()).toContain('Tambahan sesi privat 5 Sep');
  });

  it('keeps the amount and the student row it sits beside', async () => {
    const w = await mountView(bill({ description: 'Modul cetak' }));

    expect(w.text()).toContain('Aisyah Putri');
    expect(w.text()).toContain('Modul cetak');
  });
});

describe('a bill with no Keterangan shows no label', () => {
  it('renders nothing when description is null', async () => {
    const w = await mountView(bill({ description: null }));

    expect(w.find(NOTE).exists()).toBe(false);
    // Not just the value — the LABEL must go too, or every cron-raised
    // bill grows a dangling "Keterangan:".
    expect(w.text()).not.toContain('Keterangan');
  });

  it('renders nothing when the key is absent', async () => {
    const row = bill();
    delete row.description;
    const w = await mountView(row);

    expect(w.find(NOTE).exists()).toBe(false);
  });

  it('renders nothing for a stored empty string', async () => {
    const w = await mountView(bill({ description: '' }));

    expect(w.find(NOTE).exists()).toBe(false);
  });
});
