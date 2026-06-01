<!--
  ParentPageHeader.vue — STANDARD header for every parent (wali) page.

  Design contract (kept identical across the parent role for
  consistency):
    • Solid brand-azure background, no gradient.
    • Kicker (uppercase eyebrow) → Title (h1) → Meta paragraph.
    • Built-in inline child-selector pill pair sits top-right, the
      same compact style as the grade screen mock the user approved.
      Auto-hides when the parent has only one linked child.
    • Optional #actions slot for page-specific buttons (filter,
      view toggle…) — those render between the meta line and the
      child chips.
    • Optional #default slot for an extra block stacked below the
      header content (e.g. inline KPI strip or filter chips).

  Props:
    - kicker         — small text above the title.
    - title          — h1 string. Pass without the child name; pass
                       `:interpolate-child="true"` to have the header
                       append ` · {child name}` automatically.
    - meta           — paragraph under the title.
    - interpolateChild — when true (default), appends ` · {name}` to
                       the title when an active child is loaded.

  Usage:
    <ParentPageHeader
      kicker="Akademik · Anak"
      title="Kehadiran"
      :meta="`${classLabel} · ${semesterLabel}`"
    >
      <template #actions>…</template>   // optional
      …extra content stacked below…    // default slot, optional
    </ParentPageHeader>
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useChildPicker } from '@/composables/useChildPicker';

const props = withDefaults(
  defineProps<{
    kicker?: string;
    title: string;
    meta?: string;
    interpolateChild?: boolean;
  }>(),
  {
    interpolateChild: true,
  },
);

const { children, activeChildId, activeChild, setActive } = useChildPicker();

const displayTitle = computed(() => {
  if (!props.interpolateChild) return props.title;
  const name = activeChild()?.name?.trim();
  if (!name) return props.title;
  return `${props.title} · ${name}`;
});
</script>

<template>
  <header
    class="rounded-3xl p-5 sm:p-6 text-white shadow-md"
    style="background-color: #21AFE6"
  >
    <div class="flex items-start gap-4">
      <!-- Left: kicker + title + meta -->
      <div class="flex-1 min-w-0">
        <p
          v-if="kicker"
          class="text-[10px] font-bold tracking-widest uppercase text-white/80 mb-1.5"
        >
          {{ kicker }}
        </p>
        <h1 class="text-xl sm:text-2xl font-black leading-tight truncate">
          {{ displayTitle }}
        </h1>
        <p
          v-if="meta"
          class="text-[12px] font-medium text-white/80 mt-1 truncate"
        >
          {{ meta }}
        </p>
      </div>

      <!-- Right: page-specific actions, then child chip pair -->
      <div class="flex items-center gap-2 flex-shrink-0">
        <slot name="actions" />

        <div
          v-if="children.length > 1"
          role="tablist"
          aria-label="Pilih anak"
          class="inline-flex gap-0.5 bg-slate-900/15 rounded-full p-0.5"
        >
          <button
            v-for="c in children"
            :key="c.student_id"
            type="button"
            role="tab"
            :aria-selected="activeChildId === c.student_id"
            class="text-[11px] font-bold px-2.5 py-1 rounded-full transition-all whitespace-nowrap"
            :class="
              activeChildId === c.student_id
                ? 'bg-white text-slate-900 shadow-sm'
                : 'text-white/85 hover:text-white'
            "
            @click="setActive(c.student_id)"
          >
            {{ c.name }}<span
              v-if="c.class_name"
              class="ml-1 font-bold opacity-70"
            >· {{ c.class_name }}</span>
          </button>
        </div>
      </div>
    </div>

    <!-- Optional extra row (KPI strip, filter chips, etc.) -->
    <div v-if="$slots.default" class="mt-4">
      <slot />
    </div>
  </header>
</template>
