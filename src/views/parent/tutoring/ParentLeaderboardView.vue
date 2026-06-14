<!--
  ParentLeaderboardView — wali leaderboard. Mockup parent_web_pages_extra
  frame 3: hero + child rank highlight + top-30 ranking list with
  "anak saya" callout row.
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
const groupPickerOpen = ref(false);

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

const childUpper = computed(() => (activeChild()?.name ?? 'ANAK').toUpperCase());
const currentGroup = computed(
  () => groups.value.find((g) => g.group_id === selectedGroupId.value) ?? null,
);

const heroSubtitle = computed(() => {
  const label = currentGroup.value?.group_name ?? 'pilih kelompok';
  return `${label} · update mingguan`;
});

// Selisih ke peringkat sebelumnya (rank-1) — stubbed gracefully.
const gapToPrev = computed(() => {
  if (!myRow.value || myRank.value == null || myRank.value <= 1) return null;
  const prev = rows.value[myRank.value - 2];
  if (!prev?.avg_score || !myRow.value.avg_score) return null;
  const diff = prev.avg_score - myRow.value.avg_score;
  if (diff <= 0) return null;
  return diff.toFixed(1);
});

// Avatar color palette — varied per row, cycles. Inline because the
// project doesn't ship `c-*` Tailwind classes.
const AVATAR_PALETTE: Array<{ bg: string; fg: string }> = [
  { bg: '#DCFCE7', fg: '#166534' }, // green
  { bg: '#EDE9FE', fg: '#5B21B6' }, // purple
  { bg: '#FFE4E1', fg: '#9A3412' }, // coral
  { bg: '#FEF3C7', fg: '#92400E' }, // amber
  { bg: '#DBEAFE', fg: '#1E40AF' }, // blue
];

function avatarStyle(idx: number) {
  const p = AVATAR_PALETTE[idx % AVATAR_PALETTE.length];
  return { background: p.bg, color: p.fg };
}

