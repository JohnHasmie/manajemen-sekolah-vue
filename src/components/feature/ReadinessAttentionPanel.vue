<!--
  ReadinessAttentionPanel.vue — the "Perlu Perhatian" card for the admin
  dashboard (Opsi A, "Hari ini" band, right rail).

  SINGLE SOURCE OF TRUTH: this panel is a COMPACT MIRROR of the full
  Pusat Kendali page (AdminReadinessView.vue). It is fed by the SAME
  `/admin/readiness` payload the control-center card already consumes
  (the parent passes it down — no second fetch) and renders its two
  lanes verbatim:

    · "Perlu dilengkapi" (completion_needed) — Lane A, SCORED. Fixing
      these raises the readiness score → tagged "memengaruhi skor".
    · "Perlu perhatian"  (attention_needed)  — Lane B, operational,
      UNSCORED → tagged "tidak memengaruhi skor".

  It NO LONGER invents client-side signals (staff attendance %, "staf
  sepi", lowest-class attendance). Those disagreed with the Pusat
  Kendali page and duplicated the Engagement card's "Sepi" stat.

  The list is capped (top-N by severity per lane) to stay compact in the
  rail; a "Lihat semua" footer deep-links to the full readiness page.
  Each row clicks through via the backend `target_route` hint, mapped to
  a real Vue route by the shared `readiness-nav` helper (falling back to
  the readiness page when a hint is unmapped).

  ABILITY GATING — the two lanes are treated DIFFERENTLY on purpose:
    · Lane B is DROPPED when the viewer can't open the destination.
      Unscored operational nudges: hiding one costs nothing, showing one
      that 403s costs trust. Filtering runs before the cap so a dropped
      row yields its slot.
    · Lane A stays VISIBLE but goes non-tappable (no chevron, no click).
      These rows are the score's line items — hiding one would leave an
      83% the admin can't reconcile against the list in front of them.
  Both read the same `requiredAbilities` declared in `readiness-nav`.

  RENDER GUARD (mirrors the Flutter admin dashboard body): the panel
  renders NOTHING until readiness state is actually KNOWN — i.e. the
  parent holds `readiness.view`, the fetch has SETTLED (`loaded`), the
  payload came back non-null, and the tenant is `supported`. An empty
  payload and an unknown payload are different things: without this
  guard a failed / unsupported / unauthorised fetch fell through to the
  emerald "Semua aman" strip and told the admin everything was fine
  when we simply had no idea.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import NavIcon from '@/components/feature/NavIcon.vue';
import { useMeStore } from '@/stores/me';
import type {
  ReadinessPayload,
  ReadinessSeverity,
} from '@/services/readiness.service';
import {
  canReachReadinessTarget,
  resolveReadinessRouteName,
} from '@/lib/readiness-nav';

const props = withDefaults(
  defineProps<{
    /** Readiness payload from GET /admin/readiness (null when unsupported / not loaded). */
    readiness: ReadinessPayload | null;
    /**
     * Whether the parent's `/admin/readiness` fetch has SETTLED for a
     * viewer that actually holds `readiness.view`. False means "state
     * unknown" — either still in flight, or the ability is absent so no
     * fetch was ever issued. Distinct from `readiness === null`, which
     * additionally covers a fetch that settled by REJECTING.
     */
    loaded?: boolean;
  }>(),
  { loaded: false },
);

const { t } = useI18n();
const router = useRouter();
const me = useMeStore();

// Keep the rail compact: at most this many rows per lane.
const MAX_COMPLETION = 3;
const MAX_ATTENTION = 2;

const SEVERITY_RANK: Record<ReadinessSeverity, number> = {
  critical: 0,
  warning: 1,
  info: 2,
};

/** A normalised row — either lane renders through the same template. */
interface PanelRow {
  key: string;
  severity: ReadinessSeverity;
  label: string;
  subtitle: string;
  /** Backend route hint — resolved on click by the shared helper. */
  targetRoute: string;
  targetParams: Record<string, unknown>;
  /**
   * False when the viewer lacks the destination's ability. Only Lane A
   * rows can carry `false` — unreachable Lane B rows are filtered out
   * entirely rather than rendered inert.
   */
  tappable: boolean;
}

/**
 * Readiness state is KNOWN — the only condition under which this panel
 * is allowed to make a claim (including the green "Semua aman" one).
 * Same gates as `admin_dashboard_body.dart`:
 *   1. the fetch settled for an ability-holding viewer (`loaded`) —
 *      this also covers "admin lacks readiness.view", because the
 *      parent never fires the request in that case
 *   2. the payload is non-null (it settled by RESOLVING, not rejecting)
 *   3. the tenant supports readiness
 */
const stateKnown = computed(
  () => props.loaded && props.readiness != null && props.readiness.supported,
);

// Lane B minus everything this viewer can't open. Counted from the
// FILTERED list so the "N perlu perhatian" eyebrow matches what the
// full Pusat Kendali page (gated the same way) will show them.
const reachableAttention = computed(() =>
  (props.readiness?.attention_needed ?? []).filter((item) =>
    canReachReadinessTarget(item.target_route, me),
  ),
);

const completionCount = computed(
  () => props.readiness?.completion_needed?.length ?? 0,
);
const attentionCount = computed(() => reachableAttention.value.length);
const totalCount = computed(() => completionCount.value + attentionCount.value);
const hasItems = computed(() => totalCount.value > 0);

// Spread before sort so we never mutate the reactive payload array.
// Lane A rows are NEVER dropped — an unreachable one just loses its
// tap target, so the score stays fully itemised.
const completionRows = computed<PanelRow[]>(() =>
  [...(props.readiness?.completion_needed ?? [])]
    .sort((a, b) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity])
    .slice(0, MAX_COMPLETION)
    .map((item) => ({
      key: `completion-${item.key}`,
      severity: item.severity,
      label: item.label,
      subtitle: item.subtitle,
      targetRoute: item.target_route,
      targetParams: item.target_params,
      tappable: canReachReadinessTarget(item.target_route, me),
    })),
);

