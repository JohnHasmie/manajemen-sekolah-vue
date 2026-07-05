<!--
  TutorEarningsView — tutor's "Earnings Saya" page.

  Loads GET /tutoring/payouts/summary for the calling user with
  optional ?month=YYYY-MM. Displays KPI strip (earnings/session/jam/rate)
  + month picker.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type {
  TutorPayoutRequest,
  TutorPayoutRequestStatus,
  TutorPayoutSummary,
  TutoringSession,
} from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import TutorWithdrawalDialog from '@/components/tutoring/TutorWithdrawalDialog.vue';

const { t } = useI18n();
const toast = useToast();
const auth = useAuthStore();

const loading = ref(true);
const summary = ref<TutorPayoutSummary | null>(null);
const sessions = ref<TutoringSession[]>([]);
const month = ref<string>(''); // YYYY-MM; '' = current

// ── Withdrawal flow state ────────────────────────────────────────
const showWithdrawalDialog = ref(false);
const withdrawalLoading = ref(false);
const withdrawalRequests = ref<TutorPayoutRequest[]>([]);

const STATUS_BADGE_CLASS: Record<TutorPayoutRequestStatus, string> = {
  // Mirror TutoringStatusPill's tone tokens — *-dim backgrounds + the
  // matching colored text. All four read on both light + dark surfaces
  // because the underlying CSS vars are theme-aware.
  PENDING: 'bg-tutoring-amber-dim text-tutoring-amber',
  APPROVED: 'bg-tutoring-accent-dim text-tutoring-accent',
  PAID: 'bg-tutoring-green-dim text-tutoring-green',
  REJECTED: 'bg-tutoring-red-dim text-tutoring-red',
};

// Payslip PDF URL — same query the page is currently viewing.
// Browser opens / downloads via the <a> in the header.
const payslipUrl = computed(() => {
  const base = '/api/tutoring/payouts/summary/pdf';
  return month.value ? `${base}?month=${month.value}` : base;
});

// Resolve the period window we're showing — for month='' use the
// current calendar month, otherwise the picked YYYY-MM.
function periodRange(): { from: Date; to: Date } {
  const now = new Date();
  let y: number, m: number;
  if (month.value) {
    [y, m] = month.value.split('-').map(Number);
    m -= 1;
  } else {
    y = now.getFullYear();
    m = now.getMonth();
  }
  return { from: new Date(y, m, 1), to: new Date(y, m + 1, 0, 23, 59, 59) };
}

async function load() {
  loading.value = true;
  try {
    const tutorId = String(auth.user?.id ?? '');
    const { from, to } = periodRange();
    const [s, ss] = await Promise.all([
      TutoringService.getPayoutSummary({
        month: month.value || undefined,
      }),
      tutorId
        ? TutoringService.getTutorSessions(tutorId, from, to).catch(
            () => [] as TutoringSession[],
          )
        : Promise.resolve([] as TutoringSession[]),
    ]);
    summary.value = s;
    sessions.value = ss;
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutor.bimbel.earnings.load_failed'));
  } finally {
    loading.value = false;
  }
  // Withdrawal history loads independently — a 4xx here mustn't block
  // the main earnings strip from rendering.
  loadWithdrawals();
}
onMounted(load);
watch(month, load);

async function loadWithdrawals() {
  withdrawalLoading.value = true;
  try {
    const res = await TutoringService.listMyPayoutRequests({ per_page: 5 });
    withdrawalRequests.value = res.items;
  } catch {
    withdrawalRequests.value = [];
  } finally {
    withdrawalLoading.value = false;
  }
}

function openWithdrawal() {
  showWithdrawalDialog.value = true;
}

function onWithdrawalSubmitted() {
  showWithdrawalDialog.value = false;
  loadWithdrawals();
}

function statusLabel(s: TutorPayoutRequestStatus): string {
  return t(`tutor.bimbel.withdrawal.status_${s.toLowerCase()}`);
}

function statusBadgeClass(s: TutorPayoutRequestStatus): string {
  return STATUS_BADGE_CLASS[s] ?? 'bg-tutoring-grey-dim text-tutoring-text-mid';
}

function periodLabel(req: TutorPayoutRequest): string {
  if (!req.period_from || !req.period_to) return '—';
  // Display dd MMM → dd MMM yyyy when both dates land in the same year.
  const from = new Date(req.period_from);
  const to = new Date(req.period_to);
  const opt: Intl.DateTimeFormatOptions = { day: '2-digit', month: 'short' };
  const optY: Intl.DateTimeFormatOptions = { day: '2-digit', month: 'short', year: 'numeric' };
  const fmt = (d: Date, withY = false) =>
    d.toLocaleDateString('id-ID', withY ? optY : opt);
  return from.getFullYear() === to.getFullYear()
    ? `${fmt(from)} → ${fmt(to, true)}`
    : `${fmt(from, true)} → ${fmt(to, true)}`;
}

