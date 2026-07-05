<!--
  SubscriptionApprovalDetailPanel.vue — Frame 2 of the mockup.

  Slide-in drawer on desktop, full-page section on mobile. Renders the
  selected PendingApproval row with three panels:
    1. Ringkasan pesanan — plan, seats, tarif, diskon, total.
    2. Kontak admin — email (link), WhatsApp (wa.me deep link), timestamps.
    3. Cek mutasi rekening — the exact bank + nominal + berita transfer
       the bendahara must reconcile against BSI mutation history.

  Then a "sudah cek" confirmation checkbox gates the primary Setujui
  CTA — you can't accidentally approve without at least ticking that
  you've reconciled. The Tolak CTA is always available (the reason
  modal is the real safeguard on that side).

  Seat / period breakdown is computed locally from `amount` + `plan`
  because /pending-approvals doesn't return the seat counts —
  `student_count` / `staff_count` live on the `subscriptions` row but
  weren't projected onto the queue payload. If future work needs the
  breakdown, extend the backend controller instead of guessing here.
-->
<script setup lang="ts">
import { computed } from 'vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatDateTime, formatRupiah } from '@/lib/format';
import {
  waitingTone,
  type PendingApproval,
  type WaitingTone,
} from '@/types/subscription-approval';

const props = defineProps<{
  open: boolean;
  approval: PendingApproval | null;
  bankTransfer: {
    bank_name: string;
    account_number: string;
    account_holder: string;
  } | null;
  reconciled: boolean;
  approving: boolean;
  rejecting: boolean;
}>();

const emit = defineEmits<{
  close: [];
  'update:reconciled': [boolean];
  approve: [];
  reject: [];
}>();

const tone = computed<WaitingTone | null>(() =>
  props.approval ? waitingTone(props.approval.waiting_hours) : null,
);

const toneClass = computed(() => {
  switch (tone.value) {
    case 'critical':
      return 'bg-rose-100 text-rose-700 border-rose-200';
    case 'warn':
      return 'bg-amber-100 text-amber-800 border-amber-200';
    default:
      return 'bg-emerald-100 text-emerald-700 border-emerald-200';
  }
});

const planLabel = computed(() =>
  props.approval?.plan === 'yearly' ? 'Tahunan' : 'Bulanan',
);

const waLink = computed(() => {
  const wa = props.approval?.admin_whatsapp?.replace(/\D/g, '');
  if (!wa) return null;
  return `https://wa.me/${wa.startsWith('0') ? '62' + wa.slice(1) : wa}`;
});
</script>