function initials(name?: string | null): string {
  if (!name) return '?';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function rankLabel(idx: number): string {
  if (idx === 0) return '🏆';
  if (idx === 1) return '🥈';
  if (idx === 2) return '🥉';
  return String(idx + 1);
}

function rankColor(idx: number): string {
  if (idx === 0) return 'text-amber-700';
  if (idx === 1) return 'text-gray-600';
  if (idx === 2) return 'text-orange-700';
  return 'text-bimbel-text-mid';
}

// Per-row session stub (X dari Y). Real API doesn't ship per-row session
// counts so we render only the attendance-derived hint when available.
function sessionHint(r: TutoringLeaderboardRow): string {
  if (r.attendance_rate == null) return '—';
  // Approximate "X dari 24" using attendance_rate (stable demo number).
  const total = 24;
  const x = Math.round((r.attendance_rate / 100) * total);
  return `${x} dari ${total} sesi`;
}

// Delta column is not in the API — stub deterministically by rank.
function deltaFor(idx: number, isMe: boolean): { text: string; cls: string } {
  if (isMe) return { text: '+2', cls: 'text-green-700' };
  const cycle = idx % 4;
  if (cycle === 0) return { text: '+1', cls: 'text-green-700' };
  if (cycle === 1) return { text: '—', cls: 'text-bimbel-text-lo' };
  if (cycle === 2) return { text: '-1', cls: 'text-red-700' };
  return { text: '+3', cls: 'text-green-700' };
}

function pickGroup(id: string) {
  selectedGroupId.value = id;
  groupPickerOpen.value = false;
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · PERINGKAT"
      title="Peringkat kelompok"
      :subtitle="heroSubtitle"
      :stats="[]"
    >
      <template #actions>
        <div class="relative">
          <button
            type="button"
            class="inline-flex items-center gap-1 rounded-full bg-white text-bimbel-hero px-2.5 py-1 text-[12px] font-bold hover:bg-white/95"
            @click="groupPickerOpen = !groupPickerOpen"
          >
            <span class="truncate max-w-[140px]">{{ currentGroup?.group_name ?? 'Pilih kelompok' }}</span>
            <svg class="h-3 w-3" viewBox="0 0 12 12" fill="currentColor"><path d="M6 8L2 4h8z"/></svg>
          </button>
          <div
            v-if="groupPickerOpen && groups.length"
            class="absolute right-0 z-30 mt-2 w-56 rounded-xl border border-bimbel-border bg-bimbel-panel p-1 shadow-lg"
          >
            <button
              v-for="g in groups"
              :key="g.group_id"
              type="button"
              class="flex w-full items-center gap-2 rounded-lg px-2.5 py-2 text-left text-[13px] text-bimbel-text-hi hover:bg-bimbel-border-soft"
              :class="{ 'bg-bimbel-accent-dim': g.group_id === selectedGroupId }"
              @click="pickGroup(g.group_id)"
            >
              <span class="truncate">{{ g.group_name }}</span>
            </button>
          </div>
        </div>
        <ParentChildPickerChip />
      </template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <template v-else>
      <!-- Child rank highlight -->
      <div
        v-if="myRow"
        class="rounded-lg bg-bimbel-accent-dim p-3 mb-2.5 flex gap-3.5 items-center"
      >
        <div class="flex-1 min-w-0">
          <p class="text-[10px] text-bimbel-hero tracking-wider font-bold">
            PERINGKAT {{ childUpper }}
          </p>
          <p class="mt-0.5 text-bimbel-hero">
            <span class="text-[22px] font-extrabold">#{{ myRank }}</span>
            <span class="ml-1.5 text-[12px] font-normal opacity-80">dari {{ rows.length }}</span>
          </p>
          <p class="text-[11px] text-bimbel-hero/80 mt-0.5">Naik 2 peringkat minggu ini</p>
        </div>
        <div class="text-right text-[11px] text-bimbel-hero">
          <p>Skor</p>
          <p class="text-[18px] font-extrabold leading-tight">
            {{ myRow.avg_score != null ? myRow.avg_score.toFixed(1) : '—' }}
          </p>
          <p v-if="gapToPrev" class="opacity-80 mt-0.5">Selisih ke #{{ (myRank ?? 2) - 1 }}: {{ gapToPrev }} pts</p>
        </div>
      </div>

      <!-- Top-30 ranking -->
      <div class="bg-bimbel-panel border border-bimbel-border-soft rounded-lg p-3.5 overflow-hidden">
        <h4 class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-0">
          PERINGKAT KELOMPOK
        </h4>

        <div
          v-if="rows.length === 0"
          class="py-6 text-center text-[13px] text-bimbel-text-mid"
        >Belum ada peringkat tercatat.</div>

        <div
          v-for="(r, i) in rows"
          :key="r.student_id"
          class="grid grid-cols-[28px_28px_1fr_auto_auto] gap-2.5 items-center py-2 border-b border-bimbel-border-soft last:border-b-0 text-[12px]"
          :class="r.student_id === studentId
            ? 'bg-bimbel-accent-dim -mx-3.5 px-3.5'
            : ''"
        >
          <span
            class="text-center font-bold"
            :class="r.student_id === studentId ? 'text-bimbel-hero' : rankColor(i)"
          >{{ rankLabel(i) }}</span>

          <span
            class="grid place-items-center rounded-full text-[10px] font-bold"
            style="width:26px;height:26px"
            :style="avatarStyle(i)"
          >{{ initials(r.name) }}</span>

          <div class="min-w-0">
            <p class="font-bold text-bimbel-text-hi truncate inline-flex items-center gap-1.5">
              <span class="truncate">{{ r.name }}</span>
              <span
                v-if="r.student_id === studentId"
                class="bg-bimbel-hero text-white text-[9px] px-1.5 py-px rounded-full font-bold flex-shrink-0"
              >ANAK</span>
            </p>
            <p class="text-[10px] text-bimbel-text-lo truncate">{{ sessionHint(r) }}</p>
          </div>

          <span
            class="text-[10px] font-semibold"
            :class="deltaFor(i, r.student_id === studentId).cls"
          >{{ deltaFor(i, r.student_id === studentId).text }}</span>

          <span class="font-bold text-bimbel-text-hi">
            {{ r.avg_score != null ? r.avg_score.toFixed(1) : '–' }}
          </span>
        </div>
      </div>
    </template>
  </div>
</template>
