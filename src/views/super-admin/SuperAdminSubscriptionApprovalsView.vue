<!--
  SuperAdminSubscriptionApprovalsView.vue — /super-admin/subscription-approvals

  Frame 1 of the mockup: list-style queue of subscriptions the customer
  has claimed are paid but which the KamilEdu team hasn't reconciled
  against BSI mutations yet. Wraps the three AdminBillingController
  endpoints in a single-page workflow:

    - GET  /billing/admin/pending-approvals  → list (paginated)
    - POST /billing/admin/approve/{id}       → activate a sub
    - POST /billing/admin/reject/{id}        → cancel with reason

  Layout mirrors the neighbouring super-admin views
  (SuperAdminDemoRequestView.vue) for cohesion — BrandPageHeader,
  metric strip, chip row, list rows, then a slide-in drawer for the
  focused row instead of a dedicated detail route.

  Auth gate: `meta.superAdmin: true` at the router level + backend
  middleware. A non-super-admin who bookmarks this page gets a friendly
  403 message from the service layer.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { SubscriptionApprovalService } from '@/services/subscription-approval.service';
import { SubscriptionBillingService } from '@/services/billing.service';
import {
  waitingTone,
  type PendingApproval,
  type PendingApprovalMeta,
  type WaitingTone,
} from '@/types/subscription-approval';
import type { PricingPlan } from '@/types/subscription-billing';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import Pagination from '@/components/data/Pagination.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import { formatRupiah } from '@/lib/format';
import type { Pagination as PaginationModel } from '@/types/api';
import SubscriptionApprovalDetailPanel from './SubscriptionApprovalDetailPanel.vue';
import RejectSubscriptionModal from './RejectSubscriptionModal.vue';

// ── List state ──
const rows = ref<PendingApproval[]>([]);
const meta = ref<PendingApprovalMeta | null>(null);
const page = ref(1);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const PER_PAGE = 20;

// ── Drawer state ──
const focusedId = ref<string | null>(null);
const focused = computed<PendingApproval | null>(() =>
  rows.value.find((r) => r.id === focusedId.value) ?? null,
);
const reconciled = ref(false);
const approving = ref(false);

// ── Reject modal state ──
const rejectOpen = ref(false);
const rejecting = ref(false);

// ── Bank details — reused from /billing/plans so the drawer can show
//   the exact rekening tujuan without re-fetching per row. Loaded once
//   on mount; the plan cache in the service prevents re-fetches on
//   navigation. Safe to be null (drawer hides the panel).
const bankTransfer = ref<PricingPlan['bank_transfer'] | null>(null);

// ── Local toast for approve/reject success + error surfaces ──
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

