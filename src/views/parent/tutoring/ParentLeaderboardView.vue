<!--
  ParentLeaderboardView — wali leaderboard. Mockup parent_web_pages_extra
  frame 3: 2-col layout: leaderboard rows on left, child summary on right.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type {
  TutoringLeaderboardRow,
  TutoringWaliClassMeta,
} from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';

const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const groups = ref<TutoringWaliClassMeta[]>([]);
const selectedGroupId = ref<string>('');
const rows = ref<TutoringLeaderboardRow[]>([]);

async function loadGroups() {
  const sid = studentId.value;
  if (!sid) return;
  try {
    groups.value = await TutoringService.getWaliClassMeta(sid);
    if (!selectedGroupId.value && groups.value[0]) {
      selectedGroupId.value = groups.value[0].group_id;
    }
  } catch {/* non-fatal */}
}

async function loadBoard() {
  if (!selectedGroupId.value) {
    rows.value = [];
    loading.value = false;
    return;
  }
  loading.value = true;
  try {
    rows.value = await TutoringService.getGroupLeaderboard(selectedGroupId.value, { limit: 30 });
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}

onMounted(async () => {
  await loadGroups();
  await loadBoard();
});
watch(studentId, async () => { await loadGroups(); await loadBoard(); });
watch(selectedGroupId, loadBoard);

const myRow = computed(() => rows.value.find((r) => r.student_id === studentId.value) ?? null);
const myRank = computed(() => {
  const idx = rows.value.findIndex((r) => r.student_id === studentId.value);
  return idx >= 0 ? idx + 1 : null;
});

function rankClass(idx: number): string {
  if (idx === 0) return 'text-amber-600 dark:text-amber-400';
  if (idx === 1) return 'text-bimbel-text-mid';
  if (idx === 2) return 'text-orange-700 dark:text-orange-400';
  return 'text-bimbel-text-mid';
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · PERINGKAT"
      title="Peringkat kelas"
      :subtitle="`${activeChild()?.name ?? 'Anak'} · pilih kelas untuk lihat papan peringkat`"
      :stats="[]"
    >
      <template #actions><ParentChildPickerChip /></template>
    </ParentBerandaHero>

    <div class="flex flex-wrap gap-2">
      <select
        v-model="selectedGroupId"
        class="rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-1.5 text-[12px] text-bimbel-text-hi focus:border-[#21afe6] focus:outline-none"
      >
        <option v-for="g in groups" :key="g.group_id" :value="g.group_id">{{ g.group_name }}</option>
      </select>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else class="grid gap-3 lg:grid-cols-5">
      <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 lg:col-span-3">
        <h4 class="mb-2 text-[12px] font-bold tracking-tight text-bimbel-text-hi">Papan peringkat</h4>
        <div
          v-if="rows.length === 0"
          class="py-6 text-center text-[12px] text-bimbel-text-mid"
        >Belum ada peringkat tercatat.</div>
        <div
          v-for="(r, i) in rows"
          :key="r.student_id"
          class="flex items-center gap-3 border-b border-bimbel-border-soft py-2.5 last:border-b-0"
          :class="{ 'bg-[#21afe6]/10 rounded-xl px-2 -mx-2': r.student_id === studentId }"
        >
          <span class="w-7 text-center text-[15px] font-extrabold" :class="rankClass(i)">{{ i + 1 }}</span>
          <div class="min-w-0 flex-1">
            <p class="truncate text-[13px] font-bold text-bimbel-text-hi">
              {{ r.name }}<span v-if="r.student_id === studentId" class="text-bimbel-text-mid"> (anda)</span>
            </p>
            <p class="truncate text-[12px] text-bimbel-text-mid">
              {{ r.attendance_rate != null ? `${r.attendance_rate}% hadir` : 'belum tercatat' }}
            </p>
          </div>
          <span class="text-[14px] font-extrabold text-bimbel-text-hi">{{ r.avg_score?.toFixed(1) ?? '–' }}</span>
        </div>
      </div>

      <aside class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 lg:col-span-2 h-fit">
        <h4 class="mb-3 text-[12px] font-bold tracking-tight text-bimbel-text-hi">Detail anak</h4>
        <p class="text-[12px] text-bimbel-text-mid">
          {{ activeChild()?.name ?? 'Anak' }} di {{ groups.find((g) => g.group_id === selectedGroupId)?.group_name ?? 'kelas' }}
        </p>
        <div class="mt-3 grid grid-cols-2 gap-2">
          <div class="rounded-xl bg-bimbel-bg/40 p-3">
            <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">PERINGKAT</p>
            <p class="mt-1 text-xl font-extrabold text-bimbel-text-hi">
              {{ myRank != null ? `${myRank} / ${rows.length}` : '—' }}
            </p>
          </div>
          <div class="rounded-xl bg-bimbel-bg/40 p-3">
            <p class="text-[12px] font-bold uppercase tracking-widest text-bimbel-text-mid">SKOR</p>
            <p class="mt-1 text-xl font-extrabold text-bimbel-text-hi">
              {{ myRow?.avg_score != null ? myRow.avg_score.toFixed(1) : '—' }}
            </p>
          </div>
        </div>
      </aside>
    </div>
  </div>
</template>
