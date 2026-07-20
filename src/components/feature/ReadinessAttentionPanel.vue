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
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import NavIcon from '@/components/feature/NavIcon.vue';
import type {
  ReadinessPayload,
  ReadinessSeverity,
} from '@/services/readiness.service';
import { resolveReadinessRouteName } from '@/lib/readiness-nav';

const props = defineProps<{
  /** Readiness payload from GET /admin/readiness (null when unsupported / not loaded). */
  readiness: ReadinessPayload | null;
}>();

const { t } = useI18n();
const router = useRouter();

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
}

const completionCount = computed(
  () => props.readiness?.completion_needed?.length ?? 0,
);
const attentionCount = computed(
  () => props.readiness?.attention_needed?.length ?? 0,
);
const totalCount = computed(() => completionCount.value + attentionCount.value);
const hasItems = computed(() => totalCount.value > 0);

// Spread before sort so we never mutate the reactive payload array.
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
    })),
);

const attentionRows = computed<PanelRow[]>(() =>
  [...(props.readiness?.attention_needed ?? [])]
    .sort((a, b) => SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity])
    .slice(0, MAX_ATTENTION)
    .map((item) => ({
      key: `attention-${item.id}`,
      severity: item.severity,
      label: item.label,
      subtitle: item.subtitle,
      targetRoute: item.target_route,
      targetParams: item.target_params,
    })),
);

// Severity → row tint + dot. These colours CARRY MEANING (critical /
// warning / info), so they stay per the theme-colour rationalisation.
const ROW_CLASS: Record<ReadinessSeverity, string> = {
  critical: 'bg-red-50 border-red-200 hover:bg-red-100',
  warning: 'bg-amber-50 border-amber-200 hover:bg-amber-100',
  info: 'bg-slate-50 border-slate-200 hover:bg-slate-100',
};
const DOT_CLASS: Record<ReadinessSeverity, string> = {
  critical: 'bg-red-500',
  warning: 'bg-amber-500',
  info: 'bg-slate-400',
};

function goto(row: PanelRow) {
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
  <section class="bg-white border border-slate-200 rounded-2xl p-4">
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
        <button
          v-for="row in completionRows"
          :key="row.key"
          type="button"
          class="w-full flex items-start gap-2.5 p-2.5 rounded-xl border text-left transition-colors cursor-pointer"
          :class="ROW_CLASS[row.severity]"
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

      <!-- Lane B — Perlu perhatian (operational, unscored). -->
      <div v-if="attentionRows.length > 0" class="flex flex-col gap-2">
        <p class="text-3xs font-bold text-slate-500 px-1 flex items-center gap-1.5">
          {{ t('admin.readiness.laneB') }}
          <span class="text-3xs font-bold text-slate-400 normal-case">· {{ t('admin.readiness.laneBHint') }}</span>
        </p>
        <button
          v-for="row in attentionRows"
          :key="row.key"
          type="button"
          class="w-full flex items-start gap-2.5 p-2.5 rounded-xl border text-left transition-colors cursor-pointer"
          :class="ROW_CLASS[row.severity]"
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