async function reload() {
  isLoading.value = true;
  loadError.value = null;
  try {
    const res = await SubscriptionApprovalService.list({
      per_page: PER_PAGE,
      page: page.value,
    });
    rows.value = res.items;
    meta.value = res.meta;
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

async function loadBankTransfer() {
  try {
    const plan = await SubscriptionBillingService.getPlans();
    bankTransfer.value = plan.bank_transfer ?? null;
  } catch {
    // Non-fatal — the drawer just hides the bank panel.
    bankTransfer.value = null;
  }
}

function goToPage(p: number) {
  page.value = p;
  reload();
}

function openRow(row: PendingApproval) {
  focusedId.value = row.id;
  reconciled.value = false;
}

function closeDrawer() {
  focusedId.value = null;
  reconciled.value = false;
}

async function onApprove() {
  if (!focused.value) return;
  const id = focused.value.id;
  approving.value = true;
  try {
    const result = await SubscriptionApprovalService.approve(id);
    // Drop the row locally so the queue reflects the new state without
    // a round-trip. The counter under the header derives from meta so
    // decrement that too.
    rows.value = rows.value.filter((r) => r.id !== id);
    if (meta.value) meta.value.total = Math.max(0, meta.value.total - 1);
    closeDrawer();
    toast.value = {
      tone: 'success',
      message: result.already_active
        ? 'Pesanan sudah aktif sebelumnya — tidak ada notifikasi ulang.'
        : 'Pesanan disetujui. Email + WhatsApp aktivasi dikirim ke admin.',
    };
  } catch (e) {
    toast.value = { tone: 'error', message: (e as Error).message };
  } finally {
    approving.value = false;
  }
}

function openReject() {
  if (!focused.value) return;
  rejectOpen.value = true;
}

async function onReject(reason: string) {
  if (!focused.value) return;
  const id = focused.value.id;
  rejecting.value = true;
  try {
    const result = await SubscriptionApprovalService.reject(id, reason);
    rows.value = rows.value.filter((r) => r.id !== id);
    if (meta.value) meta.value.total = Math.max(0, meta.value.total - 1);
    rejectOpen.value = false;
    closeDrawer();
    toast.value = {
      tone: 'success',
      message: result.already_canceled
        ? 'Pesanan sudah dibatalkan sebelumnya.'
        : 'Pesanan ditolak. Alasan dikirim ke admin lewat email + WhatsApp.',
    };
  } catch (e) {
    toast.value = { tone: 'error', message: (e as Error).message };
  } finally {
    rejecting.value = false;
  }
}

onMounted(() => {
  reload();
  loadBankTransfer();
});

// ── Derived ─────────────────────────────────────────────────────────
const listState = computed<AsyncState<PendingApproval[]>>(() => {
  if (isLoading.value && rows.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

const paginationModel = computed<PaginationModel | null>(() => {
  const m = meta.value;
  if (!m || m.last_page <= 1) return null;
  return {
    total_items: m.total,
    total_pages: m.last_page,
    current_page: m.current_page,
    per_page: m.per_page,
    has_next_page: m.current_page < m.last_page,
    has_prev_page: m.current_page > 1,
  };
});

const headerMeta = computed(() => {
  if (!meta.value) return 'Memuat antrian…';
  const n = meta.value.total;
  return `${n} ${n === 1 ? 'pesanan menunggu verifikasi' : 'pesanan menunggu verifikasi'}`;
});

const metrics = computed(() => {
  const total = rows.value.length;
  const warn = rows.value.filter((r) => waitingTone(r.waiting_hours) === 'warn').length;
  const crit = rows.value.filter((r) => waitingTone(r.waiting_hours) === 'critical').length;
  const nominal = rows.value.reduce((sum, r) => sum + r.amount, 0);
  return { total, warn, crit, nominal };
});

function toneClass(tone: WaitingTone): string {
  if (tone === 'critical') return 'bg-rose-100 text-rose-700 border-rose-200';
  if (tone === 'warn') return 'bg-amber-100 text-amber-800 border-amber-200';
  return 'bg-emerald-100 text-emerald-700 border-emerald-200';
}

function toneIcon(tone: WaitingTone): 'alert-triangle' | 'clock' {
  return tone === 'critical' ? 'alert-triangle' : 'clock';
}

function planLabel(plan: PendingApproval['plan']): string {
  return plan === 'yearly' ? 'Tahunan' : 'Bulanan';
}

// Rupiah short-form for the metric strip.
function compactRupiah(v: number): string {
  if (v >= 1_000_000_000) return `Rp ${(v / 1_000_000_000).toFixed(1)}mrd`;
  if (v >= 1_000_000) return `Rp ${(v / 1_000_000).toFixed(1)}jt`;
  if (v >= 1_000) return `Rp ${(v / 1_000).toFixed(0)}rb`;
  return `Rp ${v}`;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Platform · Super Admin"
      title="Verifikasi Pembayaran Langganan"
      :meta="headerMeta"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 px-3 py-1.5 text-xs font-bold text-white transition"
        @click="reload"
      >
        <NavIcon name="refresh-cw" :size="14" />
        Muat ulang
      </button>
    </BrandPageHeader>

    <!-- Metric strip -->
    <section class="grid grid-cols-2 md:grid-cols-4 gap-2">
      <div class="rounded-xl bg-white border border-slate-200 p-3">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-slate-500">
          Menunggu
        </p>
        <p class="mt-1 text-xl font-black text-slate-900 tabular-nums">
          {{ metrics.total }}
        </p>
      </div>
      <div class="rounded-xl bg-white border border-slate-200 p-3">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-slate-500">
          ≥ 12 jam
        </p>
        <p class="mt-1 text-xl font-black tabular-nums" :class="metrics.warn > 0 ? 'text-amber-700' : 'text-slate-400'">
          {{ metrics.warn }}
        </p>
      </div>
      <div class="rounded-xl bg-white border border-slate-200 p-3">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-slate-500">
          ≥ 24 jam
        </p>
        <p class="mt-1 text-xl font-black tabular-nums" :class="metrics.crit > 0 ? 'text-rose-700' : 'text-slate-400'">
          {{ metrics.crit }}
        </p>
      </div>
      <div class="rounded-xl bg-white border border-slate-200 p-3">
        <p class="text-[10px] font-semibold uppercase tracking-wider text-slate-500">
          Nominal antrian
        </p>
        <p class="mt-1 text-xl font-black text-slate-900 tabular-nums">
          {{ compactRupiah(metrics.nominal) }}
        </p>
      </div>
    </section>

    <!-- LIST -->
    <AsyncView
      :state="listState"
      empty-title="Antrian kosong"
      empty-description="Belum ada pesanan yang menunggu verifikasi transfer."
      empty-icon="inbox"
      @retry="reload"
    >
      <div class="space-y-2">
        <button
          v-for="row in rows"
          :key="row.id"
          type="button"
          class="w-full text-left bg-white border rounded-2xl p-4 hover:border-role-admin/40 hover:shadow-sm transition flex items-start gap-3"
          :class="row.id === focusedId
              ? 'border-brand-cobalt bg-brand-50/40 ring-2 ring-brand-cobalt/15'
              : 'border-slate-200'"
          @click="openRow(row)"
        >
          <div
            class="w-10 h-10 rounded-xl bg-role-admin-soft text-role-admin grid place-items-center flex-shrink-0"
          >
            <NavIcon name="credit-card" :size="18" />
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <span class="font-bold text-slate-900 truncate">
                {{ row.tenant_name }}
              </span>
              <span class="text-[10px] font-bold uppercase tracking-wide bg-slate-100 text-slate-600 px-2 py-0.5 rounded">
                {{ planLabel(row.plan) }}
              </span>
              <span
                v-if="row.is_claimed"
                class="text-[10px] font-bold uppercase tracking-wide bg-emerald-100 text-emerald-700 border border-emerald-200 px-2 py-0.5 rounded inline-flex items-center gap-1"
                title="Customer sudah klik “sudah transfer”"
              >
                <NavIcon name="check-circle" :size="10" />
                Diklaim
              </span>
              <span
                v-else
                class="text-[10px] font-bold uppercase tracking-wide bg-slate-50 text-slate-500 border border-slate-200 px-2 py-0.5 rounded inline-flex items-center gap-1"
                title="Customer belum konfirmasi transfer — verifikasi langsung dari mutasi rekening"
              >
                <NavIcon name="clock" :size="10" />
                Belum diklaim
              </span>
              <span
                class="text-[10px] font-bold uppercase tracking-wide px-2 py-0.5 rounded-full border inline-flex items-center gap-1"
                :class="toneClass(waitingTone(row.waiting_hours))"
              >
                <NavIcon :name="toneIcon(waitingTone(row.waiting_hours))" :size="10" />
                {{ row.waiting_hours }} jam
              </span>
            </div>
            <p class="text-xs text-slate-500 mt-0.5 truncate font-mono">
              {{ row.order_id }}
            </p>
            <p v-if="row.admin_email || row.admin_whatsapp" class="text-[11px] text-slate-500 mt-1 truncate">
              <span v-if="row.admin_email">{{ row.admin_email }}</span>
              <span v-if="row.admin_email && row.admin_whatsapp"> · </span>
              <span v-if="row.admin_whatsapp" class="tabular-nums">{{ row.admin_whatsapp }}</span>
            </p>
          </div>
          <div class="flex flex-col items-end gap-1 flex-shrink-0">
            <p class="text-sm font-bold text-slate-900 tabular-nums">
              {{ formatRupiah(row.amount) }}
            </p>
            <span class="hidden sm:inline-flex items-center gap-1 text-[11px] font-semibold text-brand-cobalt">
              Verifikasi
              <NavIcon name="chevron-right" :size="14" />
            </span>
          </div>
        </button>
      </div>

      <div v-if="paginationModel" class="mt-5">
        <Pagination :pagination="paginationModel" @change="goToPage" />
      </div>
    </AsyncView>

    <!-- Detail drawer -->
    <SubscriptionApprovalDetailPanel
      :open="focused !== null"
      :approval="focused"
      :bank-transfer="bankTransfer"
      :reconciled="reconciled"
      :approving="approving"
      :rejecting="rejecting"
      @update:reconciled="reconciled = $event"
      @close="closeDrawer"
      @approve="onApprove"
      @reject="openReject"
    />

    <!-- Reject modal -->
    <RejectSubscriptionModal
      :open="rejectOpen"
      :approval="focused"
      :submitting="rejecting"
      @close="rejectOpen = false"
      @confirm="onReject"
    />

    <!-- Toast -->
    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
