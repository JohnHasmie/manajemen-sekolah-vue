<!--
  AdminBadgeTile.vue — badge card for /admin/readiness "Pencapaian" grid.

  Sibling of `feature/gamification/BadgeTile.vue` — the teacher tile has
  an inline CATALOG map keyed by teacher badge codes (beruntun_10, wali_
  tuntas, …). Admin badges are a distinct code set (admin_*) with
  server-served label + description, so extending the teacher map would
  couple two unrelated hubs and risk regressing the teacher gallery on
  a copy edit. Kept as a small sibling instead.

  Three states, same visual language as the teacher tile:
    · earned — cobalt-tinted border + brand icon
    · new    — amber gradient + "Baru!" ribbon (48h window on the server)
    · locked — slate wash + lock icon + muted copy

  Label + description come from the payload's `catalog[i]` entry so the
  backend owns all copy. The per-code icon is picked here (lucide names
  registered in NavIcon.vue) — falls back to `award` for unknown codes
  so new badges rendered before the FE bump don't blank out.
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    /** Badge code — used only for icon lookup. Copy comes from props below. */
    code: string;
    /** Server-localized label — rendered as the tile title. */
    label: string;
    /** Server-localized description — rendered under the title. */
    description: string;
    /** Visual state — same tri-state as BadgeTile.vue. */
    state?: 'earned' | 'new' | 'locked';
  }>(),
  { state: 'locked' },
);

/**
 * Per-code icon mapping. Deliberately here (not on the server) so an
 * admin-side visual tweak stays a web-vue commit; the backend keeps
 * shipping just copy + code. Any code missing from this map falls back
 * to `award` — a lucide trophy-adjacent glyph that reads as a generic
 * achievement, so new server-side badges still render, just without
 * the bespoke cue.
 */
const ICON_BY_CODE: Record<string, string> = {
  admin_foundation_set: 'landmark',
  admin_all_teachers_ready: 'user-check',
  admin_students_placed: 'graduation-cap',
  admin_schedule_full: 'calendar-check',
  admin_school_ready: 'sparkles',
  admin_steward_streak_30: 'flame',
  admin_clean_house_7: 'wind',
};

const iconName = computed(() => ICON_BY_CODE[props.code] ?? 'award');

const toneClasses = computed(() => {
  switch (props.state) {
    case 'earned':
      return 'bg-white border-brand-cobalt/40 shadow-md';
    case 'new':
      return 'bg-gradient-to-br from-amber-50 to-orange-50 border-amber-300 shadow-md';
    case 'locked':
    default:
      return 'bg-slate-50 border-slate-200';
  }
});

const iconTone = computed(() => {
  switch (props.state) {
    case 'earned':
      return 'bg-brand-cobalt/10 text-brand-cobalt';
    case 'new':
      return 'bg-amber-500/20 text-amber-700';
    case 'locked':
    default:
      return 'bg-slate-200 text-slate-400';
  }
});
</script>

<template>
  <div class="rounded-2xl p-3 border relative" :class="toneClasses">
    <span
      v-if="state === 'new'"
      class="absolute -top-2 -right-2 text-3xs font-black uppercase tracking-widest text-white bg-amber-500 rounded-full px-2 py-0.5 shadow"
    >
      Baru!
    </span>
    <div class="flex items-center gap-2">
      <div
        class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
        :class="iconTone"
      >
        <NavIcon :name="state === 'locked' ? 'lock' : iconName" :size="20" />
      </div>
      <div class="min-w-0">
        <p
          class="text-2xs font-bold leading-tight"
          :class="state === 'locked' ? 'text-slate-400' : 'text-slate-900'"
        >
          {{ label }}
        </p>
      </div>
    </div>
    <p
      class="text-3xs mt-2 leading-tight"
      :class="state === 'locked' ? 'text-slate-400' : 'text-slate-600'"
    >
      {{ description }}
    </p>
  </div>
</template>