function reqAmount(req: TutorPayoutRequest): string {
  return formatRupiah(req.amount_requested);
}

const canWithdraw = computed(
  () => (summary.value?.earnings ?? 0) > 0,
);

// ── RITME — sessions per week bars (mirrors mobile tutor_earnings_screen) ──
// Buckets DONE sessions in the period by Monday-start week, returns
// 4-6 columns depending on month length.
type RitmeBar = { label: string; count: number };

const ritme = computed<RitmeBar[]>(() => {
  const { from, to } = periodRange();
  const bars: RitmeBar[] = [];
  // Walk Monday-start weeks from the first Monday on/before `from`.
  const start = new Date(from);
  const lead = (start.getDay() + 6) % 7;
  start.setDate(start.getDate() - lead);
  let w = 1;
  for (let cursor = new Date(start); cursor <= to; cursor.setDate(cursor.getDate() + 7)) {
    const weekStart = new Date(cursor);
    const weekEnd = new Date(cursor);
    weekEnd.setDate(weekEnd.getDate() + 6);
    weekEnd.setHours(23, 59, 59, 999);
    const count = sessions.value.filter((s) => {
      if (s.status !== 'DONE') return false;
      if (!s.scheduled_at) return false;
      const t = new Date(s.scheduled_at).valueOf();
      return t >= weekStart.valueOf() && t <= weekEnd.valueOf();
    }).length;
    bars.push({ label: `M${w}`, count });
    w++;
    if (w > 6) break;
  }
  return bars;
});

const ritmeMax = computed(() => Math.max(1, ...ritme.value.map((b) => b.count)));

function basisLabel(b: string) {
  return b === 'PER_HOUR' ? t('tutor.bimbel.earnings.rate_per_hour') : t('tutor.bimbel.earnings.rate_per_session');
}

const kpiCards = computed<KpiCard[]>(() => {
  const s = summary.value;
  if (!s) return [];
  return [
    {
      icon: 'wallet',
      label: t('tutor.bimbel.earnings.kpi_earnings'),
      value: formatRupiah(s.earnings),
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'calendar',
      label: t('tutor.bimbel.earnings.kpi_sessions'),
      value: s.sessions_count,
      tone: 'violet',
    },
    {
      icon: 'clock',
      label: t('tutor.bimbel.earnings.kpi_hours'),
      value: `${s.hours}h`,
      tone: 'amber',
    },
    {
      icon: 'tag',
      label: t('tutor.bimbel.earnings.kpi_rate'),
      value: s.rate.configured ? formatRupiah(s.rate.amount) : '–',
      suffix: s.rate.configured ? basisLabel(s.rate.basis) : t('tutor.bimbel.earnings.rate_unset'),
      tone: s.rate.configured ? 'green' : 'slate',
    },
  ];
});

// Build a small picker — last 6 months including current.
const monthOptions = computed(() => {
  const out: { value: string; label: string }[] = [
    { value: '', label: t('tutor.bimbel.earnings.month_current') },
  ];
  const now = new Date();
  for (let i = 1; i <= 5; i++) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    out.push({
      value: `${yyyy}-${mm}`,
      label: d.toLocaleString('id-ID', { month: 'long', year: 'numeric' }),
    });
  }
  return out;
});
</script>

