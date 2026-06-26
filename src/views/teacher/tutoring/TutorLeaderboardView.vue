<!--
  TutorLeaderboardView — leaderboard of the classes the tutor teaches.
  Mockup tutor_web_pages_notif_announce_rank frame 3.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useAuthStore } from '@/stores/auth';
import type {
  TutoringGroup,
  TutoringLeaderboardRow,
} from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';

const { t } = useI18n();
const auth = useAuthStore();

const loading = ref(true);
const groups = ref<TutoringGroup[]>([]);
const selectedGroupId = ref<string>('');
const rows = ref<TutoringLeaderboardRow[]>([]);

async function loadGroups() {
  try {
    const all = await TutoringService.getAllGroups();
    groups.value = all.filter((g) => g.tutor_user_id === auth.user?.id);
    if (!selectedGroupId.value && groups.value[0]) {
      selectedGroupId.value = groups.value[0].id;
    }
  } catch {/* non-fatal */}
}

async function loadBoard() {
  if (!selectedGroupId.value) { rows.value = []; loading.value = false; return; }
  loading.value = true;
  try { rows.value = await TutoringService.getGroupLeaderboard(selectedGroupId.value, { limit: 30 }); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}

onMounted(async () => { await loadGroups(); await loadBoard(); });
watch(selectedGroupId, loadBoard);

const summary = computed(() => {
  const n = rows.value.length;
  const validScores = rows.value.map((r) => r.avg_score).filter((s): s is number => s != null);
  const avg = validScores.length > 0 ? Math.round(validScores.reduce((a, b) => a + b, 0) / validScores.length) : null;
  const validAtt = rows.value.map((r) => r.attendance_rate).filter((s): s is number => s != null);
  const avgAtt = validAtt.length > 0 ? Math.round(validAtt.reduce((a, b) => a + b, 0) / validAtt.length) : null;
  return { count: n, avg, avgAtt };
});

function rankColor(idx: number): string {
  if (idx === 0) return 'text-amber-600 dark:text-amber-400';
  if (idx === 1) return 'text-tutoring-text-mid';
  if (idx === 2) return 'text-orange-700 dark:text-orange-400';
  return 'text-tutoring-text-mid';
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('tutor.bimbel.leaderboard.greeting')"
      :title="t('tutor.bimbel.leaderboard.title')"
      :subtitle="t('tutor.bimbel.leaderboard.subtitle')"
      :stats="[]"
    >
      <template #actions>
        <select
          v-model="selectedGroupId"
          class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[13px] font-semibold text-white"
        >
          <option v-for="g in groups" :key="g.id" :value="g.id" class="text-tutoring-text-hi">{{ g.name }}</option>
        </select>
      </template>
    </TutorHomeHero>

    <div class="grid grid-cols-3 gap-2.5">
      <div class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
        <p class="text-[12px] font-bold uppercase tracking-widest text-tutoring-text-mid">{{ t('tutor.bimbel.leaderboard.kpi_students') }}</p>
        <p class="mt-1 text-[22px] font-extrabold text-tutoring-text-hi">{{ summary.count }}</p>
      </div>
      <div class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
        <p class="text-[12px] font-bold uppercase tracking-widest text-tutoring-text-mid">{{ t('tutor.bimbel.leaderboard.kpi_average') }}</p>
        <p class="mt-1 text-[22px] font-extrabold text-tutoring-text-hi">{{ summary.avg ?? '–' }}</p>
      </div>
      <div class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
        <p class="text-[12px] font-bold uppercase tracking-widest text-tutoring-text-mid">{{ t('tutor.bimbel.leaderboard.kpi_participation') }}</p>
        <p class="mt-1 text-[22px] font-extrabold text-tutoring-text-hi">{{ summary.avgAtt != null ? `${summary.avgAtt}%` : '–' }}</p>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('tutor.bimbel.leaderboard.loading') }}</div>

    <div v-else class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5">
      <div v-if="rows.length === 0" class="py-8 text-center text-sm text-tutoring-text-mid">
        {{ t('tutor.bimbel.leaderboard.empty') }}
      </div>
      <div
        v-for="(r, i) in rows"
        :key="r.student_id"
        class="flex items-center gap-3 border-b border-tutoring-border-soft py-2.5 last:border-b-0"
      >
        <span class="w-7 text-center text-[16px] font-extrabold" :class="rankColor(i)">{{ i + 1 }}</span>
        <div class="min-w-0 flex-1">
          <p class="truncate text-[14px] font-bold text-tutoring-text-hi">{{ r.name }}</p>
          <p class="truncate text-[12px] text-tutoring-text-mid">
            {{ r.attendance_rate != null ? `${r.attendance_rate}% ${t('tutor.bimbel.leaderboard.attendance_suffix')}` : t('tutor.bimbel.leaderboard.attendance_none') }}
          </p>
        </div>
        <span class="text-[15px] font-extrabold text-tutoring-accent">{{ r.avg_score?.toFixed(1) ?? '–' }}</span>
      </div>
    </div>
  </div>
</template>