const attentionRows = computed<PanelRow[]>(() =>
  [...reachableAttention.value]
    .sort((a, b) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity])
    .slice(0, MAX_ATTENTION)
    .map((item) => ({
      key: `attention-${item.id}`,
      severity: item.severity,
      label: item.label,
      subtitle: item.subtitle,
      targetRoute: item.target_route,
      targetParams: item.target_params,
      tappable: true,
    })),
);

// Severity → row tint + dot. These colours CARRY MEANING (critical /
// warning / info), so they stay per the theme-colour rationalisation.
const ROW_CLASS: Record<ReadinessSeverity, string> = {
  critical: 'bg-red-50 border-red-200',
  warning: 'bg-amber-50 border-amber-200',
  info: 'bg-slate-50 border-slate-200',
};
// Applied only to tappable rows, so an ability-blocked Lane A row reads
// as inert (no hover tint, no pointer cursor) instead of looking
// clickable and doing nothing.
const ROW_INTERACTIVE_CLASS: Record<ReadinessSeverity, string> = {
  critical: 'hover:bg-red-100 cursor-pointer',
  warning: 'hover:bg-amber-100 cursor-pointer',
  info: 'hover:bg-slate-100 cursor-pointer',
};
const DOT_CLASS: Record<ReadinessSeverity, string> = {
  critical: 'bg-red-500',
  warning: 'bg-amber-500',
  info: 'bg-slate-400',
};

function goto(row: PanelRow) {
  if (!row.tappable) return;
  const name = resolveReadinessRouteName(row.targetRoute);
  if (name) {
    router.push({ name, params: row.targetParams as Record<string, string> });
  } else {
    // Unmapped hint → still actionable: send them to the full page.
    router.push({ name: 'admin.readiness' });
  }
}

function gotoReadiness() {
  router.push({ name: 'admin.readiness' });
}
</script>

