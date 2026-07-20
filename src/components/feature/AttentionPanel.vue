<!--
  AttentionPanel.vue — the "Perlu Perhatian" card for the admin dashboard
  (Opsi A, "Hari ini" band, right rail).

  A small, actionable list DERIVED CLIENT-SIDE from data already present on
  the dashboard payload (staff attendance today, engagement "sepi" count,
  lowest-class attendance) — no extra endpoint. The parent view computes
  the `items` array; this component is purely presentational.

  Rows are ordered by severity (critical → warning → info) by the parent.
  When the list is empty the card degrades to a single positive
  "Semua aman" row so the panel never renders blank.

  Each row: colored icon dot + bold title + subtitle + chevron. Clicking a
  row routes to its `route` (when present). Styling mirrors the mockup's
  warm-state card conventions using the existing light-theme tokens.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import NavIcon from '@/components/feature/NavIcon.vue';

/** Severity drives ordering (parent-sorted) + the row/dot colour. */
export type AttentionSeverity = 'critical' | 'warning' | 'info';

export interface AttentionItem {
  /** Stable v-for key. */
  key: string;
  severity: AttentionSeverity;
  /** NavIcon name for the leading dot. */
  icon: string;
  /** Bold headline line. */
  title: string;
  /** Muted subtitle line. */
  subtitle: string;
  /** Optional destination — row is a button when set, static row otherwise. */
  route?: string;
}

const props = defineProps<{
  items: AttentionItem[];
}>();

const { t } = useI18n();
const router = useRouter();

const hasItems = computed(() => props.items.length > 0);

// Static Tailwind lookups (JIT-safe literals) per severity.
const ROW_CLASS: Record<AttentionSeverity, string> = {
  critical: 'bg-red-50 border-red-200',
  warning: 'bg-amber-50 border-amber-200',
  info: 'bg-slate-50 border-slate-200',
};
const DOT_CLASS: Record<AttentionSeverity, string> = {
  critical: 'bg-red-100 text-red-600',
  warning: 'bg-amber-100 text-amber-600',
  info: 'bg-blue-50 text-blue-600',
};

function goto(item: AttentionItem) {
  if (item.route) router.push(item.route);
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
          {{ hasItems ? t('admin.dashboard.attention.count', { n: items.length }) : t('admin.dashboard.attention.allClearEyebrow') }}
        </p>
        <h3 class="text-sm font-black text-slate-900 leading-none mt-0.5">
          {{ t('admin.dashboard.needsAttention') }}
        </h3>
      </div>
    </header>

    <div class="flex flex-col gap-2">
      <!-- Actionable rows -->
      <component
        :is="item.route ? 'button' : 'div'"
        v-for="item in items"
        :key="item.key"
        :type="item.route ? 'button' : undefined"
        class="w-full flex items-start gap-2.5 p-2.5 rounded-xl border text-left transition-colors"
        :class="[ROW_CLASS[item.severity], item.route ? 'hover:brightness-95 cursor-pointer' : '']"
        @click="goto(item)"
      >
        <span
          class="w-7 h-7 rounded-lg grid place-items-center flex-shrink-0"
          :class="DOT_CLASS[item.severity]"
        >
          <NavIcon :name="item.icon" :size="14" />
        </span>
        <span class="min-w-0 flex-1">
          <span class="block text-xs font-bold text-slate-900 leading-tight">{{ item.title }}</span>
          <span class="block text-3xs text-slate-500 leading-tight mt-0.5">{{ item.subtitle }}</span>
        </span>
        <NavIcon
          v-if="item.route"
          name="chevron-right"
          :size="14"
          class="text-slate-400 self-center flex-shrink-0"
        />
      </component>

      <!-- All-clear fallback -->
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
    </div>
  </section>
</template>
