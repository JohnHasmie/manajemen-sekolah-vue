<!--
  TutoringHero — compact hero card used at the top of tutoring pages.
  Mirrors Flutter `TutoringHero`. Slot `trailing` is reserved for
  Realtime pill / primary CTA.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

withDefaults(
  defineProps<{
    /** lucide-style icon name accepted by [NavIcon]. */
    icon: string;
    /** ALL-CAPS micro-label (e.g. "SELAMAT DATANG"). */
    greet?: string;
    /** Display title. Markup-free text shown via the default slot. */
    title?: string;
    /** Optional accent-coloured suffix appended to the title. */
    accentName?: string;
    /** Optional sub-line under the title. */
    subtitle?: string;
    /** Role accent token: 'admin' | 'tutor' | 'parent'. */
    accent?: 'admin' | 'tutor' | 'wali';
  }>(),
  { accent: 'admin' },
);
</script>

<template>
  <div
    class="flex items-center gap-3 bg-tutoring-panel border border-tutoring-border-soft rounded-3xl p-4"
  >
    <div
      class="w-10 h-10 rounded-xl grid place-items-center flex-shrink-0"
      :class="{
        'bg-tutoring-accent-dim text-tutoring-accent': accent === 'admin',
        'bg-tutoring-accent-dim text-tutoring-accent': accent === 'tutor',
        'bg-tutoring-accent-dim text-tutoring-accent': accent === 'wali',
      }"
    >
      <NavIcon :name="icon" :size="20" />
    </div>
    <div class="min-w-0 flex-1">
      <p
        v-if="greet"
        class="text-[12px] font-bold text-tutoring-text-lo tracking-widest uppercase"
      >
        {{ greet }}
      </p>
      <h2 class="text-lg sm:text-xl font-extrabold text-tutoring-text-hi tracking-tight">
        <slot>{{ title }}</slot>
        <span
          v-if="accentName"
          :class="{
            'text-tutoring-accent': accent === 'admin',
            'text-tutoring-accent': accent === 'tutor',
            'text-tutoring-accent': accent === 'wali',
          }"
        >
          {{ accentName }}
        </span>
      </h2>
      <p v-if="subtitle" class="text-xs text-tutoring-text-mid mt-0.5">{{ subtitle }}</p>
    </div>
    <div v-if="$slots.trailing" class="flex-shrink-0">
      <slot name="trailing" />
    </div>
  </div>
</template>
