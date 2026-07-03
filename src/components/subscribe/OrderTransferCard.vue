<!--
  OrderTransferCard.vue — post-order transfer instructions with timer
  header, order summary, copyable bank details, warning card, and a
  4-step timeline. Matches mockup 3
  (subscribe_page_payment_and_thanks).

  Emits `mark-transferred`, `edit`, `share` for the parent to wire.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { money } from './moduleTokens';

const props = defineProps<{
  planLabel: string;
  studentCount: number;
  staffCount: number;
  amount: number;
  bankName: string;
  accountNumber: string;
  accountHolder: string;
  referenceCode: string;
  createdAt?: string | null;
  submitting?: boolean;
  notified?: boolean;
}>();

defineEmits<{
  'mark-transferred': [];
  edit: [];
  share: [];
}>();

const createdLabel = computed(() => {
  if (!props.createdAt) return 'Hari ini';
  const d = new Date(props.createdAt);
  return `Hari ini · ${d.getHours().toString().padStart(2, '0')}:${d
    .getMinutes()
    .toString()
    .padStart(2, '0')} WIB`;
});

function copy(v: string) {
  navigator.clipboard?.writeText(v);
}
</script>

<template>
  <div class="ot-card">
    <div class="ot-head">
      <div class="ot-head-i">
        <i class="ti ti-clock-hour-4" aria-hidden="true" />
      </div>
      <div>
        <div class="ot-head-kicker">Menunggu pembayaran</div>
        <div class="ot-head-title">Pesanan Anda sudah kami buat</div>
      </div>
    </div>

    <div class="ot-order">
      <div>
        <div class="ot-o-lbl">Paket</div>
        <div class="ot-o-val">{{ planLabel }}</div>
      </div>
      <div>
        <div class="ot-o-lbl">Skala</div>
        <div class="ot-o-val">
          {{ studentCount }} siswa · {{ staffCount }} guru
        </div>
      </div>
      <div>
        <div class="ot-o-lbl">Total tagihan</div>
        <div class="ot-o-val big">{{ money(amount) }}</div>
      </div>
    </div>

    <div class="ot-bank">
      <div class="ot-bank-head">
        <div class="ot-bank-i">{{ bankName }}</div>
        <div>
          <div class="ot-bank-name">Rekening tujuan</div>
          <div class="ot-bank-h">{{ accountHolder }}</div>
        </div>
      </div>

      <div class="ot-bank-grid">
        <div class="ot-b">
          <div class="ot-b-body">
            <div class="ot-b-lbl">Nomor rekening</div>
            <div class="ot-b-val">{{ accountNumber }}</div>
          </div>
          <button
            type="button"
            class="ot-b-copy"
            aria-label="Salin"
            @click="copy(accountNumber)"
          >
            <i class="ti ti-copy" style="font-size:16px" aria-hidden="true" />
          </button>
        </div>
        <div class="ot-b is-hi">
          <div class="ot-b-body">
            <div class="ot-b-lbl">Jumlah transfer (persis)</div>
            <div class="ot-b-val">{{ money(amount) }}</div>
          </div>
          <button
            type="button"
            class="ot-b-copy"
            aria-label="Salin"
            @click="copy(String(amount))"
          >
            <i class="ti ti-copy" style="font-size:16px" aria-hidden="true" />
          </button>
        </div>
        <div class="ot-b" style="grid-column: span 2">
          <div class="ot-b-body">
            <div class="ot-b-lbl">
              Kode referensi (tulis di berita transfer)
            </div>
            <div class="ot-b-val">{{ referenceCode }}</div>
          </div>
          <button
            type="button"
            class="ot-b-copy"
            aria-label="Salin"
            @click="copy(referenceCode)"
          >
            <i class="ti ti-copy" style="font-size:16px" aria-hidden="true" />
          </button>
        </div>
      </div>

      <div class="ot-warn">
        <i class="ti ti-alert-triangle" aria-hidden="true" />
        <div>
          <div class="ot-warn-t">Transfer dengan jumlah persis</div>
          <div class="ot-warn-d">
            Beda Rp 1 pun akan gagal cocok otomatis dan verifikasi jadi
            manual (lebih lama). Wajib tulis kode referensi di kolom
            berita transfer.
          </div>
        </div>
      </div>
    </div>

    <div class="ot-timeline">
      <div class="ot-tl-head">Alur setelah transfer</div>

      <div class="ot-tl-row done">
        <div class="ot-tl-dot">
          <i class="ti ti-check" style="font-size:13px" aria-hidden="true" />
        </div>
        <div class="ot-tl-body">
          <div class="ot-tl-title">Pesanan dibuat</div>
          <div class="ot-tl-time">{{ createdLabel }}</div>
        </div>
      </div>

      <div class="ot-tl-row" :class="notified ? 'done' : 'active'">
        <div class="ot-tl-dot">
          <i
            v-if="notified"
            class="ti ti-check"
            style="font-size:13px"
            aria-hidden="true"
          />
          <i
            v-else
            class="ti ti-loader-2"
            style="font-size:12px"
            aria-hidden="true"
          />
        </div>
        <div class="ot-tl-body">
          <div class="ot-tl-title">Anda transfer ke {{ bankName }}</div>
          <div class="ot-tl-time">
            <template v-if="notified">
              Konfirmasi Anda sudah kami terima
            </template>
            <template v-else>
              Klik "Saya sudah transfer" setelah selesai
            </template>
          </div>
        </div>
      </div>

      <div class="ot-tl-row" :class="notified ? 'active' : 'pending'">
        <div class="ot-tl-dot">3</div>
        <div class="ot-tl-body">
          <div class="ot-tl-title">Tim keuangan verifikasi</div>
          <div class="ot-tl-time">Estimasi 1×24 jam kerja</div>
        </div>
      </div>

      <div class="ot-tl-row pending">
        <div class="ot-tl-dot">4</div>
        <div class="ot-tl-body">
          <div class="ot-tl-title">
            Berlangganan aktif · notifikasi email + WA
          </div>
          <div class="ot-tl-time">
            Anda otomatis diarahkan ke dashboard
          </div>
        </div>
      </div>
    </div>

    <div v-if="!notified" class="ot-cta-row">
      <button
        type="button"
        class="ot-cta-primary"
        :disabled="submitting"
        @click="$emit('mark-transferred')"
      >
        <template v-if="submitting">Mengirim…</template>
        <template v-else>
          <i class="ti ti-check" aria-hidden="true" />
          Saya sudah transfer
        </template>
      </button>
      <button type="button" class="ot-cta-secondary" @click="$emit('edit')">
        <i class="ti ti-edit" style="font-size:13px" aria-hidden="true" />
        Ubah pesanan
      </button>
      <button type="button" class="ot-cta-secondary" @click="$emit('share')">
        <i class="ti ti-share" style="font-size:13px" aria-hidden="true" />
        Bagikan
      </button>
    </div>
  </div>