<template>
  <section
    v-if="stateKnown"
    class="bg-white border border-slate-200 rounded-2xl p-4"
  >
    <!-- Header — alert icon when there are items, check icon when clear. -->
    <header class="flex items-center gap-2.5 mb-3 px-1">
      <div
        class="w-8 h-8 rounded-xl grid place-items-center flex-shrink-0"
        :class="hasItems ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700'"
      >
        <NavIcon :name="hasItems ? 'alert-triangle' : 'check-circle'" :size="16" />
      </div>
      <div class="min-w-0">
        <p class="text-3xs font-bold text-slate-400 uppercase tracking-widest">
          {{ hasItems ? t('admin.dashboard.attention.count', { n: totalCount }) : t('admin.dashboard.attention.allClearEyebrow') }}
        </p>
        <h3 class="text-sm font-black text-slate-900 leading-none mt-0.5">
          {{ t('admin.dashboard.needsAttention') }}
        </h3>
      </div>
    </header>

    <div class="flex flex-col gap-3">
      <!-- Lane A — Perlu dilengkapi (scored). -->
      <div v-if="completionRows.length > 0" class="flex flex-col gap-2">
        <p class="text-3xs font-bold text-slate-500 px-1 flex items-center gap-1.5">
          {{ t('admin.readiness.laneA') }}
          <span class="text-3xs font-bold text-role-admin normal-case">· {{ t('admin.readiness.laneAHint') }}</span>
        </p>
        <!-- Row stays rendered even when the viewer can't open it (the
             score has to stay itemised); `disabled` + no chevron is what
             communicates "not yours to fix". -->
        <button
          v-for="row in completionRows"
          :key="row.key"
          type="button"
          class="w-full flex items-start gap-2.5 p-2.5 rounded-xl border text-left transition-colors"
          :class="[
            ROW_CLASS[row.severity],
            row.tappable ? ROW_INTERACTIVE_CLASS[row.severity] : 'cursor-default',
          ]"
          :disabled="!row.tappable"
          @click="goto(row)"
        >
          <span
            class="w-2 h-2 rounded-full mt-1.5 flex-shrink-0"
            :class="DOT_CLASS[row.severity]"
            aria-hidden="true"
          ></span>
          <span class="min-w-0 flex-1">
            <span class="block text-xs font-bold text-slate-900 leading-tight">{{ row.label }}</span>
            <span class="block text-3xs text-slate-500 leading-tight mt-0.5 truncate">{{ row.subtitle }}</span>
          </span>
          <NavIcon
            v-if="row.tappable"
            name="chevron-right"
            :size="14"
            class="text-slate-400 self-center flex-shrink-0"
          />
        </button>
      </div>

      <!-- Lane B — Perlu perhatian (operational, unscored). -->
      <div v-if="attentionRows.length > 0" class="flex flex-col gap-2">
        <p class="text-3xs font-bold text-slate-500 px-1 flex items-center gap-1.5">
          {{ t('admin.readiness.laneB') }}
          <span class="text-3xs font-bold text-slate-400 normal-case">· {{ t('admin.readiness.laneBHint') }}</span>
        </p>
        <!-- Lane B rows are pre-filtered to reachable destinations only,
             so every one of these is genuinely tappable. -->
        <button
          v-for="row in attentionRows"
          :key="row.key"
          type="button"
          class="w-full flex items-start gap-2.5 p-2.5 rounded-xl border text-left transition-colors"
          :class="[ROW_CLASS[row.severity], ROW_INTERACTIVE_CLASS[row.severity]]"
          @click="goto(row)"
        >
          <span
            class="w-2 h-2 rounded-full mt-1.5 flex-shrink-0"
            :class="DOT_CLASS[row.severity]"
            aria-hidden="true"
          ></span>
          <span class="min-w-0 flex-1">
            <span class="block text-xs font-bold text-slate-900 leading-tight">{{ row.label }}</span>
            <span class="block text-3xs text-slate-500 leading-tight mt-0.5 truncate">{{ row.subtitle }}</span>
          </span>
          <NavIcon name="chevron-right" :size="14" class="text-slate-400 self-center flex-shrink-0" />
        </button>
      </div>

      <!-- All-clear — both lanes empty. -->
      <div
        v-if="!hasItems"
        class="flex items-center gap-2.5 p-2.5 rounded-xl border bg-emerald-50 border-emerald-200"
      >
        <span class="w-7 h-7 rounded-lg grid place-items-center flex-shrink-0 bg-emerald-100 text-emerald-600">
          <NavIcon name="check" :size="14" />
        </span>
        <span class="min-w-0 flex-1">
          <span class="block text-xs font-bold text-emerald-900 leading-tight">
            {{ t('admin.dashboard.attention.allClearTitle') }}
          </span>
          <span class="block text-3xs text-emerald-700 leading-tight mt-0.5">
            {{ t('admin.dashboard.attention.allClearSub') }}
          </span>
        </span>
      </div>

      <!-- Deep-dive to the full Pusat Kendali page. -->
      <button
        v-if="hasItems"
        type="button"
        class="self-end inline-flex items-center gap-1 text-2xs font-bold text-role-admin hover:underline mt-0.5"
        @click="gotoReadiness"
      >
        {{ t('common.viewAll') }}
        <NavIcon name="arrow-right" :size="12" />
      </button>
    </div>
  </section>
</template>
