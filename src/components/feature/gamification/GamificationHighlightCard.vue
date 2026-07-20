<!--
  GamificationHighlightCard.vue — the gamification highlight hero card
  that lands at the top of the guru dashboard (and the compact variant
  on admin).

  Backend picks ONE `state` per day; this component picks the palette
  + icon + mini-badge tone from the state, and renders the shared
  layout (icon left · text center · CTA right + 3 tiny meta chips
  below on the guru variant).

  Six states supported for guru:
    new_badge         gold / orange
    level_up          cobalt / blue
    streak_milestone  red / orange
    top_rank          violet / pink
    positive_delta    green / emerald
    welcome           cobalt / navy

  Plus four admin-only variants — role-palette anchored per `useRoleColor`:
    teacher_of_month        cobalt (role-teacher) / navy
    needs_attention         amber / orange (warning tone, role-agnostic)
    staff_of_month          amber (role-staff) / amber-900
    staff_needs_attention   amber / orange (warning tone, role-agnostic)
-->
<script setup lang="ts">
import { computed } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = withDefaults(
  defineProps<{
    state: string;
    eyebrow?: string;
    /** Backend-generated, may contain `<b>...</b>` — rendered with v-html. */
    title: string;
    sub?: string;
    miniBadge?: string | null;
    ctaLabel: string;
    ctaTarget: string;
    /** Guru variant only — 3 chips (level, streak, badge count) below the card. */
    meta?: { level: number; streak: number; badge_count: number } | null;
    /** Compact mode used on Flutter dashboard teaser + admin dashboard tile. */
    compact?: boolean;
  }>(),
  { eyebrow: '', sub: '', miniBadge: null, meta: null, compact: false },
);

const emit = defineEmits<{
  (e: 'cta'): void;
}>();

const stateMeta = computed<{ gradient: string; icon: string; miniBadgeTone: string }>(() => {
  switch (props.state) {
    case 'new_badge':
      return {
        gradient: 'from-amber-500 to-orange-600',
        icon: 'trophy',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'level_up':
      return {
        gradient: 'from-brand-cobalt to-blue-700',
        icon: 'trending-up',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'streak_milestone':
      return {
        gradient: 'from-red-500 to-orange-600',
        icon: 'flame',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'top_rank':
      return {
        gradient: 'from-violet-600 to-pink-600',
        icon: 'medal',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'positive_delta':
      return {
        gradient: 'from-emerald-500 to-green-700',
        icon: 'trending-up',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'welcome':
      return {
        gradient: 'from-brand-cobalt to-slate-800',
        icon: 'sparkles',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'teacher_of_month':
      // Role palette: teacher = cobalt (#1B6FB8 from useRoleColor).
      // Pair with navy tail so the card reads as "school-officialTeacher
      // moment", not the generic ambient cobalt used elsewhere.
      return {
        gradient: 'from-role-teacher to-slate-800',
        icon: 'trophy',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'needs_attention':
      return {
        gradient: 'from-amber-500 to-orange-600',
        icon: 'bell',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    // Staff variants — cobalt palette so the surface visually
    // pairs with the teacher variants (violet + amber) without
    // colliding. Icon-wise we use `briefcase` for the champion
    // card to lean into the operational nature of staff work.
    case 'staff_of_month':
      // Role palette: staff = amber (#B45309 from useRoleColor).
      // Pair with a darker brown-red tail so the amber reads warm +
      // grounded, not fluorescent — matches the staff shell accent.
      return {
        gradient: 'from-role-staff to-amber-900',
        icon: 'briefcase',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    case 'staff_needs_attention':
      return {
        gradient: 'from-amber-500 to-orange-600',
        icon: 'bell',
        miniBadgeTone: 'bg-white/25 text-white',
      };
    default:
      return {
        gradient: 'from-slate-600 to-slate-800',
        icon: 'sparkles',
        miniBadgeTone: 'bg-white/25 text-white',
      };
  }
});
</script>

<template>
  <section
    class="rounded-3xl text-white shadow-xl relative overflow-hidden"
    :class="[
      compact ? 'p-4' : 'p-6',
      `bg-gradient-to-br ${stateMeta.gradient}`,
    ]"
  >
    <!-- Ambient blob for depth. -->
    <div class="absolute -top-12 -right-12 w-44 h-44 bg-white/10 rounded-full blur-3xl"></div>

    <div class="relative z-10 flex items-center gap-4">
      <!-- Icon -->
      <div
        class="w-12 h-12 rounded-2xl bg-white/20 grid place-items-center flex-shrink-0"
        :class="{ 'w-14 h-14 rounded-3xl': !compact }"
      >
        <NavIcon :name="stateMeta.icon" :size="compact ? 22 : 26" />
      </div>

      <!-- Middle text -->
      <div class="min-w-0 flex-1">
        <div class="flex items-center gap-2">
          <p
            v-if="eyebrow"
            class="text-3xs sm:text-2xs font-bold text-white/70 uppercase tracking-widest leading-none truncate"
          >
            {{ eyebrow }}
          </p>
          <span
            v-if="miniBadge"
            class="text-3xs font-black uppercase tracking-wider px-2 py-0.5 rounded-full"
            :class="stateMeta.miniBadgeTone"
          >
            {{ miniBadge }}
          </span>
        </div>
        <h2
          class="font-black leading-snug mt-1"
          :class="compact ? 'text-sm' : 'text-base sm:text-lg'"
          v-html="title"
        ></h2>
        <p
          v-if="sub"
          class="text-xs sm:text-sm text-white/80 mt-1 leading-tight line-clamp-2"
        >
          {{ sub }}
        </p>
      </div>

      <!-- CTA -->
      <button
        type="button"
        class="flex-shrink-0 rounded-xl bg-white/25 hover:bg-white/35 transition text-white text-xs font-bold px-3 py-2"
        @click="emit('cta')"
      >
        {{ ctaLabel }}
      </button>
    </div>

    <!-- 3 tiny meta chips (guru variant only). -->
    <div
      v-if="meta && !compact"
      class="relative z-10 mt-4 grid grid-cols-3 gap-2"
    >
      <div class="bg-white/15 rounded-xl px-3 py-2 text-white">
        <p class="text-4xs font-bold text-white/70 uppercase tracking-widest">Level</p>
        <p class="text-sm font-black mt-0.5">{{ meta.level }}</p>
      </div>
      <div class="bg-white/15 rounded-xl px-3 py-2 text-white">
        <p class="text-4xs font-bold text-white/70 uppercase tracking-widest">Streak</p>
        <p class="text-sm font-black mt-0.5">{{ meta.streak }} hari</p>
      </div>
      <div class="bg-white/15 rounded-xl px-3 py-2 text-white">
        <p class="text-4xs font-bold text-white/70 uppercase tracking-widest">Badge</p>
        <p class="text-sm font-black mt-0.5">{{ meta.badge_count }}</p>
      </div>
    </div>
  </section>
</template>
