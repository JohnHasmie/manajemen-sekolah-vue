<!--
  AdminTutoring2PayoutRequestsView.vue — WEB-16 (BE-25 requests).

  Admin queue for self-service tutor payout requests. Every row has a
  status-dependent action set:
    pending  → Approve · Reject
    approved → Mark Paid · Rollback (back to pending)
    paid     → Rollback (back to approved)
    rejected → (read-only; reason shown inline)

  Reject requires a >= 3-char reason (RejectPayoutRequestRequest).
  Mark-paid takes an OPTIONAL payment_reference — omit for cash /
  imprest tenants. Rollback needs no payload; the backend decides which
  state to fall back to.

  Reads gate on `tutoring.payout.view_all`; each write button gates on
  its own ability (approve/reject/mark_paid/rollback) so a per-role FE
  hides affordances the caller can't fire even if the controller would
  403 them anyway.

  ── The Tutor filter ──

  The Tutor chip now opens a <FilterFacetPickerModal>, the same per-facet
  picker the Manajemen Data screens use. Its handler was
  `@click="tutorFilter = ''"`, which only ever CLEARS, and the chip
  displayed `truncateId(tutorFilter)` — an id fragment.

  The one path that could actually set it was a raw text box in the
  "advanced" row below, asking an admin to paste a tutor UUID — and that
  row was `v-if="statusFilter || tutorFilter"`, so it only appeared AFTER
  you had toggled the Status chip. Filtering by tutor therefore meant:
  toggle an unrelated filter, then hand-type a UUID. That box is gone;
  the chip does the job by name. Part of the "semua button/filter tdk
  berfungsi" report a bimbel admin filed on prod.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import FilterFacetPickerModal, {
  type FacetOption,
} from '@/components/feature/FilterFacetPickerModal.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import FormField from '@/components/ui/FormField.vue';
import FormSheet from '@/components/ui/FormSheet.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { toLocalYm } from '@/lib/local-date';
import { PayoutsService } from '@/services/tutoring2/payouts';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { StatusBadgeTone } from '@/types/status-badge';
import type { PayoutRequest, PayoutRequestStatus } from '@/types/tutoring2/payout';
import { PAYOUT_REQUEST_STATUSES } from '@/types/tutoring2/payout';
import type { Tutor } from '@/types/tutoring2/tutor';

const { t } = useI18n();
const toast = useToast();
const { can } = useMe();

const canApprove = computed(() => can('tutoring.payout.approve'));
const canReject = computed(() => can('tutoring.payout.reject'));
const canMarkPaid = computed(() => can('tutoring.payout.mark_paid'));
const canRollback = computed(() => can('tutoring.payout.rollback'));

// ─── Filters ────────────────────────────────────────────────────────

const search = ref('');
const statusFilter = ref<string>(''); // '' | PayoutRequestStatus
const monthFilter = ref<string>(''); // '' | YYYY-MM
const tutorFilter = ref<string>('');

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await PayoutsService.listRequests({
    per_page: 100,
    status: (statusFilter.value || undefined) as PayoutRequestStatus | undefined,
    month: monthFilter.value || undefined,
    tutor_id: tutorFilter.value || undefined,
  });
  return items;
});
watch([statusFilter, monthFilter, tutorFilter], () => reload());
useAcademicYearWatcher(reload);

// ── Tutor facet option list ────────────────────────────────────────
// The chip filters on a tutor id, so it needs the id→name list its
// picker renders. Status and Period are enum/date toggles: no fetch.
const tutors = ref<Tutor[]>([]);
const showTutorPicker = ref(false);

// `tu`, not `t` — the i18n `t` is in scope and must not be shadowed.
const tutorOptions = computed<FacetOption[]>(() =>
  tutors.value.map((tu) => ({ key: tu.id, label: tu.name })),
);

/**
 * Load the option list once, tolerantly: a failing or ability-gated
 * endpoint must leave the chip disabled with a hover reason rather than
 * opening a picker with nothing to pick. This screen gates on
 * `tutoring.payout.view_all` while the tutor list gates on its own
 * ability, so the two really can diverge.
 */
async function loadFacetOptions() {
  const [tutorRes] = await Promise.allSettled([
    TutoringTutorsService.list({ per_page: 200 }),
  ]);
  if (tutorRes.status === 'fulfilled') tutors.value = tutorRes.value.items;
}

onMounted(loadFacetOptions);

const filteredRequests = computed<PayoutRequest[]>(() => {
  const rows = state.value.status === 'content' ? (state.value.data as PayoutRequest[]) : [];
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return rows;
  return rows.filter((r) => (r.tutor_name ?? r.tutor_id).toLowerCase().includes(q));
});

// ─── KPI (client-side over the current page) ────────────────────────

