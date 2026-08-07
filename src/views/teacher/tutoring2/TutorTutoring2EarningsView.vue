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
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { PayoutsService } from '@/services/tutoring2/payouts';
import type {
  PayoutRequest,
  PayoutRequestStatus,
  SelfPayoutSummary,
} from '@/types/tutoring2/payout';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t } = useI18n();

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
    </div>

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
                class="flex items-center justify-between rounded-lg border px-4 py-3"
              >
                <div>
                  <p class="text-sm font-medium tabular-nums">{{ formatIdr(req.amount) }}</p>
                  <p class="text-xs opacity-70">{{ formatMonthLabel(req.period_month) }}</p>
                </div>
                <StatusBadge :tone="requestTone(req.status)" :label="req.status" />
              </li>
            </ul>
          </section>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
