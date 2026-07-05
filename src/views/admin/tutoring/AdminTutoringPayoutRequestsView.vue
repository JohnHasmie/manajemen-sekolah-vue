<!--
  AdminTutoringPayoutRequestsView — admin queue for tutor honor-
  withdrawal requests. Pulls /tutoring/payouts/requests and groups by
  status into 4 tabs (Menunggu / Disetujui / Dibayar / Ditolak).

  Per-row actions are status-aware:
    - PENDING  → Setujui  | Tolak
    - APPROVED → Tandai Dibayar | Rollback
    - PAID     → Lihat Bukti? | Rollback
    - REJECTED → (read-only)

  We keep ONE shared loader and filter client-side per tab so switching
  tabs is instant. The backend already returns at most 50 rows by
  default; if a tenant grows past that we'll add pagination here.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type {
  TutorPayoutRequest,
  TutorPayoutRequestStatus,
} from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminMarkPaidDialog from '@/components/tutoring/AdminMarkPaidDialog.vue';
import AdminRejectDialog from '@/components/tutoring/AdminRejectDialog.vue';

const { t } = useI18n();
const toast = useToast();

const STATUSES: TutorPayoutRequestStatus[] = ['PENDING', 'APPROVED', 'PAID', 'REJECTED'];

const STATUS_BADGE_CLASS: Record<TutorPayoutRequestStatus, string> = {
  PENDING: 'bg-tutoring-amber-dim text-tutoring-amber',
  APPROVED: 'bg-tutoring-accent-dim text-tutoring-accent',
  PAID: 'bg-tutoring-green-dim text-tutoring-green',
  REJECTED: 'bg-tutoring-red-dim text-tutoring-red',
};

const loading = ref(true);
const rows = ref<TutorPayoutRequest[]>([]);
const activeTab = ref<TutorPayoutRequestStatus>('PENDING');

const busyRowId = ref<string | null>(null);
const markPaidTarget = ref<TutorPayoutRequest | null>(null);
const rejectTarget = ref<TutorPayoutRequest | null>(null);

async function load() {
  loading.value = true;
  try {
    // Pull a wide page once and bucket client-side. per_page=100 covers
    // every realistic active tenant; we can paginate later if needed.
    const res = await TutoringService.listAllPayoutRequests({ per_page: 100 });
    rows.value = res.items;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.bimbel.payout_requests.load_fail'),
    );
    rows.value = [];
  } finally {
    loading.value = false;
  }
}
onMounted(load);

const counts = computed<Record<TutorPayoutRequestStatus, number>>(() => {
  const c: Record<TutorPayoutRequestStatus, number> = {
    PENDING: 0,
    APPROVED: 0,
    PAID: 0,
    REJECTED: 0,
  };
  for (const r of rows.value) {
    if (c[r.status] != null) c[r.status]++;
  }
  return c;
});

const visibleRows = computed(() =>
  rows.value.filter((r) => r.status === activeTab.value),
);

function tabLabel(s: TutorPayoutRequestStatus): string {
  return t(`admin.bimbel.payout_requests.tab_${s.toLowerCase()}`);
}

function periodLabel(req: TutorPayoutRequest): string {
  if (!req.period_from || !req.period_to) return '—';
  const from = new Date(req.period_from);
  const to = new Date(req.period_to);
  const opt: Intl.DateTimeFormatOptions = { day: '2-digit', month: 'short', year: 'numeric' };
  return `${from.toLocaleDateString('id-ID', opt)} → ${to.toLocaleDateString('id-ID', opt)}`;
}

