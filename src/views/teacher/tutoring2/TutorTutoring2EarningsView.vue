<!--
  TutorTutoring2EarningsView.vue — the logged-in tutor's own "Honor
  Saya" page (CLEAN-2 Phase 2 · greenfield replacement for the legacy
  `teacher/tutoring/TutorEarningsView.vue`).

  Route: /teacher/tutoring2/earnings
  Endpoints:
    GET /tutoring-v2/payouts/summary          — self-scoped aggregate
    GET /tutoring-v2/payouts/requests         — caller's own requests
    POST /tutoring-v2/payouts/requests        — file a withdrawal

  CONTRACT DIFFERENCES vs the legacy v1 view — read before touching:

  1. v1 `GET /tutoring/payouts/summary` accepted `?user_id=`, letting an
     admin read any tutor through the tutor-side path. v2 resolves the
     tutor from the auth context (`user_id` → `teachers.id`) and has NO
     such param. Admins use `/payouts/admin-summary` — that is what
     AdminTutoring2PayoutSummaryView already does. Do not add a tutor
     picker here.
  2. v1 exposed `GET /tutoring/payouts/summary/pdf`. v2 has no PDF
     route, so the legacy "Unduh PDF" button is deliberately NOT ported
     rather than shipped pointing at a dead URL. If the export is
     wanted back it needs a backend route first.
  3. A tutor with no `teachers` row on this tenant gets an empty
     payload, not a 404 — hence every summary field is optional and the
     view renders an explanatory empty state instead of zeroes, which
     would read as "you earned nothing" rather than "you're not set up".
  4. GET /tutoring-v2/payouts/requests/{id}  — one request in full.

  ── The withdrawal rows used to be dead ──

  "pada website role teacher di list honor kenapa di klik tidak
  memunculkan detail list yang di klik" — a tutor tapping a row in
  "Pengajuan pencairan terakhir" got nothing, because the row carried no
  handler at all. The whole file had exactly ONE `@click`: the
  "Ajukan pencairan" button.

  Nothing was missing server-side. `PayoutRequestController::show` has
  been live behind `GET /tutoring-v2/payouts/requests/{id}` all along and
  `PayoutsService.getRequest` already wraps it — the admin queue is what
  never needed it (it expands the row it already holds). The rows are now
  buttons that open a read-only detail sheet, matching the sheet idiom
  the admin tutoring2 screens use (`<Modal>` + status pill + label/value
  rows; see AdminTutoring2LeadsView's detail sheet).

  ── Two rules this sheet is bound by ──

  a. ABILITY. `show` does not `authorize()` a fixed key; it runs the same
     `resolveReadScope` as `index`: `tutoring.payout.view_all` reads any
     row, `tutoring.payout.view_own` reads only the caller's, anything
     else is a 403. So the control is gated on holding EITHER, read off
     the /me snapshot (scoped by `X-Active-Role`) via `useMe().canAny` —
     never `roles[].permission_keys`, which is unscoped and exists only
     for the role switcher.
  b. HONEST BLANKS. `PayoutRequestResource` emits `approved_at`,
     `rejected_at`, `paid_at`, `note`, `payment_reference` and the
     `whenLoaded` `reviewer_name` as null-or-omitted. A key that is not
     sent means "did not happen", not "zero" — every optional row renders
     an em-dash rather than a fabricated value (the !849/!850/!1236
     conflation).
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import TutorTutoring2WithdrawalDialog from '@/components/tutoring2/TutorTutoring2WithdrawalDialog.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { PayoutsService } from '@/services/tutoring2/payouts';
import type {
  PayoutRequest,
  PayoutRequestStatus,
  SelfPayoutSummary,
} from '@/types/tutoring2/payout';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();
const { canAny } = useMe();

/**
 * Either key gets a row read: `view_all` for an admin who also holds a
 * tutor profile, `view_own` for the ordinary tutor. Mirrors
 * `PayoutRequestController::resolveReadScope` exactly — offering the
 * sheet to anyone else would be a guaranteed 403.
 */
const canViewRequestDetail = computed(() =>
  canAny(['tutoring.payout.view_own', 'tutoring.payout.view_all']),
);

/**
 * Selected period. Defaults to the current month in LOCAL time — not
 * `toISOString().slice(0,7)`, which is UTC and rolls a WIB user back
 * into the previous month for the first 7 hours of every 1st.
 */
function currentLocalMonth(): string {
  const d = new Date();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  return `${d.getFullYear()}-${mm}`;
}

const month = ref<string>(currentLocalMonth());

const { state, reload } = useDataRefresh(async () => {
  const [summary, requests] = await Promise.all([
    PayoutsService.getSelfSummary({ month: month.value }),
    PayoutsService.listMyRequests({ per_page: 5 }),
  ]);
  return { summary, requests: requests.items };
});

// Re-fetch when the tutor picks a different month.
watch(month, () => {
  void reload();
});

const payload = computed<{ summary: SelfPayoutSummary; requests: PayoutRequest[] } | null>(() => {
  return state.value.status === 'content' || state.value.status === 'empty'
    ? ((state.value.data as { summary: SelfPayoutSummary; requests: PayoutRequest[] } | undefined) ??
        null)
    : null;
});

const summary = computed<SelfPayoutSummary | null>(() => payload.value?.summary ?? null);
const requests = computed<PayoutRequest[]>(() => payload.value?.requests ?? []);

/** A tutor with no `teachers` row gets a payload with no tutor_id. */
const isOnboarded = computed(() => Boolean(summary.value?.tutor_id));

const kpis = computed(() => [
  {
    key: 'net',
    label: t('tutoring2.tutor.earnings.kpiNet'),
    value: formatIdr(summary.value?.net_amount),
  },
  {
    key: 'base',
    label: t('tutoring2.tutor.earnings.kpiBase'),
    value: formatIdr(summary.value?.base_amount),
  },
  {
    key: 'adjustments',
    label: t('tutoring2.tutor.earnings.kpiAdjustments'),
    value: formatIdr(summary.value?.adjustments),
  },
  {
    key: 'sessions',
    label: t('tutoring2.tutor.earnings.kpiSessions'),
    value: String(summary.value?.sessions_taught ?? 0),
  },
]);

function formatIdr(amount?: number | null): string {
  if (amount == null) return '—';
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(amount);
}

function formatMonthLabel(ym: string): string {
  const [y, m] = ym.split('-');
  if (!y || !m) return ym;
  // Day 1 in LOCAL time — `new Date('2026-08')` parses as UTC and can
  // render the previous month for negative-offset locales.
  const d = new Date(Number(y), Number(m) - 1, 1);
  return d.toLocaleDateString('id-ID', { month: 'long', year: 'numeric' });
}

/**
 * Withdrawal dialog (CLEAN-2 P2). Mounted only while open so its
 * settings + summary fetches don't run on every earnings page view.
 * On success we reload so the new pending request appears in the list.
 */
const withdrawalOpen = ref(false);

function onWithdrawalSubmitted() {
  void reload();
}

/**
 * Status → tone. Kept byte-identical to `statusTone` in
 * AdminTutoring2PayoutRequestsView so the same request reads the same
 * colour whether a tutor or an admin is looking at it. If you change
 * one, change both.
 */
function requestTone(status: PayoutRequestStatus): StatusBadgeTone {
  switch (status) {
    case 'pending':
      return 'warning';
    case 'approved':
      return 'info';
    case 'paid':
      return 'success';
    case 'rejected':
      return 'danger';
    case 'rolled_back':
      return 'neutral';
  }
}

/**
 * Human status. The list used to print `req.status` raw, so an
 * Indonesian tutor read "pending" / "rolled_back" — the wire enum. The
 * five values are pinned to the same copy the admin queue shows by
 * `TutorTutoring2EarningsView.detail.spec.ts`, so one side cannot drift.
 */
function requestStatusLabel(status: PayoutRequestStatus): string {
  return t(`tutoring2.tutor.earnings.status.${status}`);
}

// ─── Detail sheet ───────────────────────────────────────────────────

/**
 * The row that was tapped. Seeded from the list row so the sheet paints
 * instantly, then replaced by the `show` payload — same "open, then
 * refresh from server truth" shape AdminTutoring2LeadsView.openDetail
 * uses. A failed refetch is non-fatal: the list row is already correct
 * for the fields it carries, and blanking the sheet would be worse.
 */
const activeRequest = ref<PayoutRequest | null>(null);
const detailOpen = ref(false);
const detailLoading = ref(false);

async function openRequestDetail(row: PayoutRequest) {
  // Belt-and-braces beside the template's `v-if`: the sheet must not be
  // reachable for a caller the endpoint would refuse.
  if (!canViewRequestDetail.value) return;

  activeRequest.value = row;
  detailOpen.value = true;
  detailLoading.value = true;
  try {
    activeRequest.value = await PayoutsService.getRequest(row.id);
  } catch {
    // Keep the list row on screen rather than emptying the sheet.
  } finally {
    detailLoading.value = false;
  }
}

function closeRequestDetail() {
  detailOpen.value = false;
  activeRequest.value = null;
}

/** Em-dash for anything the wire did not send. Never `0`, never a guess. */
function orDash(value: string | null | undefined): string {
  return value != null && value !== '' ? value : '—';
}

/**
 * Timestamps carry a time-of-day, so they are rendered with one. Always
 * via `toLocaleString` in the viewer's zone — never
 * `toISOString().slice(...)`, which is UTC and shows a WIB tutor the
 * previous day for anything stamped before 07:00.
 */
function formatIsoDateTime(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString('id-ID', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

interface DetailRow {
  key: string;
  label: string;
  value: string;
}

/**
 * The timeline half. Every stage is listed whether or not it happened —
 * "Ditolak —" is the honest reading of an omitted `rejected_at`, and
 * hiding the row would make a pending request look identical to one
 * whose rejection simply was not sent.
 */
const detailTimelineRows = computed<DetailRow[]>(() => {
  const r = activeRequest.value;
  if (!r) return [];
  return [
    {
      key: 'requested_at',
      label: t('tutoring2.tutor.earnings.requestedAt'),
      value: formatIsoDateTime(r.requested_at),
    },
    {
      key: 'approved_at',
      label: t('tutoring2.tutor.earnings.approvedAt'),
      value: formatIsoDateTime(r.approved_at),
    },
    {
      key: 'rejected_at',
      label: t('tutoring2.tutor.earnings.rejectedAt'),
      value: formatIsoDateTime(r.rejected_at),
    },
    {
      key: 'paid_at',
      label: t('tutoring2.tutor.earnings.paidAt'),
      value: formatIsoDateTime(r.paid_at),
    },
    {
      key: 'reviewer',
      label: t('tutoring2.tutor.earnings.reviewer'),
      // `reviewer_name` only, never `reviewer_id`: a UUID on screen is
      // not an answer to "who approved my honor". It arrives via
      // `whenLoaded('reviewer')`, which `show` does eager-load.
      value: orDash(r.reviewer_name),
    },
  ];
});

/** The non-timeline half: what the admin typed, if anything. */
const detailNoteRows = computed<DetailRow[]>(() => {
  const r = activeRequest.value;
  if (!r) return [];
  return [
    {
      key: 'payment_reference',
      label: t('tutoring2.tutor.earnings.paymentReference'),
      value: orDash(r.payment_reference),
    },
    {
      key: 'note',
      label: t('tutoring2.common.notes'),
      value: orDash(r.note),
    },
  ];
});
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      :kicker="t('tutoring2.common.roleTutor')"
      :title="t('tutoring2.tutor.earnings.title')"
      :meta="
        state.status === 'loading'
          ? t('tutoring2.common.loading')
          : formatMonthLabel(month)
      "
    />

    <div class="flex items-center gap-2">
      <label class="text-sm font-medium" for="earnings-month">
        {{ t('tutoring2.tutor.earnings.monthLabel') }}
      </label>
      <input
        id="earnings-month"
        v-model="month"
        type="month"
        class="rounded-md border px-3 py-1.5 text-sm"
      />
      <button
        v-if="isOnboarded"
        type="button"
        class="ml-auto rounded-lg bg-brand-cobalt px-3 py-1.5 text-sm font-semibold text-white hover:opacity-90"
        @click="withdrawalOpen = true"
      >
        {{ t('tutoring2.tutor.withdrawal.openCta') }}
      </button>
    </div>

    <TutorTutoring2WithdrawalDialog
      v-if="withdrawalOpen"
      :initial-month="month"
      :initial-eligible="summary?.net_amount"
      @close="withdrawalOpen = false"
      @submitted="onWithdrawalSubmitted"
    />

    <AsyncView :state="state" @retry="reload">
      <template #default>
        <div v-if="!isOnboarded" class="rounded-lg border p-6 text-center">
          <p class="text-sm">{{ t('tutoring2.tutor.earnings.notOnboarded') }}</p>
        </div>

        <template v-else>
          <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
            <div v-for="kpi in kpis" :key="kpi.key" class="rounded-lg border p-4">
              <p class="text-xs uppercase tracking-wide opacity-70">{{ kpi.label }}</p>
              <p class="mt-1 text-lg font-bold tabular-nums">{{ kpi.value }}</p>
            </div>
          </div>

          <section class="mt-6">
            <h2 class="mb-2 text-sm font-semibold">
              {{ t('tutoring2.tutor.earnings.requestsTitle') }}
            </h2>

            <p v-if="requests.length === 0" class="text-sm opacity-70">
              {{ t('tutoring2.tutor.earnings.requestsEmpty') }}
            </p>

            <ul v-else class="space-y-2">
              <li
                v-for="req in requests"
                :key="req.id"
                data-testid="earnings-request-item"
                class="rounded-lg border"
              >
                <!-- A real <button> when the caller may read the row,
                     a plain <div> otherwise: no dead affordance, and no
                     keyboard focus stop on something that does nothing. -->
                <button
                  v-if="canViewRequestDetail"
                  type="button"
                  data-testid="earnings-request-row"
                  class="flex w-full items-center justify-between gap-3 px-4 py-3 text-left hover:bg-slate-50"
                  @click="openRequestDetail(req)"
                >
                  <span class="block">
                    <span class="block text-sm font-medium tabular-nums">
                      {{ formatIdr(req.amount) }}
                    </span>
                    <span class="block text-xs opacity-70">
                      {{ formatMonthLabel(req.period_month) }}
                    </span>
                  </span>
                  <span class="flex items-center gap-2">
                    <StatusBadge
                      :tone="requestTone(req.status)"
                      :label="requestStatusLabel(req.status)"
                    />
                    <span class="text-xs font-semibold text-brand-cobalt">
                      {{ t('tutoring2.common.detail') }}
                    </span>
                  </span>
                </button>
                <div v-else class="flex items-center justify-between gap-3 px-4 py-3">
                  <div>
                    <p class="text-sm font-medium tabular-nums">{{ formatIdr(req.amount) }}</p>
                    <p class="text-xs opacity-70">{{ formatMonthLabel(req.period_month) }}</p>
                  </div>
                  <StatusBadge
                    :tone="requestTone(req.status)"
                    :label="requestStatusLabel(req.status)"
                  />
                </div>
              </li>
            </ul>
          </section>
        </template>
      </template>
    </AsyncView>

    <!-- Read-only detail sheet. Same <Modal> idiom as the admin
         tutoring2 detail sheets; no actions, because every payout write
         is an admin ability the tutor does not hold. -->
    <Modal
      v-if="detailOpen && activeRequest"
      testid="payout-request-detail"
      :title="t('tutoring2.tutor.earnings.detailTitle')"
      :subtitle="formatMonthLabel(activeRequest.period_month)"
      size="md"
      @close="closeRequestDetail"
    >
      <div class="space-y-4">
        <div class="flex items-center justify-between gap-3 rounded-2xl bg-slate-50 p-4">
          <div>
            <p class="text-xs text-slate-500">{{ t('tutoring2.common.amount') }}</p>
            <p data-testid="payout-detail-amount" class="text-lg font-bold tabular-nums">
              {{ formatIdr(activeRequest.amount) }}
            </p>
          </div>
          <StatusBadge
            :tone="requestTone(activeRequest.status)"
            :label="requestStatusLabel(activeRequest.status)"
            uppercase
          />
        </div>

        <section class="space-y-2">
          <h3 class="px-1 text-2xs font-bold uppercase tracking-widest text-slate-400">
            {{ t('tutoring2.tutor.earnings.timeline') }}
          </h3>
          <div class="divide-y divide-slate-100 rounded-2xl border border-slate-200">
            <div
              v-for="row in detailTimelineRows"
              :key="row.key"
              :data-testid="`payout-detail-${row.key}`"
              class="flex items-start justify-between gap-3 px-3 py-2.5"
            >
              <span class="flex-shrink-0 text-xs text-slate-500">{{ row.label }}</span>
              <span class="min-w-0 flex-1 break-words text-right text-xs font-bold text-slate-900">
                {{ row.value }}
              </span>
            </div>
          </div>
        </section>

        <section class="space-y-2">
          <h3 class="px-1 text-2xs font-bold uppercase tracking-widest text-slate-400">
            {{ t('tutoring2.tutor.earnings.details') }}
          </h3>
          <div class="divide-y divide-slate-100 rounded-2xl border border-slate-200">
            <div
              v-for="row in detailNoteRows"
              :key="row.key"
              :data-testid="`payout-detail-${row.key}`"
              class="flex items-start justify-between gap-3 px-3 py-2.5"
            >
              <span class="flex-shrink-0 text-xs text-slate-500">{{ row.label }}</span>
              <span class="min-w-0 flex-1 break-words text-right text-xs font-bold text-slate-900">
                {{ row.value }}
              </span>
            </div>
          </div>
        </section>

        <p v-if="detailLoading" data-testid="payout-detail-loading" class="text-xs text-slate-400">
          {{ t('tutoring2.common.loading') }}
        </p>

        <Button variant="secondary" block @click="closeRequestDetail">
          {{ t('tutoring2.tutor.earnings.close') }}
        </Button>
      </div>
    </Modal>
  </div>
</template>
