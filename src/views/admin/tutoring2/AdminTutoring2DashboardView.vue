<!--
  AdminTutoring2DashboardView.vue — the bimbel admin home (CLEAN-2
  Phase 2 · greenfield replacement for the legacy
  `admin/tutoring/AdminTutoringDashboardView.vue`).

  This is the highest-traffic legacy view in the phase: it is the only
  screen still generating real production hits on the v1
  `/tutoring/admin-stats` + `/tutoring/admin-activity` pair.

  Route: /admin/tutoring2
  Endpoints:
    GET /tutoring-v2/admin/stats        headline KPI aggregate  (BE-27)
    GET /tutoring-v2/admin/activity     tenant feed, 30 days    (BE-27)
    GET /tutoring-v2/learning-groups    "kelompok tanpa tutor"  (BE-3)
    GET /tutoring-v2/bills              "tagihan tertunggak"    (BE-8)
    GET /tutoring-v2/leads?status=trial "lead panas"            (BE-15)

  ── WHICH v2 STATS ROUTE, AND WHY ────────────────────────────────────
  The v2 group exposes `/tutoring-v2/admin/stats` + `/admin/activity`
  (slash-separated, `Tutoring\AdminStatsController`). It does NOT
  expose `/tutoring-v2/admin-stats` / `/admin-activity` — the
  hyphenated pair exists ONLY under the legacy `/tutoring` prefix
  (`TutoringLegacy\TutoringAdminStatsController` +
  `TutoringActivityFeedController`, both behind the
  `log.legacy-tutoring` middleware). Verified by reading
  `routes/api.php` between the `Route::prefix('tutoring-v2')` group and
  the `Route::prefix('tutoring')` group that follows it. So: slash form,
  because it is the only form wired to a greenfield controller.

  ── CONTRACT DIFFERENCES vs the legacy view ──────────────────────────

  1. STATS SHAPE IS NESTED. v1 returned a flat bag (`students`,
     `groups`, `sessions_this_week`, `sessions_today`,
     `new_enrollments_today`). v2 returns five buckets
     (students / sessions / assessments / billing / leads). Two v1
     fields have no v2 equivalent and are dropped rather than faked:
       - `new_enrollments_today` — v2 has no "today" enrollment
         counter, so the "+N hari ini" hint under the student stat is
         gone. Closest v2 signal is `leads.new_this_week`, which we
         surface as its own KPI instead of pretending it's the same
         number.
       - `groups` — v2 stats has no group counter. We derive the group
         count from the `/learning-groups` list we already fetch for
         the "perlu tutor" panel, so the number stays real.
     In exchange v2 gives us three things v1 never had, now shown as
     KPIs: 7-day attendance rate, tenant arrears (`billing.menunggak`),
     and this-month assessment output.

  2. GROUP → TUTOR FIELD RENAMED. v1 `TutoringGroup.tutor_user_id`
     (FK to `users`) became v2 `BimbelLearningGroup.tutor_id` (FK to
     `teachers`). The "kelompok tanpa tutor" filter tests the new field.

  3. BILL STATUS IS A CLOSED ENUM NOW. v1 statuses were free text, so
     the legacy view ran a `/unpaid|pending|due|overdue|belum/i` regex
     over them. v2 bills carry `unpaid | pending | partial | paid`, so
     we ask the server for `status=unpaid` and drop the regex.

  4. LEAD STATUS IS LOWERCASE. v1 filtered `status: 'TRIAL'`; the v2
     `LeadStatus` enum is lowercase `trial`.

  5. NAVIGATION TARGETS. The legacy view's "assign tutor" CTA pushed
     `admin.tutoring.group-detail` (a v1 view). It now points at
     `admin.tutoring2.group-detail`, the sibling greenfield detail view
     shipped alongside this one.

  ── PARTIAL-FAILURE POLICY ───────────────────────────────────────────
  `admin/stats` is the page's reason to exist and is gated on the same
  `dashboard.admin.view` ability as the route itself, so a failure
  there fails the whole view (AsyncView renders the error + retry).
  The four SIDE PANELS are each gated on a different, independently
  grantable ability (`tutoring.group.view`, `tutoring.bill.view`,
  `tutoring.lead.view`) — an admin who lacks one of them must still get
  a working dashboard, so those four soft-fail to empty and render
  their own empty state. This mirrors the legacy view's per-call
  `.catch(() => [])`, but only for the calls that genuinely are
  optional.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, { type KpiCard } from '@/components/feature/KpiStripCards.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { formatRupiah } from '@/lib/format';