const kpiCards = computed<KpiCard[]>(() => {
  const rows = filteredRequests.value;
  const nowMonth = toLocalYm();
  const pending = rows.filter((r) => r.status === 'pending').length;
  const approved = rows.filter((r) => r.status === 'approved').length;
  const paidThis = rows
    .filter((r) => r.status === 'paid' && r.period_month === nowMonth)
    .reduce((s, r) => s + r.amount, 0);
  const rejected = rows.filter((r) => r.status === 'rejected').length;
  return [
    { icon: 'clock', label: t('tutoring2.admin.payoutRequests.kpiPending'), value: String(pending), tone: pending > 0 ? 'amber' : undefined },
    { icon: 'circle-check', label: t('tutoring2.admin.payoutRequests.kpiApproved'), value: String(approved), tone: approved > 0 ? 'green' : undefined },
    { icon: 'wallet', label: t('tutoring2.admin.payoutRequests.kpiPaidMonth'), value: `Rp ${paidThis.toLocaleString('id-ID')}` },
    { icon: 'x-circle', label: t('tutoring2.admin.payoutRequests.kpiRejected'), value: String(rejected), tone: rejected > 0 ? 'red' : undefined },
  ];
});

// ─── Expand + action state ──────────────────────────────────────────

const expandedId = ref<string | null>(null);
function toggleExpand(id: string) {
  expandedId.value = expandedId.value === id ? null : id;
}

const busyId = ref<string | null>(null);

async function approve(row: PayoutRequest) {
  busyId.value = row.id;
  try {
    await PayoutsService.approveRequest(row.id);
    toast.success(t('tutoring2.admin.payoutRequests.approved'));
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.actionFailed'));
  } finally {
    busyId.value = null;
  }
}

async function rollback(row: PayoutRequest) {
  busyId.value = row.id;
  try {
    await PayoutsService.rollbackRequest(row.id);
    toast.success(t('tutoring2.admin.payoutRequests.rolledBack'));
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.actionFailed'));
  } finally {
    busyId.value = null;
  }
}

// ─── Reject dialog ──────────────────────────────────────────────────

const rejectTarget = ref<PayoutRequest | null>(null);
const rejectReason = ref('');
const isRejecting = ref(false);

async function submitReject() {
  if (!rejectTarget.value) return;
  const reason = rejectReason.value.trim();
  if (reason.length < 3) {
    toast.error(t('tutoring2.admin.payoutRequests.errReasonMin'));
    return;
  }
  isRejecting.value = true;
  try {
    await PayoutsService.rejectRequest(rejectTarget.value.id, { reason });
    toast.success(t('tutoring2.admin.payoutRequests.rejected'));
    rejectTarget.value = null;
    rejectReason.value = '';
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.actionFailed'));
  } finally {
    isRejecting.value = false;
  }
}

// ─── Mark-paid dialog ───────────────────────────────────────────────

const paidTarget = ref<PayoutRequest | null>(null);
const paymentReference = ref('');
const isMarkingPaid = ref(false);

async function submitMarkPaid() {
  if (!paidTarget.value) return;
  isMarkingPaid.value = true;
  try {
    const ref_ = paymentReference.value.trim();
    await PayoutsService.markRequestPaid(paidTarget.value.id, {
      payment_reference: ref_ ? ref_ : undefined,
    });
    toast.success(t('tutoring2.admin.payoutRequests.markedPaid'));
    paidTarget.value = null;
    paymentReference.value = '';
    await reload();
  } catch (e) {
    toast.error(extractError(e) ?? t('tutoring2.common.actionFailed'));
  } finally {
    isMarkingPaid.value = false;
  }
}

// ─── Helpers ────────────────────────────────────────────────────────

function extractError(e: unknown): string | null {
  const err = e as { response?: { data?: { message?: string; errors?: Record<string, string[]> } } };
  const msg = err?.response?.data?.message;
  if (msg) return msg;
  const errors = err?.response?.data?.errors;
  if (errors) {
    const first = Object.values(errors)[0];
    if (Array.isArray(first) && first.length > 0) return first[0];
  }
  return null;
}

function truncateId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

/**
 * What the Tutor chip reads: the picked tutor's NAME, or "Semua" when
 * unset.
 *
 * Falls back to `truncateId` only when the id is genuinely not in the
 * loaded list (options still in flight, or the tutor was deactivated
 * after requesting). An id fragment is ugly but honest there — "—" on a
 * chip rendered ACTIVE would read as "no filter applied", which is the
 * failure this screen just came out of.
 */
function chipValue(id: string, options: FacetOption[]): string {
  if (!id) return t('tutoring2.common.all');
  return options.find((o) => o.key === id)?.label ?? truncateId(id);
}

function statusLabel(s: PayoutRequestStatus): string {
  return t(`tutoring2.admin.payoutRequests.status.${s}`);
}

