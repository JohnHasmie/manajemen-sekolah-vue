<!--
  ParentMoreView — wali "Lainnya" hub. Three sections (AKADEMIK ANAK /
  DAFTAR & PROMO / AKUN) each rendered as a 3-up tile grid. Each tile is
  a bimbel-panel button with colored icon box, label, and sub. Routes
  preserved via go(name).
-->
<script setup lang="ts">
import { useRouter } from 'vue-router';
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useChildPicker } from '@/composables/useChildPicker';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const { children, activeChildId, setActive } = useChildPicker();

const childId = computed(() => activeChildId.value);

function initials(name?: string | null): string {
  if (!name) return '?';
  return name
    .split(/\s+/)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase() ?? '')
    .join('');
}

// Cycle a small palette so multi-child rows aren't all the same hue.
const CHIP_RAMP = [
  'bg-bimbel-accent-dim text-bimbel-hero',
  'bg-bimbel-green-dim text-green-700',
  'bg-bimbel-amber-dim text-amber-700',
  'bg-bimbel-red-dim text-red-700',
];
function chipClass(i: number): string {
  return CHIP_RAMP[i % CHIP_RAMP.length];
}

function pickChild(id: string) {
  setActive(id);
  router.push({ name: 'parent.tutoring.overview', params: { studentId: id } });
}

interface Tile {
  label: string;
  sub: string;
  icon: string;
  iconCls?: string;
  route: string;
}

const academic = computed<Tile[]>(() => [
  { label: t('wali.bimbel.more.tile_progress_label'), sub: t('wali.bimbel.more.tile_progress_sub'), icon: 'chart-bar', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero', route: 'parent.tutoring.progress' },
  { label: t('wali.bimbel.more.tile_leaderboard_label'), sub: t('wali.bimbel.more.tile_leaderboard_sub'), icon: 'star', iconCls: 'bg-bimbel-amber-dim text-amber-700', route: 'parent.tutoring.leaderboard' },
  { label: t('wali.bimbel.more.tile_activities_label'), sub: t('wali.bimbel.more.tile_activities_sub'), icon: 'book', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero', route: 'parent.tutoring.activities' },
]);

const funnel = computed<Tile[]>(() => [
  { label: t('wali.bimbel.more.tile_vouchers_label'), sub: t('wali.bimbel.more.tile_vouchers_sub'), icon: 'discount', iconCls: 'bg-bimbel-red-dim text-red-700', route: 'parent.tutoring.vouchers' },
  { label: t('wali.bimbel.more.tile_register_lead_label'), sub: t('wali.bimbel.more.tile_register_lead_sub'), icon: 'user-plus', iconCls: 'bg-bimbel-green-dim text-green-700', route: 'parent.tutoring.register-lead' },
  { label: t('wali.bimbel.more.tile_enroll_program_label'), sub: t('wali.bimbel.more.tile_enroll_program_sub'), icon: 'package', iconCls: 'bg-bimbel-accent-dim text-bimbel-hero', route: 'parent.tutoring.enroll-new' },
]);

const account = computed<Tile[]>(() => [
  { label: t('wali.bimbel.more.tile_notifications_label'), sub: t('wali.bimbel.more.tile_notifications_sub'), icon: 'bell', route: 'parent.tutoring.notifications' },
  { label: t('wali.bimbel.more.tile_profile_label'), sub: t('wali.bimbel.more.tile_profile_sub'), icon: 'user', route: 'parent.tutoring.profile' },
  { label: t('wali.bimbel.more.tile_appearance_label'), sub: t('wali.bimbel.more.tile_appearance_sub'), icon: 'sun', route: 'parent.tutoring.appearance' },
]);

function go(name: string) {
  const params = childId.value ? { studentId: childId.value } : undefined;
  router.push({ name, params });
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      :kicker="t('wali.bimbel.more.kicker')"
      :title="t('wali.bimbel.more.title')"
      :subtitle="t('wali.bimbel.more.subtitle')"
      :stats="[]"
    />

    <!-- ANAK SAYA — quick switch row, mirrors mobile parent_more_hub -->
    <template v-if="children.length > 0">
      <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
        {{ t('wali.bimbel.more.my_children_heading') }}
      </p>
      <div class="grid gap-2" :class="children.length > 1 ? 'sm:grid-cols-2' : 'grid-cols-1'">
        <button
          v-for="(c, i) in children"
          :key="c.student_id"
          type="button"
          class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-3 flex items-center gap-2.5 text-left transition-colors"
          :class="c.student_id === activeChildId ? 'border-bimbel-hero ring-1 ring-bimbel-hero/30' : 'hover:border-bimbel-border'"
          @click="pickChild(c.student_id)"
        >
          <span
            class="w-9 h-9 rounded-full grid place-items-center text-[13px] font-bold flex-shrink-0"
            :class="chipClass(i)"
          >{{ initials(c.name) }}</span>
          <div class="min-w-0 flex-1">
            <p class="text-[14px] font-bold text-bimbel-text-hi truncate">{{ c.name }}</p>
            <p class="text-[12px] text-bimbel-text-mid truncate">{{ c.class_name || t('wali.bimbel.more.default_class_name') }}</p>
          </div>
          <span
            v-if="c.student_id === activeChildId"
            class="text-[10px] font-bold uppercase tracking-wider text-bimbel-hero flex-shrink-0"
          >{{ t('wali.bimbel.more.active_badge') }}</span>
          <NavIcon v-else name="chevron-right" :size="14" class="text-bimbel-text-mid flex-shrink-0" />
        </button>
      </div>
    </template>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
      {{ t('wali.bimbel.more.academic_heading') }}
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="tile in academic"
        :key="tile.label"
        type="button"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3.5 text-center"
        @click="go(tile.route)"
      >
        <div class="w-[38px] h-[38px] rounded-lg mx-auto mb-1.5 grid place-items-center" :class="tile.iconCls">
          <NavIcon :name="tile.icon" :size="18" />
        </div>
        <p class="text-[13px] font-bold text-bimbel-text-hi">{{ tile.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ tile.sub }}</p>
      </button>
    </div>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      {{ t('wali.bimbel.more.funnel_heading') }}
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="tile in funnel"
        :key="tile.label"
        type="button"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3.5 text-center"
        @click="go(tile.route)"
      >
        <div class="w-[38px] h-[38px] rounded-lg mx-auto mb-1.5 grid place-items-center" :class="tile.iconCls">
          <NavIcon :name="tile.icon" :size="18" />
        </div>
        <p class="text-[13px] font-bold text-bimbel-text-hi">{{ tile.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ tile.sub }}</p>
      </button>
    </div>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      {{ t('wali.bimbel.more.account_heading') }}
    </p>
    <div class="grid grid-cols-3 gap-2">
      <button
        v-for="tile in account"
        :key="tile.label"
        type="button"
        class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-3.5 text-center"
        @click="go(tile.route)"
      >
        <div class="w-[38px] h-[38px] rounded-lg mx-auto mb-1.5 grid place-items-center bg-bimbel-bg text-bimbel-text-hi">
          <NavIcon :name="tile.icon" :size="18" />
        </div>
        <p class="text-[13px] font-bold text-bimbel-text-hi">{{ tile.label }}</p>
        <p class="text-[10px] text-bimbel-text-mid mt-0.5">{{ tile.sub }}</p>
      </button>
    </div>
  </div>
</template>