import {
  TutoringBimbelService,
  type BimbelBill,
  type BimbelLearningGroup,
} from '@/services/tutoring-bimbel.service';
import { TutoringAdminDashboardService } from '@/services/tutoring2/dashboard';
import { TutoringLeadsService } from '@/services/tutoring2/leads';
import { useAuthStore } from '@/stores/auth';
import type {
  AdminActivityEvent,
  AdminDashboardStats,
} from '@/types/tutoring2/dashboard';
import type { BimbelLead } from '@/types/tutoring2/lead';

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();

interface DashboardPayload {
  stats: AdminDashboardStats;
  feed: AdminActivityEvent[];
  groups: BimbelLearningGroup[];
  unpaidBills: BimbelBill[];
  trialLeads: BimbelLead[];
}

/**
 * Side-panel loader guard — see the PARTIAL-FAILURE POLICY note in the
 * file header. Swallowing here is deliberate and scoped: only the four
 * optional panels use it, and each renders an honest empty state when
 * its fetch was refused.
 */
function optional<T>(p: Promise<T>, fallback: T): Promise<T> {
  return p.catch(() => fallback);
}

const { state, reload } = useDataRefresh<DashboardPayload>(async () => {
  const [stats, activity, groups, bills, leads] = await Promise.all([
    TutoringAdminDashboardService.getStats(),
    optional(TutoringAdminDashboardService.listActivity({ per_page: 8 }), {
      items: [],
      meta: undefined,
    }),
    optional(TutoringBimbelService.listGroups({ per_page: 100 }), {
      items: [],
      pagination: undefined,
    }),
    // v2 bill statuses are a closed enum — ask the server for `unpaid`
    // instead of regex-matching free text the way v1 had to.
    optional(TutoringBimbelService.listBills({ per_page: 50, status: 'unpaid' }), {
      items: [],
      pagination: undefined,
    }),
    optional(TutoringLeadsService.list({ status: 'trial', per_page: 20 }), {
      items: [],
      pagination: undefined,
    }),
  ]);

  return {
    stats,
    feed: activity.items,
    groups: groups.items,
    unpaidBills: bills.items,
    trialLeads: leads.items,
  };
});

const payload = computed<DashboardPayload | null>(() =>
  state.value.status === 'content' || state.value.status === 'empty'
    ? (state.value.data ?? null)
    : null,
);

const stats = computed<AdminDashboardStats | null>(() => payload.value?.stats ?? null);
const feed = computed<AdminActivityEvent[]>(() => payload.value?.feed ?? []);
const groups = computed<BimbelLearningGroup[]>(() => payload.value?.groups ?? []);
const trialLeads = computed<BimbelLead[]>(() => payload.value?.trialLeads ?? []);

/** v2 renamed `tutor_user_id` → `tutor_id` (users → teachers FK). */
const groupsWithoutTutor = computed(() => groups.value.filter((g) => !g.tutor_id));
const attentionGroup = computed(() => groupsWithoutTutor.value[0] ?? null);

/** Soonest-due first; bills with no due date sink to the bottom. */
const unpaidBills = computed<BimbelBill[]>(() =>
  [...(payload.value?.unpaidBills ?? [])].sort((a, b) => dueSortKey(a) - dueSortKey(b)),
);

function dueSortKey(bill: BimbelBill): number {
  const d = parseLocalDate(bill.due_date);
  return d ? d.valueOf() : Number.POSITIVE_INFINITY;
}

/**
 * Local-time greeting. `getHours()` is the user's own clock, which is
 * exactly what a greeting wants — no UTC anywhere.
 */
