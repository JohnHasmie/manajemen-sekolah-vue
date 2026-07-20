<!--
  LeaderboardRow.vue — one entry in the peringkat table.
  When `you=true` the row is highlighted with a cobalt tint + left
  border, so the teacher's own position is easy to spot even if
  they're on page 2.
-->
<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';
import type { LeaderboardEntry } from '@/services/teacher-progress.service';

defineProps<{
  entry: LeaderboardEntry;
}>();

function initials(name: string): string {
  return name
    .split(/\s+/)
    .map((s) => s[0]?.toUpperCase() ?? '')
    .slice(0, 2)
    .join('');
}
</script>

<template>
  <div
    class="flex items-center gap-3 py-2.5 pr-2 pl-3 rounded-xl border-l-4 border-transparent"
    :class="entry.you
      ? 'bg-brand-cobalt/5 border-brand-cobalt'
      : 'bg-white hover:bg-slate-50'"
  >
    <!-- Rank -->
    <p
      class="w-8 text-sm font-black text-center flex-shrink-0"
      :class="entry.position === 1
        ? 'text-amber-500'
        : entry.position === 2
          ? 'text-slate-500'
          : entry.position === 3
            ? 'text-orange-500'
            : 'text-slate-400'"
    >
      #{{ entry.position }}
    </p>
    <!-- Avatar -->
    <div
      class="w-10 h-10 rounded-full grid place-items-center flex-shrink-0 overflow-hidden"
      :class="entry.photo_url
        ? 'bg-slate-100'
        : 'bg-brand-cobalt/10 text-brand-cobalt text-xs font-black'"
    >
      <img
        v-if="entry.photo_url"
        :src="entry.photo_url"
        :alt="entry.name"
        class="w-full h-full object-cover"
      />
      <span v-else>{{ initials(entry.name) }}</span>
    </div>
    <!-- Name + streak (staff cohort: role-tag chip inline with the name) -->
    <div class="min-w-0 flex-1">
      <div class="flex items-center gap-2 min-w-0">
        <p class="text-sm font-bold text-slate-900 truncate">
          {{ entry.name }}<span v-if="entry.you" class="ml-1 text-2xs font-bold text-brand-cobalt">(kamu)</span>
        </p>
        <!-- Staff MR13: peran chip. Only present on staff cohort rows;
             derived server-side from ability intersection so a viewer
             sees the same tag ("Bendahara" / "Tata Usaha" / "Kehadiran")
             on this row that Admin Prestasi Staf shows in its table. -->
        <span
          v-if="entry.ability_role_tag"
          class="flex-shrink-0 text-3xs font-black uppercase tracking-wider px-1.5 py-0.5 rounded-full"
          :class="{
            'bg-emerald-100 text-emerald-800': entry.ability_role_tag === 'Bendahara',
            'bg-sky-100 text-sky-800': entry.ability_role_tag === 'Tata Usaha',
            'bg-slate-100 text-slate-600': entry.ability_role_tag === 'Kehadiran',
          }"
        >
          {{ entry.ability_role_tag }}
        </span>
      </div>
      <p class="text-3xs text-slate-500 mt-0.5 flex items-center gap-2">
        <span class="flex items-center gap-1">
          <NavIcon name="flame" :size="12" />
          {{ entry.streak_days }} hari
        </span>
        <span>·</span>
        <span>L{{ entry.level }}</span>
        <span v-if="entry.badge_count > 0">·</span>
        <span v-if="entry.badge_count > 0" class="flex items-center gap-1">
          <NavIcon name="medal" :size="12" />
          {{ entry.badge_count }}
        </span>
      </p>
    </div>
    <!-- Points -->
    <p class="text-sm font-black text-slate-900 flex-shrink-0">
      {{ entry.points }}<span class="text-3xs text-slate-500 font-bold ml-1">XP</span>
    </p>
  </div>
</template>