<template>
  <div class="space-y-md pb-12">
    <TutorHomeHero
      :greeting="t('tutor.bimbel.earnings.greeting')"
      :title="t('tutor.bimbel.earnings.title')"
      :subtitle="summary ? `${t('tutor.bimbel.earnings.period_prefix')} ${summary.period.label}` : undefined"
      :stats="[]"
    />
    <div v-if="summary" class="flex justify-end -mt-2">
      <a
        :href="payslipUrl"
        target="_blank"
        rel="noopener"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-tutoring-accent text-white text-[13px] font-bold hover:opacity-90"
      >
        {{ t('tutor.bimbel.earnings.payslip_btn') }}
      </a>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>

    <template v-else-if="summary">
      <KpiStripCards :cards="kpiCards" />

      <!-- Withdrawal CTA — hidden when there's nothing to withdraw -->
      <div v-if="canWithdraw" class="flex justify-center sm:justify-end -mt-1">
        <button
          type="button"
          class="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-tutoring-accent text-white text-[14px] font-bold hover:opacity-90 shadow-sm"
          @click="openWithdrawal"
        >
          <NavIcon name="wallet" :size="16" />
          {{ t('tutor.bimbel.withdrawal.cta') }}
        </button>
      </div>

      <!-- RITME — sessions per week bars (mobile parity) -->
      <div
        v-if="ritme.length"
        class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 sm:p-5"
      >
        <div class="flex justify-between items-baseline mb-3">
          <p class="text-[12px] font-bold uppercase tracking-widest text-tutoring-text-mid">{{ t('tutor.bimbel.earnings.ritme_heading') }}</p>
          <p class="text-2xs text-tutoring-text-lo">{{ t('tutor.bimbel.earnings.ritme_subheading') }}</p>
        </div>
        <div class="flex items-end justify-between gap-2 h-24">
          <div
            v-for="b in ritme"
            :key="b.label"
            class="flex-1 flex flex-col items-center justify-end gap-1.5"
          >
            <span class="text-2xs font-bold text-tutoring-text-hi">{{ b.count }}</span>
            <div
              class="w-full rounded-t-md bg-tutoring-accent transition-all"
              :style="{ height: `${(b.count / ritmeMax) * 70}px`, minHeight: b.count > 0 ? '4px' : '0' }"
            ></div>
            <span class="text-3xs text-tutoring-text-lo">{{ b.label }}</span>
          </div>
        </div>
      </div>

      <div class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 sm:p-5">
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.earnings.month_label') }}
          </span>
          <select
            v-model="month"
            class="mt-1.5 w-full sm:w-64 rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option
              v-for="o in monthOptions"
              :key="o.value || 'now'"
              :value="o.value"
            >
              {{ o.label }}
            </option>
          </select>
        </label>

        <div
          v-if="!summary.rate.configured"
          class="mt-4 rounded-xl bg-tutoring-amber-soft border border-status-warning/30 p-3 text-sm text-tutoring-amber"
        >
          {{ t('tutor.bimbel.earnings.rate_unset_alert') }}
        </div>

        <div v-else class="mt-4 text-sm text-tutoring-text-mid leading-relaxed">
          <p>
            {{ t('tutor.bimbel.earnings.honor_prefix') }}
            <span class="font-bold text-tutoring-text-hi">
              {{ formatRupiah(summary.rate.amount) }}
            </span>
            {{ basisLabel(summary.rate.basis) }}
          </p>
          <p class="mt-1">
            {{ t('tutor.bimbel.earnings.computed_lead', { count: summary.sessions_count }) }}
            <strong>{{ t('tutor.bimbel.earnings.computed_done') }}</strong> {{ t('tutor.bimbel.earnings.computed_period_prefix') }}
            <strong>{{ summary.period.label }}</strong>
            ({{ summary.hours }} {{ t('tutor.bimbel.earnings.computed_hours_suffix') }}).
          </p>
          <p
            v-if="summary.rate.note"
            class="mt-2 text-xs text-tutoring-text-mid"
          >
            {{ t('tutor.bimbel.earnings.admin_note_prefix') }} {{ summary.rate.note }}
          </p>
        </div>
      </div>

      <!-- ── Riwayat Penarikan ──────────────────────────────────── -->
      <div
        class="bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4 sm:p-5"
      >
        <div class="flex items-baseline justify-between mb-3">
          <p class="text-[12px] font-bold uppercase tracking-widest text-tutoring-text-mid">
            {{ t('tutor.bimbel.withdrawal.history_heading') }}
          </p>
          <p class="text-2xs text-tutoring-text-lo">
            {{ t('tutor.bimbel.withdrawal.history_subtitle') }}
          </p>
        </div>

        <div
          v-if="withdrawalLoading"
          class="py-6 text-center text-tutoring-text-mid text-sm"
        >
          {{ t('tutoring.common.loading') }}
        </div>
        <div
          v-else-if="withdrawalRequests.length === 0"
          class="py-6 text-center text-tutoring-text-mid text-sm"
        >
          {{ t('tutor.bimbel.withdrawal.history_empty') }}
        </div>
        <ul v-else class="divide-y divide-tutoring-border-soft">
          <li
            v-for="req in withdrawalRequests"
            :key="req.id"
            class="py-2.5 first:pt-0 last:pb-0 flex items-start justify-between gap-3"
          >
            <div class="min-w-0">
              <p class="text-[13.5px] font-semibold text-tutoring-text-hi truncate">
                {{ reqAmount(req) }}
              </p>
              <p class="text-[11.5px] text-tutoring-text-mid mt-0.5">
                {{ periodLabel(req) }}
              </p>
              <p
                v-if="req.status === 'REJECTED' && req.reject_reason"
                class="text-2xs text-tutoring-red mt-0.5 line-clamp-2"
              >
                {{ t('tutor.bimbel.withdrawal.reject_reason_prefix') }} {{ req.reject_reason }}
              </p>
            </div>
            <span
              class="shrink-0 inline-flex items-center rounded-md px-2 py-0.5 text-2xs font-bold uppercase tracking-wide"
              :class="statusBadgeClass(req.status)"
            >
              {{ statusLabel(req.status) }}
            </span>
          </li>
        </ul>
      </div>
    </template>

    <TutoringEmpty
      v-else
      :text="t('tutor.bimbel.earnings.load_failed_short')"
      icon="alert-circle"
    />

    <TutorWithdrawalDialog
      v-if="showWithdrawalDialog"
      :initial-eligible="summary?.earnings"
      :initial-month="month || undefined"
      @close="showWithdrawalDialog = false"
      @submitted="onWithdrawalSubmitted"
    />
  </div>
</template>