</template>

<style scoped>
.ot-card {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 14px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04),
              0 8px 24px rgba(15, 23, 42, 0.05);
}

.ot-head {
  padding: 14px 18px;
  background: linear-gradient(180deg, #FEF9C3 0%, #FEF3C7 100%);
  border-bottom: 0.5px solid #FDE68A;
  display: flex; align-items: center; gap: 10px;
}
.ot-head-i {
  width: 36px; height: 36px; border-radius: 10px;
  background: #FFFFFF; color: #B45309;
  display: grid; place-items: center;
  font-size: 18px;
  box-shadow: 0 1px 3px rgba(180, 83, 9, 0.15);
}
.ot-head-kicker {
  font-size: 10px; text-transform: uppercase;
  letter-spacing: 0.8px; color: #78350F; font-weight: 600;
}
.ot-head-title {
  font-size: 14.5px; font-weight: 500;
  color: #78350F; letter-spacing: -0.1px;
}

.ot-order {
  padding: 14px 18px;
  border-bottom: 0.5px solid #F1F5F9;
  display: grid; grid-template-columns: 1fr 1fr 1fr;
  gap: 14px;
}
.ot-o-lbl {
  font-size: 10px; text-transform: uppercase;
  letter-spacing: 0.4px; color: #94A3B8;
  font-weight: 500;
}
.ot-o-val { font-size: 13px; font-weight: 500; margin-top: 2px; color: #0F172A; }
.ot-o-val.big { font-size: 16px; font-weight: 600; color: #113E75; font-variant-numeric: tabular-nums; }

.ot-bank { padding: 16px 18px; }
.ot-bank-head {
  display: flex; align-items: center; gap: 10px;
  margin-bottom: 12px;
}
.ot-bank-i {
  width: 38px; height: 38px; border-radius: 8px;
  background: #FEF3C7; color: #B45309;
  display: grid; place-items: center;
  font-weight: 700; font-size: 12px;
  letter-spacing: 0.5px;
}
.ot-bank-name { font-size: 12px; color: #64748B; }
.ot-bank-h { font-size: 13.5px; font-weight: 500; color: #0F172A; }

.ot-bank-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.ot-b {
  background: #F8FAFC;
  border: 0.5px solid #E7ECF3;
  border-radius: 10px;
  padding: 10px 12px;
  display: flex; align-items: center;
}
.ot-b-body { flex: 1; min-width: 0; }
.ot-b-lbl {
  font-size: 10px; text-transform: uppercase;
  letter-spacing: 0.4px; color: #94A3B8;
  font-weight: 500;
}
.ot-b-val {
  font-size: 14px; font-weight: 500;
  margin-top: 2px;
  font-family: var(--font-mono);
  color: #0F172A;
  font-variant-numeric: tabular-nums;
}
.ot-b-copy {
  color: #64748B;
  padding: 6px; border-radius: 6px;
  background: transparent; border: none;
  cursor: pointer;
}
.ot-b-copy:hover { background: #FFFFFF; color: #1B6FB8; }
.ot-b.is-hi { background: #F0F7FF; border-color: #B5D4F4; }
.ot-b.is-hi .ot-b-val { color: #113E75; font-weight: 600; font-size: 16px; }

.ot-warn {
  margin-top: 12px;
  padding: 10px 12px;
  background: #FEE2E2;
  border: 0.5px solid #FCA5A5;
  border-radius: 10px;
  display: flex; align-items: flex-start; gap: 8px;
}
.ot-warn .ti { color: #B91C1C; font-size: 15px; flex-shrink: 0; margin-top: 1px; }
.ot-warn-t { font-size: 11.5px; font-weight: 500; color: #7F1D1D; }
.ot-warn-d { font-size: 10.5px; color: #991B1B; margin-top: 2px; line-height: 1.45; }

.ot-timeline {
  padding: 14px 18px 16px;
  background: #FBFDFF;
  border-top: 0.5px solid #E7ECF3;
}
.ot-tl-head {
  font-size: 11px; text-transform: uppercase;
  letter-spacing: 0.5px; color: #64748B;
  font-weight: 600; margin-bottom: 10px;
}
.ot-tl-row {
  display: flex; gap: 10px; align-items: flex-start;
  padding-bottom: 12px;
  position: relative;
}
.ot-tl-row:not(:last-child)::before {
  content: '';
  position: absolute; left: 11px; top: 24px; bottom: 0;
  width: 1.5px; background: #E2E8F0;
}
.ot-tl-row.done:not(:last-child)::before {
  background: linear-gradient(180deg, #5DCAA5 0%, #E2E8F0 100%);
}
.ot-tl-dot {
  width: 22px; height: 22px; border-radius: 50%;
  display: grid; place-items: center;
  background: #E2E8F0; color: #64748B;
  font-size: 12px;
  flex-shrink: 0;
}
.ot-tl-row.done .ot-tl-dot { background: #1D9E75; color: #fff; }
.ot-tl-row.active .ot-tl-dot {
  background: #1B6FB8; color: #fff;
  box-shadow: 0 0 0 4px rgba(27, 111, 184, 0.15);
}
.ot-tl-body { flex: 1; padding-top: 2px; }
.ot-tl-title { font-size: 12.5px; font-weight: 500; color: #0F172A; }
.ot-tl-time { font-size: 10.5px; color: #94A3B8; margin-top: 1px; }
.ot-tl-row.pending .ot-tl-title { color: #94A3B8; }

.ot-cta-row {
  padding: 12px 18px 16px;
  display: flex; gap: 8px;
  border-top: 0.5px solid #F1F5F9;
}
.ot-cta-primary {
  flex: 1;
  background: #059669; color: #fff; border: none;
  padding: 11px 14px; border-radius: 10px;
  font-size: 13px; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: 6px;
}
.ot-cta-primary:hover { background: #047857; }
.ot-cta-primary:disabled { background: #94A3B8; cursor: not-allowed; }
.ot-cta-secondary {
  padding: 11px 12px;
  background: transparent;
  border: 0.5px solid #CBD5E1;
  border-radius: 10px;
  font-size: 12px; color: #475569; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; gap: 5px;
}
</style>