function timeGreeting(): string {
  const h = new Date().getHours();
  if (h < 11) return t('tutoring2.admin.dashboard.greetingMorning');
  if (h < 15) return t('tutoring2.admin.dashboard.greetingAfternoon');
  if (h < 19) return t('tutoring2.admin.dashboard.greetingEvening');
  return t('tutoring2.admin.dashboard.greetingNight');
}

const firstName = computed(() => (auth.user?.name ?? 'Admin').split(/\s+/)[0] ?? 'Admin');

const kpiCards = computed<KpiCard[]>(() => {
  const s = stats.value;
  return [
    {
      icon: 'users',
      label: t('tutoring2.admin.dashboard.kpiStudents'),
      value: String(s?.students.total ?? 0),
      suffix: t('tutoring2.admin.dashboard.kpiStudentsActiveSuffix', {
        count: s?.students.active_enrollments ?? 0,
      }),
      tone: 'brand',
      accented: true,
    },
    {
      icon: 'calendar',
      label: t('tutoring2.admin.dashboard.kpiSessionsWeek'),
      value: String(s?.sessions.this_week ?? 0),
      suffix: t('tutoring2.admin.dashboard.kpiSessionsTodaySuffix', {
        count: s?.sessions.today ?? 0,
      }),
      tone: 'violet',
    },
    {
      icon: 'check-circle',
      label: t('tutoring2.admin.dashboard.kpiAttendance7d'),
      // Backend ships a 0..1 ratio; the strip shows whole percent.
      value: `${Math.round((s?.sessions.attendance_rate_7d ?? 0) * 100)}%`,
      tone: 'green',
    },
    {
      icon: 'wallet',
      label: t('tutoring2.admin.dashboard.kpiArrears'),
      value: formatRupiah(s?.billing.menunggak ?? 0),
      suffix: t('tutoring2.admin.dashboard.kpiArrearsCountSuffix', {
        count: s?.billing.overdue_count ?? 0,
      }),
      tone: (s?.billing.overdue_count ?? 0) > 0 ? 'red' : 'slate',
    },
  ];
});

const headerMeta = computed(() => {
  if (state.value.status === 'loading') return t('tutoring2.common.loading');
  const s = stats.value;
  return t('tutoring2.admin.dashboard.meta', {
    students: s?.students.total ?? 0,
    groups: groups.value.length,
  });
});

/** Days since the lead row was created, floor'd. Null when unknown. */
function leadAgeDays(lead: BimbelLead): number | null {
  if (!lead.created_at) return null;
  const created = new Date(lead.created_at).valueOf();
  if (Number.isNaN(created)) return null;
  return Math.floor((Date.now() - created) / 86_400_000);
}

const oldestTrialLead = computed<BimbelLead | null>(() => {
  const sorted = [...trialLeads.value].sort((a, b) => {
    const da = a.created_at ? new Date(a.created_at).valueOf() : 0;
    const db = b.created_at ? new Date(b.created_at).valueOf() : 0;
    return da - db;
  });
  return sorted[0] ?? null;
});

const leadHint = computed(() => {
  const lead = oldestTrialLead.value;
  if (!lead) return '';
  const days = leadAgeDays(lead);
  if (days === null) return lead.name;
  return t('tutoring2.admin.dashboard.hotLeadHint', { days, name: lead.name });
});

/**
 * Parse a `YYYY-MM-DD` (or the date half of an ISO string) into a
 * LOCAL-midnight Date. `new Date('2026-08-10')` is parsed as UTC by
 * spec, which renders the previous day for any negative-offset viewer
 * — so we build from the parts instead. Mirrors the rule that bans
 * `toISOString().slice(...)` on the way out.
 */
function parseLocalDate(value: string | null | undefined): Date | null {
  if (!value) return null;
  const [datePart] = value.split('T');
  const [y, m, d] = (datePart ?? '').split('-').map(Number);
  if (!y || !m || !d) return null;
  const parsed = new Date(y, m - 1, d);
  return Number.isNaN(parsed.valueOf()) ? null : parsed;
}

function formatDueDate(value: string | null | undefined): string {
  const d = parseLocalDate(value);
  if (!d) return '—';
  return t('tutoring2.admin.dashboard.dueShort', {
    date: d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }),
  });
}