<template>
  <transition
    enter-active-class="transition-opacity duration-150"
    leave-active-class="transition-opacity duration-100"
    enter-from-class="opacity-0"
    leave-to-class="opacity-0"
  >
    <div
      v-if="open && approval"
      class="fixed inset-0 z-40 bg-slate-900/40"
      @click="emit('close')"
    />
  </transition>

  <transition
    enter-active-class="transition-transform duration-200 ease-out"
    leave-active-class="transition-transform duration-150 ease-in"
    enter-from-class="translate-x-full"
    leave-to-class="translate-x-full"
  >
    <aside
      v-if="open && approval"
      class="fixed top-0 right-0 z-50 h-full w-full max-w-xl bg-white shadow-2xl overflow-y-auto"
      role="dialog"
      aria-label="Detail pesanan langganan"
    >
      <!-- Sticky header -->
      <header class="sticky top-0 z-10 bg-white border-b border-slate-200 px-5 py-4 flex items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2 flex-wrap">
            <span
              class="text-3xs font-black tracking-widest uppercase px-2 py-0.5 rounded-full border"
              :class="toneClass"
            >
              Menunggu · {{ approval.waiting_hours }} jam
            </span>
            <span class="text-3xs font-bold uppercase tracking-wider bg-slate-100 text-slate-600 px-2 py-0.5 rounded">
              {{ planLabel }}
            </span>
          </div>
          <h2 class="mt-1.5 text-base font-bold text-slate-900 truncate">
            {{ approval.tenant_name }}
          </h2>
          <p class="mt-0.5 text-2xs font-mono text-slate-500 truncate">
            {{ approval.order_id }}
          </p>
        </div>
        <button
          type="button"
          class="p-1.5 rounded-lg text-slate-400 hover:bg-slate-100 hover:text-slate-700 flex-shrink-0"
          aria-label="Tutup"
          @click="emit('close')"
        >
          <NavIcon name="x" :size="18" />
        </button>
      </header>

      <div class="p-5 space-y-4">
        <!-- Panel: Ringkasan pesanan -->
        <section class="rounded-xl border border-slate-200 p-4">
          <h3 class="text-[13px] font-bold text-slate-900 mb-3">
            Ringkasan pesanan
          </h3>
          <dl class="grid grid-cols-[minmax(120px,auto)_1fr] gap-y-2 gap-x-3 text-[13px]">
            <dt class="text-slate-500 text-xs">Paket</dt>
            <dd class="text-slate-900">
              {{ planLabel }}
              <span v-if="approval.plan === 'yearly'" class="text-xs text-emerald-700 ml-1">
                · hemat 20%
              </span>
            </dd>

            <dt class="text-slate-500 text-xs">Total tagihan</dt>
            <dd class="font-bold text-slate-900 tabular-nums">
              {{ formatRupiah(approval.amount) }}
            </dd>
          </dl>
        </section>

        <!-- Panel: Kontak admin -->
        <section class="rounded-xl border border-slate-200 p-4">
          <h3 class="text-[13px] font-bold text-slate-900 mb-3">
            Kontak admin
          </h3>
          <dl class="grid grid-cols-[minmax(120px,auto)_1fr] gap-y-2 gap-x-3 text-[13px]">
            <dt class="text-slate-500 text-xs">Nama tenant</dt>
            <dd class="text-slate-900">{{ approval.tenant_name }}</dd>

            <dt class="text-slate-500 text-xs">Admin email</dt>
            <dd>
              <a
                v-if="approval.admin_email"
                :href="`mailto:${approval.admin_email}`"
                class="text-brand-cobalt hover:underline break-all"
              >
                {{ approval.admin_email }}
              </a>
              <span v-else class="text-slate-400 text-xs">Tidak tersedia</span>
            </dd>

            <dt class="text-slate-500 text-xs">WhatsApp</dt>
            <dd class="flex items-center gap-2 flex-wrap">
              <span v-if="approval.admin_whatsapp" class="text-slate-900 tabular-nums">
                {{ approval.admin_whatsapp }}
              </span>
              <span v-else class="text-slate-400 text-xs">Tidak tersedia</span>
              <a
                v-if="waLink"
                :href="waLink"
                target="_blank"
                rel="noopener"
                class="inline-flex items-center gap-1 text-2xs font-semibold text-emerald-700 hover:text-emerald-800"
              >
                <NavIcon name="message-circle" :size="12" />
                Hubungi
              </a>
            </dd>

            <dt class="text-slate-500 text-xs">Diminta pada</dt>
            <dd class="text-slate-700 tabular-nums">
              {{ formatDateTime(approval.created_at) || '—' }}
            </dd>

            <dt class="text-slate-500 text-xs">Klaim transfer</dt>
            <dd class="text-slate-700 tabular-nums">
              {{ formatDateTime(approval.last_marked_at) || '—' }}
            </dd>
          </dl>
        </section>

        <!-- Panel: Cek mutasi rekening (amber) -->
        <section
          v-if="bankTransfer"
          class="rounded-xl border-2 border-amber-200 bg-amber-50/70 p-4"
        >
          <h3 class="text-[13px] font-bold text-amber-900 mb-1">
            Cek mutasi rekening ini
          </h3>
          <p class="text-2xs text-amber-800/80 mb-3 leading-relaxed">
            Cocokkan nominal masuk dan berita transfer dengan mutasi BSI sebelum menyetujui.
          </p>
          <dl class="grid grid-cols-[minmax(120px,auto)_1fr] gap-y-2 gap-x-3 text-[13px]">
            <dt class="text-amber-800 text-xs font-semibold">Rekening</dt>
            <dd class="text-amber-900">{{ bankTransfer.bank_name }}</dd>

            <dt class="text-amber-800 text-xs font-semibold">Nomor</dt>
            <dd class="font-mono text-amber-900">
              {{ bankTransfer.account_number }}
            </dd>

            <dt class="text-amber-800 text-xs font-semibold">Atas nama</dt>
            <dd class="text-amber-900">{{ bankTransfer.account_holder }}</dd>

            <dt class="text-amber-800 text-xs font-semibold">Nominal masuk</dt>
            <dd class="font-mono font-bold text-amber-900 tabular-nums">
              {{ formatRupiah(approval.amount) }}
            </dd>

            <dt class="text-amber-800 text-xs font-semibold">Berita transfer</dt>
            <dd class="font-mono text-amber-900 break-all">
              {{ approval.order_id }}
            </dd>
          </dl>
        </section>

        <!-- Reconciled confirmation -->
        <label
          class="flex items-start gap-3 rounded-xl border p-3.5 cursor-pointer transition-colors"
          :class="reconciled
              ? 'border-emerald-300 bg-emerald-50/60'
              : 'border-slate-200 bg-slate-50 hover:border-slate-300'"
        >
          <input
            type="checkbox"
            class="mt-0.5 h-4 w-4 rounded border-slate-300 text-brand-cobalt focus:ring-brand-cobalt"
            :checked="reconciled"
            @change="emit('update:reconciled', ($event.target as HTMLInputElement).checked)"
          />
          <span class="flex-1 min-w-0 text-[12px] leading-relaxed">
            <span class="block font-semibold text-slate-900 mb-0.5">
              Sudah cek mutasi BSI · nominal cocok
            </span>
            <span class="text-slate-600">
              Wajib dicek sebelum menyetujui. Setelah setuju, tenant langsung aktif
              {{ approval.plan === 'yearly' ? '12 bulan' : '1 bulan' }}
              (mulai hari ini) dan email + WhatsApp aktivasi otomatis dikirim ke admin.
            </span>
          </span>
        </label>
      </div>

      <!-- Sticky footer with actions -->
      <footer class="sticky bottom-0 bg-white border-t border-slate-200 px-5 py-3.5 flex flex-col sm:flex-row-reverse gap-2">
        <Button
          variant="primary"
          :disabled="!reconciled || approving || rejecting"
          :loading="approving"
          @click="emit('approve')"
        >
          <NavIcon name="check" :size="14" />
          Setujui &amp; aktifkan
        </Button>
        <Button
          variant="danger"
          :disabled="approving || rejecting"
          :loading="rejecting"
          @click="emit('reject')"
        >
          <NavIcon name="x" :size="14" />
          Tolak pembayaran
        </Button>
      </footer>
    </aside>
  </transition>
</template>