function statusTone(s: PayoutRequestStatus): StatusBadgeTone {
  switch (s) {
    case 'pending': return 'warning';
    case 'approved': return 'info';
    case 'paid': return 'success';
    case 'rejected': return 'danger';
    case 'rolled_back': return 'neutral';
  }
}

function formatIsoDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' });
}

const statusOptions = PAYOUT_REQUEST_STATUSES.map((s) => ({ value: s, label: statusLabel(s) }));
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.payoutRequests.title')"
      :meta="state.status === 'content' ? t('tutoring2.admin.payoutRequests.meta', { count: filteredRequests.length }) : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.payoutRequests.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="statusFilter ? statusLabel(statusFilter as PayoutRequestStatus) : t('tutoring2.common.all')"
          icon-name="circle-check"
          :active="!!statusFilter"
          @click="statusFilter = statusFilter ? '' : 'pending'"
        />
        <AppFilterChip
          :label="t('tutoring2.common.period')"
          :value="monthFilter || t('tutoring2.common.all')"
          icon-name="calendar"
          :active="!!monthFilter"
          @click="monthFilter = monthFilter ? '' : toLocalYm()"
        />
        <AppFilterChip
          :label="t('tutoring2.common.tutor')"
          :value="chipValue(tutorFilter, tutorOptions)"
          icon-name="user"
          :active="!!tutorFilter"
          :disabled="tutorOptions.length === 0"
          :title="tutorOptions.length === 0 ? t('tutoring2.common.filterNoOptions') : undefined"
          @click="showTutorPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- Advanced status row. The Status chip is a two-value toggle
         (Semua ⇄ pending); this select is how an admin reaches the other
         four states, so it stays. The tutor UUID box that used to sit
         beside it is gone — the Tutor chip picks by name now. -->
    <div v-if="statusFilter" class="flex flex-wrap gap-2 text-2xs">
      <label class="flex items-center gap-2">
        <span class="text-slate-500">{{ t('tutoring2.common.status') }}:</span>
        <select v-model="statusFilter" class="rounded-lg border border-slate-200 px-2 py-1 text-2xs">
          <option value="">{{ t('tutoring2.common.all') }}</option>
          <option v-for="opt in statusOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
      </label>
    </div>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.payoutRequests.emptyTitle')"
      :empty-description="t('tutoring2.admin.payoutRequests.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.tutor') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.period') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.amount') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.payoutRequests.requestedAt') }}</th>
                <th class="px-4 py-3 font-bold text-right">{{ t('tutoring2.common.actions') }}</th>
              </tr>
            </thead>
            <tbody>
              <template v-for="r in filteredRequests" :key="r.id">
                <tr
                  class="border-b border-slate-100 hover:bg-slate-50 cursor-pointer"
                  @click="toggleExpand(r.id)"
                >
                  <td class="px-4 py-3 font-semibold text-slate-900">{{ r.tutor_name ?? truncateId(r.tutor_id) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ r.period_month }}</td>
                  <td class="px-4 py-3 font-semibold text-slate-900">Rp {{ r.amount.toLocaleString('id-ID') }}</td>
                  <td class="px-4 py-3">
                    <StatusBadge :label="statusLabel(r.status)" :tone="statusTone(r.status)" uppercase />
                  </td>
                  <td class="px-4 py-3 text-slate-600">{{ formatIsoDate(r.requested_at) }}</td>
                  <td class="px-4 py-3 text-right" @click.stop>
                    <div class="inline-flex flex-wrap justify-end gap-2">
                      <template v-if="r.status === 'pending'">
                        <Button
                          v-if="canApprove"
                          variant="primary"
                          size="sm"
                          :loading="busyId === r.id"
                          @click="approve(r)"
                        >{{ t('tutoring2.admin.payoutRequests.approve') }}</Button>
                        <Button
                          v-if="canReject"
                          variant="secondary"
                          size="sm"
                          @click="rejectTarget = r; rejectReason = ''"
                        >{{ t('tutoring2.admin.payoutRequests.reject') }}</Button>
                      </template>
                      <template v-else-if="r.status === 'approved'">
                        <Button
                          v-if="canMarkPaid"
                          variant="primary"
                          size="sm"
                          @click="paidTarget = r; paymentReference = ''"
                        >{{ t('tutoring2.admin.payoutRequests.markPaid') }}</Button>
                        <Button
                          v-if="canRollback"
                          variant="ghost"
                          size="sm"
                          :loading="busyId === r.id"
                          @click="rollback(r)"
                        >{{ t('tutoring2.admin.payoutRequests.rollback') }}</Button>
                      </template>
                      <template v-else-if="r.status === 'paid'">
                        <Button
                          v-if="canRollback"
                          variant="ghost"
                          size="sm"
                          :loading="busyId === r.id"
                          @click="rollback(r)"
                        >{{ t('tutoring2.admin.payoutRequests.rollback') }}</Button>
                      </template>
                    </div>
                  </td>
                </tr>
                <tr v-if="expandedId === r.id" class="bg-slate-50/60 border-b border-slate-100">
                  <td colspan="6" class="px-4 py-4">
                    <div class="grid gap-3 md:grid-cols-2">
                      <div>
                        <p class="text-2xs uppercase tracking-wide text-slate-400 font-bold mb-1">
                          {{ t('tutoring2.admin.payoutRequests.timeline') }}
                        </p>
                        <ul class="space-y-1 text-xs text-slate-600">
                          <li>{{ t('tutoring2.admin.payoutRequests.requestedAt') }}: {{ formatIsoDate(r.requested_at) }}</li>
                          <li v-if="r.approved_at">{{ t('tutoring2.admin.payoutRequests.approvedAt') }}: {{ formatIsoDate(r.approved_at) }}</li>
                          <li v-if="r.rejected_at">{{ t('tutoring2.admin.payoutRequests.rejectedAt') }}: {{ formatIsoDate(r.rejected_at) }}</li>
                          <li v-if="r.paid_at">{{ t('tutoring2.admin.payoutRequests.paidAt') }}: {{ formatIsoDate(r.paid_at) }}</li>
                          <li v-if="r.reviewer_name">{{ t('tutoring2.admin.payoutRequests.reviewer') }}: {{ r.reviewer_name }}</li>
                        </ul>
                      </div>
                      <div>
                        <p class="text-2xs uppercase tracking-wide text-slate-400 font-bold mb-1">
                          {{ t('tutoring2.admin.payoutRequests.details') }}
                        </p>
                        <ul class="space-y-1 text-xs text-slate-600">
                          <li v-if="r.payment_reference">{{ t('tutoring2.admin.payoutRequests.paymentReference') }}: {{ r.payment_reference }}</li>
                          <li v-if="r.note && r.status === 'rejected'" class="text-red-700">
                            {{ t('tutoring2.admin.payoutRequests.rejectReason') }}: {{ r.note }}
                          </li>
                          <li v-else-if="r.note">{{ t('tutoring2.common.notes') }}: {{ r.note }}</li>
                        </ul>
                      </div>
                    </div>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <!-- Reject dialog: reason required (min 3 chars). -->
    <FormSheet
      v-if="rejectTarget"
      :title="t('tutoring2.admin.payoutRequests.rejectTitle')"
      :subtitle="t('tutoring2.admin.payoutRequests.rejectSubtitle', { name: rejectTarget.tutor_name ?? truncateId(rejectTarget.tutor_id) })"
      :saving="isRejecting"
      :save-label="t('tutoring2.admin.payoutRequests.reject')"
      @save="submitReject"
      @cancel="rejectTarget = null"
      @close="rejectTarget = null"
    >
      <FormField
        v-model="rejectReason"
        :label="t('tutoring2.admin.payoutRequests.reasonLabel')"
        type="textarea"
        required
        :rows="3"
        :placeholder="t('tutoring2.admin.payoutRequests.reasonPh')"
      />
      <p class="text-2xs text-slate-500 mt-1">{{ t('tutoring2.admin.payoutRequests.reasonHint') }}</p>
    </FormSheet>

    <!-- Mark-paid dialog: optional payment_reference. -->
    <FormSheet
      v-if="paidTarget"
      :title="t('tutoring2.admin.payoutRequests.markPaidTitle')"
      :subtitle="t('tutoring2.admin.payoutRequests.markPaidSubtitle', { name: paidTarget.tutor_name ?? truncateId(paidTarget.tutor_id) })"
      :saving="isMarkingPaid"
      :save-label="t('tutoring2.admin.payoutRequests.markPaid')"
      @save="submitMarkPaid"
      @cancel="paidTarget = null"
      @close="paidTarget = null"
    >
      <FormField
        v-model="paymentReference"
        :label="t('tutoring2.admin.payoutRequests.paymentReference') + ' (' + t('tutoring2.common.optional') + ')'"
        type="text"
        :placeholder="t('tutoring2.admin.payoutRequests.paymentReferencePh')"
      />
      <p class="text-2xs text-slate-500 mt-1">{{ t('tutoring2.admin.payoutRequests.markPaidHint') }}</p>
    </FormSheet>

    <!-- Per-facet picker. It writes its ref; the existing watcher on
         [status, month, tutor] does the reload, so nothing calls it
         here. -->
    <FilterFacetPickerModal
      v-if="showTutorPicker"
      :title="t('tutoring2.common.tutor')"
      :options="tutorOptions"
      :selected="tutorFilter"
      :all-label="t('tutoring2.common.all')"
      @close="showTutorPicker = false"
      @apply="(v) => { tutorFilter = v; }"
    />
  </div>
</template>