function ts(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function applyUpdated(updated: TutorPayoutRequest) {
  const idx = rows.value.findIndex((r) => r.id === updated.id);
  if (idx >= 0) {
    rows.value.splice(idx, 1, updated);
  } else {
    rows.value.unshift(updated);
  }
}

async function onApprove(req: TutorPayoutRequest) {
  busyRowId.value = req.id;
  try {
    const updated = await TutoringService.approvePayoutRequest(req.id);
    applyUpdated(updated);
    toast.success(t('admin.bimbel.payout_requests.approve_ok'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.bimbel.payout_requests.approve_fail'),
    );
  } finally {
    busyRowId.value = null;
  }
}

async function onRollback(req: TutorPayoutRequest) {
  if (!confirm(t('admin.bimbel.payout_requests.rollback_confirm'))) return;
  busyRowId.value = req.id;
  try {
    const updated = await TutoringService.rollbackPayoutRequest(req.id);
    applyUpdated(updated);
    toast.success(t('admin.bimbel.payout_requests.rollback_ok'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.bimbel.payout_requests.rollback_fail'),
    );
  } finally {
    busyRowId.value = null;
  }
}

function openMarkPaid(req: TutorPayoutRequest) {
  markPaidTarget.value = req;
}
function openReject(req: TutorPayoutRequest) {
  rejectTarget.value = req;
}

function onMarkPaidDone(updated: TutorPayoutRequest) {
  applyUpdated(updated);
  markPaidTarget.value = null;
}
function onRejectDone(updated: TutorPayoutRequest) {
  applyUpdated(updated);
  rejectTarget.value = null;
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.payout_requests.kicker')"
      :title="t('admin.bimbel.payout_requests.title')"
      :meta="t('admin.bimbel.payout_requests.meta', { pending: counts.PENDING })"
    />

    <!-- Status tab pills with live counts -->
    <div class="flex flex-wrap gap-2">
      <button
        v-for="s in STATUSES"
        :key="s"
        type="button"
        class="inline-flex items-center gap-2 rounded-xl border px-3 py-2 text-[13px] font-bold transition"
        :class="
          activeTab === s
            ? 'bg-tutoring-accent text-white border-tutoring-accent shadow-sm'
            : 'bg-tutoring-panel text-tutoring-text-mid border-tutoring-border-soft hover:bg-tutoring-bg'
        "
        @click="activeTab = s"
      >
        <span>{{ tabLabel(s) }}</span>
        <span
          class="rounded-md px-1.5 py-0 text-2xs"
          :class="
            activeTab === s
              ? 'bg-white/20 text-white'
              : STATUS_BADGE_CLASS[s]
          "
        >{{ counts[s] }}</span>
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="visibleRows.length === 0"
      :text="t('admin.bimbel.payout_requests.empty')"
      icon="wallet"
    />
    <div
      v-else
      class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl overflow-hidden"
    >
      <ul class="divide-y divide-tutoring-border-soft">
        <li
          v-for="req in visibleRows"
          :key="req.id"
          class="p-4 sm:p-5"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0 flex-1">
              <p class="text-[15px] font-bold text-tutoring-text-hi truncate">
                {{ req.tutor?.name ?? t('admin.bimbel.payout_requests.unknown_tutor') }}
              </p>
              <p
                v-if="req.tutor?.email"
                class="text-[12px] text-tutoring-text-mid mt-0.5 truncate"
              >
                {{ req.tutor.email }}
              </p>
              <p class="text-[12px] text-tutoring-text-mid mt-1">
                {{ periodLabel(req) }}
              </p>
            </div>
            <div class="text-right">
              <span
                class="inline-flex items-center rounded-md px-2 py-0.5 text-2xs font-bold uppercase tracking-wide"
                :class="STATUS_BADGE_CLASS[req.status]"
              >
                {{ tabLabel(req.status) }}
              </span>
              <p class="text-[16px] font-bold text-tutoring-text-hi mt-1">
                {{ formatRupiah(req.amount_requested) }}
              </p>
              <p
                v-if="req.amount_computed && req.amount_computed !== req.amount_requested"
                class="text-2xs text-tutoring-text-mid"
              >
                {{ t('admin.bimbel.payout_requests.eligible_inline', {
                  amount: formatRupiah(req.amount_computed),
                }) }}
              </p>
            </div>
          </div>

          <!-- Bank + notes block -->
          <div
            v-if="req.bank_name || req.bank_account_number || req.notes"
            class="mt-3 rounded-lg bg-tutoring-bg border border-tutoring-border-soft p-3 text-[12px] text-tutoring-text-mid space-y-1"
          >
            <p v-if="req.bank_name || req.bank_account_number">
              <span class="font-bold text-tutoring-text-hi">{{ req.bank_name ?? '—' }}</span>
              <span v-if="req.bank_account_number" class="font-mono ml-2">{{ req.bank_account_number }}</span>
              <span v-if="req.bank_account_holder" class="ml-2">· {{ req.bank_account_holder }}</span>
            </p>
            <p v-if="req.notes" class="italic">"{{ req.notes }}"</p>
          </div>

          <!-- Status-specific meta -->
          <div class="mt-2 text-[11.5px] text-tutoring-text-lo space-y-0.5">
            <p v-if="req.status === 'PENDING'">
              {{ t('admin.bimbel.payout_requests.requested_at') }} {{ ts(req.requested_at) }}
            </p>
            <p v-else-if="req.status === 'APPROVED'">
              {{ t('admin.bimbel.payout_requests.approved_at') }} {{ ts(req.approved_at) }}
            </p>
            <p v-else-if="req.status === 'PAID'">
              {{ t('admin.bimbel.payout_requests.paid_at') }} {{ ts(req.paid_at) }}
              <span v-if="req.payment_notes"> · {{ req.payment_notes }}</span>
            </p>
            <p v-else-if="req.status === 'REJECTED'" class="text-tutoring-red">
              {{ t('admin.bimbel.payout_requests.rejected_at') }} {{ ts(req.rejected_at) }}
              <span v-if="req.reject_reason"> · {{ req.reject_reason }}</span>
            </p>
          </div>

          <!-- Per-row actions -->
          <div class="mt-3 flex flex-wrap gap-2 justify-end">
            <a
              v-if="req.status === 'PAID' && req.proof_file_url"
              :href="req.proof_file_url"
              target="_blank"
              rel="noopener"
              class="inline-flex items-center gap-1.5 rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-1.5 text-[13px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft"
            >
              <NavIcon name="book" :size="13" />
              {{ t('admin.bimbel.payout_requests.action_view_proof') }}
            </a>

            <button
              v-if="req.status === 'PENDING'"
              type="button"
              :disabled="busyRowId === req.id"
              class="rounded-lg bg-tutoring-accent hover:opacity-90 px-3 py-1.5 text-[13px] font-bold text-white disabled:opacity-50"
              @click="onApprove(req)"
            >
              {{ t('admin.bimbel.payout_requests.action_approve') }}
            </button>
            <button
              v-if="req.status === 'PENDING'"
              type="button"
              :disabled="busyRowId === req.id"
              class="rounded-lg border border-tutoring-red text-tutoring-red px-3 py-1.5 text-[13px] font-bold hover:bg-tutoring-red-dim disabled:opacity-50"
              @click="openReject(req)"
            >
              {{ t('admin.bimbel.payout_requests.action_reject') }}
            </button>
            <button
              v-if="req.status === 'APPROVED'"
              type="button"
              :disabled="busyRowId === req.id"
              class="rounded-lg bg-tutoring-accent hover:opacity-90 px-3 py-1.5 text-[13px] font-bold text-white disabled:opacity-50"
              @click="openMarkPaid(req)"
            >
              {{ t('admin.bimbel.payout_requests.action_mark_paid') }}
            </button>
            <button
              v-if="req.status === 'APPROVED' || req.status === 'PAID'"
              type="button"
              :disabled="busyRowId === req.id"
              class="rounded-lg border border-tutoring-border text-tutoring-text-mid px-3 py-1.5 text-[13px] font-bold hover:bg-tutoring-border-soft disabled:opacity-50"
              @click="onRollback(req)"
            >
              {{ t('admin.bimbel.payout_requests.action_rollback') }}
            </button>
          </div>
        </li>
      </ul>
    </div>

    <AdminMarkPaidDialog
      v-if="markPaidTarget"
      :request="markPaidTarget"
      @close="markPaidTarget = null"
      @done="onMarkPaidDone"
    />
    <AdminRejectDialog
      v-if="rejectTarget"
      :request="rejectTarget"
      @close="rejectTarget = null"
      @done="onRejectDone"
    />
  </div>
</template>