/**
 * Feed timestamps are full ISO-8601 WITH an offset, so `new Date()` is
 * unambiguous here — the local-parts dance above is only needed for
 * bare `YYYY-MM-DD` values.
 */
function formatEventTime(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleString('id-ID', {
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
}

/** Event flavour → NavIcon name. Every flavour in the union is covered. */
function eventIcon(type: AdminActivityEvent['type']): string {
  switch (type) {
    case 'bill_created':
    case 'bill_paid':
      return 'wallet';
    case 'session_done':
      return 'check-circle';
    case 'enrollment_created':
      return 'user-plus';
    case 'assessment_published':
      return 'file-text';
    case 'feedback_submitted':
      return 'star';
    case 'lead_converted':
      return 'sparkles';
  }
}

function goLeads(): void {
  void router.push({ name: 'admin.tutoring2.leads' });
}

function goBills(): void {
  void router.push({ name: 'admin.tutoring2.billing' });
}

/**
 * Accepts null so the "perlu perhatian" CTA can bind straight to
 * `attentionGroup` without relying on template-level narrowing.
 */
function goGroupDetail(group: BimbelLearningGroup | null): void {
  if (!group) return;
  void router.push({
    name: 'admin.tutoring2.group-detail',
    params: { groupId: group.id },
  });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="`${timeGreeting()} · ${t('tutoring2.common.roleAdmin')}`"
      :title="t('tutoring2.admin.dashboard.title', { name: firstName })"
      :meta="headerMeta"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="4"
      @retry="reload"
    >
      <template #default>
        <div class="grid gap-3 lg:grid-cols-3">
          <div class="space-y-3 lg:col-span-2">
            <!-- Perlu perhatian — first group still missing a tutor. -->
            <section
              v-if="attentionGroup"
              class="rounded-3xl border border-amber-200 bg-amber-50/60 p-4"
            >
              <p class="text-2xs font-bold uppercase tracking-widest text-amber-700">
                {{ t('tutoring2.admin.dashboard.attentionKicker') }}
              </p>
              <p class="mt-1 text-sm font-bold text-slate-900">
                {{ t('tutoring2.admin.dashboard.attentionTitle', { name: attentionGroup.name }) }}
              </p>
              <p class="mt-0.5 text-2xs text-slate-600">
                {{ t('tutoring2.admin.dashboard.attentionDesc') }}
              </p>
              <button
                type="button"
                class="mt-3 inline-flex items-center gap-1.5 rounded-xl bg-amber-500 px-3.5 py-2 text-2xs font-bold text-white transition hover:bg-amber-600"
                @click="goGroupDetail(attentionGroup)"
              >
                <NavIcon name="user-check" :size="13" />
                {{ t('tutoring2.admin.dashboard.assignTutor') }}
              </button>
            </section>

            <!-- Lead panas — trial-stage leads waiting on a decision. -->
            <button
              v-if="trialLeads.length > 0"
              type="button"
              class="flex w-full items-center gap-3 rounded-3xl border border-amber-200 bg-white p-4 text-left transition hover:border-amber-400 hover:shadow-md"
              @click="goLeads"
            >
              <span
                class="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-amber-100 text-amber-700"
              >
                <NavIcon name="sparkles" :size="16" />
              </span>
              <span class="min-w-0 flex-1">
                <span class="block text-sm font-bold text-slate-900">
                  {{ t('tutoring2.admin.dashboard.hotLeadValue', { count: trialLeads.length }) }}
                </span>
                <span v-if="leadHint" class="block truncate text-2xs text-slate-500">
                  {{ leadHint }}
                </span>
              </span>
              <span class="text-slate-300" aria-hidden="true">›</span>
            </button>

            <div class="grid gap-3 sm:grid-cols-2">
              <!-- Kelompok tanpa tutor -->
              <section class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
                <h2 class="mb-2 text-sm font-bold text-slate-900">
                  {{ t('tutoring2.admin.dashboard.groupsNeedingTutor') }}
                </h2>
                <p
                  v-if="groupsWithoutTutor.length === 0"
                  class="py-3 text-center text-2xs text-slate-400"
                >
                  {{ t('tutoring2.admin.dashboard.allGroupsHaveTutor') }}
                </p>
                <button
                  v-for="g in groupsWithoutTutor.slice(0, 4)"
                  :key="g.id"
                  type="button"
                  class="flex w-full items-center gap-2.5 border-b border-slate-100 py-2 text-left last:border-0 hover:bg-slate-50"
                  @click="goGroupDetail(g)"
                >
                  <span
                    class="grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-amber-100 text-amber-700"
                  >
                    <NavIcon name="alert-triangle" :size="13" />
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="block truncate text-2xs font-bold text-slate-900">{{ g.name }}</span>
                    <span class="block text-2xs text-slate-500">
                      {{ t('tutoring2.admin.dashboard.noTutor') }}
                    </span>
                  </span>
                </button>
              </section>

              <!-- Tagihan tertunggak -->
              <section class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
                <h2 class="mb-2 text-sm font-bold text-slate-900">
                  {{ t('tutoring2.admin.dashboard.unpaidBills') }}
                </h2>
                <p v-if="unpaidBills.length === 0" class="py-3 text-center text-2xs text-slate-400">
                  {{ t('tutoring2.admin.dashboard.noUnpaidBills') }}
                </p>
                <template v-else>
                  <!-- Total comes from the server aggregate, not a sum
                       over the 50-row page we happen to have loaded. -->
                  <div class="mb-1 flex items-center justify-between border-b border-slate-100 pb-2">
                    <span class="text-2xs text-slate-500">
                      {{ t('tutoring2.admin.dashboard.arrearsTotal') }}
                    </span>
                    <span class="text-sm font-black text-slate-900">
                      {{ formatRupiah(stats?.billing.menunggak ?? 0) }}
                    </span>
                  </div>
                  <button
                    v-for="b in unpaidBills.slice(0, 3)"
                    :key="b.id"
                    type="button"
                    class="flex w-full items-center gap-2.5 border-b border-slate-100 py-2 text-left last:border-0 hover:bg-slate-50"
                    @click="goBills"
                  >
                    <span
                      class="grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-red-100 text-red-700"
                    >
                      <NavIcon name="wallet" :size="13" />
                    </span>
                    <span class="min-w-0 flex-1">
                      <span class="block text-2xs font-bold text-slate-900">
                        {{ formatRupiah(b.amount) }}
                      </span>
                      <span class="block truncate text-2xs text-slate-500">
                        {{ [b.student_name, formatDueDate(b.due_date)].filter(Boolean).join(' · ') }}
                      </span>
                    </span>
                  </button>
                </template>
              </section>
            </div>
          </div>

          <!-- Yang baru — merged tenant feed. -->
          <aside class="rounded-3xl border border-slate-100 bg-white p-4 shadow-sm">
            <h2 class="mb-2 text-sm font-bold text-slate-900">
              {{ t('tutoring2.admin.dashboard.whatsNew') }}
            </h2>
            <p v-if="feed.length === 0" class="py-6 text-center text-2xs text-slate-400">
              {{ t('tutoring2.admin.dashboard.noNewActivity') }}
            </p>
            <ul v-else class="space-y-1">
              <li
                v-for="(e, i) in feed.slice(0, 6)"
                :key="`${e.type}-${e.at ?? i}`"
                class="flex items-start gap-2.5 border-b border-slate-100 py-2 last:border-0"
              >
                <span
                  class="grid h-7 w-7 shrink-0 place-items-center rounded-lg bg-brand-cobalt/10 text-brand-cobalt"
                >
                  <NavIcon :name="eventIcon(e.type)" :size="13" />
                </span>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-2xs font-bold text-slate-900">
                    {{ e.subject_name ?? '—' }}
                  </p>
                  <p class="truncate text-2xs text-slate-500">
                    {{ [e.snippet, e.actor_name].filter(Boolean).join(' · ') }}
                  </p>
                  <p class="text-2xs text-slate-400">{{ formatEventTime(e.at) }}</p>
                </div>
              </li>
            </ul>
          </aside>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
