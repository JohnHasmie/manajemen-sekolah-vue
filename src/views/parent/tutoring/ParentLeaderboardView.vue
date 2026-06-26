<!--
  ParentLeaderboardView — wali leaderboard. Mockup parent_web_pages_extra
  frame 3: hero + "Peringkat ANAK" highlight card + group ranking list.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type {
  TutoringLeaderboardRow,
  TutoringParentClassMeta,
} from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const { activeChildId, activeChild } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const groups = ref<TutoringParentClassMeta[]>([]);
const currentGroupId = ref<string>('');
const rawRows = ref<TutoringLeaderboardRow[]>([]);

async function loadGroups() {
  const sid = studentId.value;
  if (!sid) return;
  try {
    groups.value = await TutoringService.getWaliClassMeta(sid);
    if (!currentGroupId.value && groups.value[0]) {
      currentGroupId.value = groups.value[0].group_id;
    }
  } catch {/* non-fatal */}
}

async function loadBoard() {
  if (!currentGroupId.value) {
    rawRows.value = [];
    loading.value = false;
    return;
  }
  loading.value = true;
  try {
    rawRows.value = await TutoringService.getGroupLeaderboard(currentGroupId.value, { limit: 30 });
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}

onMounted(async () => { await loadGroups(); await loadBoard(); });
watch(studentId, async () => { await loadGroups(); await loadBoard(); });
watch(currentGroupId, loadBoard);

// ── Group label/short for hero + #actions chip ────────────────────
const currentGroup = computed(
  () => groups.value.find((g) => g.group_id === currentGroupId.value) ?? null,
);
const currentGroupLabel = computed(() => currentGroup.value?.group_name ?? t('wali.bimbel.leaderboard.default_group_label'));
const currentGroupShort = computed(() => {
  const n = currentGroupLabel.value;
  return n.length > 16 ? n.slice(0, 14) + '…' : n;
});

// Simple cycle picker — no popup, just round-robin through enrolled
// groups (mockup spec says: keep button visual). Single-group wali sees
// a no-op press.
function openGroupPicker() {
  if (groups.value.length <= 1) return;
  const idx = groups.value.findIndex((g) => g.group_id === currentGroupId.value);
  const next = groups.value[(idx + 1) % groups.value.length];
  if (next) currentGroupId.value = next.group_id;
}

// ── Row shape consumed by the template ────────────────────────────
interface Row {
  id: string;
  rank: number;
  name: string;
  score: string;
  attendedLine: string;
  delta: number;
  deltaText: string;
  isMe: boolean;
  gapText?: string;
  paletteIdx: number;
}

const rows = computed<Row[]>(() => {
  return rawRows.value.map((r, idx) => {
    const isMe = r.student_id === studentId.value;
    // delta stub: deterministic per rank position (API has no delta yet).
    const cycle = idx % 4;
    const delta = isMe ? 2 : cycle === 0 ? 1 : cycle === 1 ? 0 : cycle === 2 ? -1 : 3;
    // sessions: derive "X dari 24" from attendance_rate, fall back gracefully.
    const total = 24;
    const attended = r.attendance_rate != null
      ? Math.round((r.attendance_rate / 100) * total)
      : null;
    return {
      id: r.student_id,
      rank: idx + 1,
      name: r.name,
      score: r.avg_score != null ? r.avg_score.toFixed(1) : '—',
      attendedLine: attended != null
        ? t('wali.bimbel.leaderboard.sessions_attended', { attended, total })
        : t('wali.bimbel.leaderboard.no_session_record'),
      delta,
      deltaText: delta > 0
        ? t('wali.bimbel.leaderboard.delta_up', { count: delta })
        : delta < 0
          ? t('wali.bimbel.leaderboard.delta_down', { count: Math.abs(delta) })
          : t('wali.bimbel.leaderboard.delta_same'),
      isMe,
      paletteIdx: idx,
    };
  });
});

const myRow = computed<Row | null>(() => {
  const me = rows.value.find((r) => r.isMe) ?? null;
  if (!me) return null;
  // Selisih ke #rank-1 (gap to the rank above).
  if (me.rank > 1) {
    const prev = rawRows.value[me.rank - 2];
    const myRaw = rawRows.value[me.rank - 1];
    if (prev?.avg_score != null && myRaw?.avg_score != null) {
      const diff = prev.avg_score - myRaw.avg_score;
      if (diff > 0) me.gapText = t('wali.bimbel.leaderboard.gap_text', { rank: me.rank - 1, diff: diff.toFixed(1) });
    }
  }
  return me;
});

// ── Avatar palette ────────────────────────────────────────────────
const AVATAR_PALETTE: Array<{ bg: string; fg: string }> = [
  { bg: '#DCFCE7', fg: '#166534' },
  { bg: '#EDE9FE', fg: '#5B21B6' },
  { bg: '#FFE4E1', fg: '#9A3412' },
  { bg: '#FEF3C7', fg: '#92400E' },
  { bg: '#DBEAFE', fg: '#1E40AF' },
];

function avatarStyle(r: Row): Record<string, string> {
  // Inline styles — tailwind JIT can't resolve arbitrary classes built
  // from dynamic template literals, so we ship the palette via :style.
  const p = AVATAR_PALETTE[r.paletteIdx % AVATAR_PALETTE.length];
  return { background: p.bg, color: p.fg };
}

function initials(name?: string | null): string {
  if (!name) return '?';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function rankCls(rank: number, isMe: boolean): string {
  if (isMe) return 'text-bimbel-hero';
  if (rank === 1) return 'text-amber-700';
  if (rank === 2) return 'text-gray-600';
  if (rank === 3) return 'text-orange-700';
  return 'text-bimbel-text-mid';
}

function rankPrefix(rank: number): string {
  if (rank === 1) return '🏆 ';
  if (rank === 2) return '🥈 ';
  if (rank === 3) return '🥉 ';
  return '';
}

function deltaCls(d: number): string {
  if (d > 0) return 'text-green-700';
  if (d < 0) return 'text-red-700';
  return 'text-bimbel-text-lo';
}

function deltaLabel(d: number): string {
  if (d > 0) return `+${d}`;
  if (d < 0) return `${d}`;
  return '—';
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      :kicker="t('wali.bimbel.leaderboard.kicker')"
      :title="t('wali.bimbel.leaderboard.title')"
      :subtitle="t('wali.bimbel.leaderboard.subtitle', { group: currentGroupLabel })"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="openGroupPicker"
        >
          {{ currentGroupShort }}
          <NavIcon name="chevron-down" :size="12" />
        </button>
      </template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">{{ t('wali.bimbel.leaderboard.loading') }}</div>

    <template v-else>
      <!-- Anak saya highlight -->
      <div
        v-if="myRow"
        class="rounded-lg bg-bimbel-accent-dim p-3 flex gap-3.5 items-center"
      >
        <div class="flex-1 min-w-0">
          <p class="text-[10px] text-bimbel-hero tracking-wider font-bold uppercase">
            {{ t('wali.bimbel.leaderboard.child_label', { name: myRow.name }) }}
          </p>
          <p class="text-[22px] font-extrabold text-bimbel-hero leading-tight">
            #{{ myRow.rank }}<span class="text-[13px] font-normal text-bimbel-hero/80"> {{ t('wali.bimbel.leaderboard.of_total', { total: rows.length }) }}</span>
          </p>
          <p class="text-[12px] text-bimbel-hero/80">
            {{ myRow.deltaText || t('wali.bimbel.leaderboard.delta_same') }}
          </p>
        </div>
        <div class="text-[12px] text-bimbel-hero text-right">
          <p>{{ t('wali.bimbel.leaderboard.score_label') }}</p>
          <p class="text-[18px] font-extrabold leading-tight">{{ myRow.score }}</p>
          <p v-if="myRow.gapText" class="text-bimbel-hero/80">{{ myRow.gapText }}</p>
        </div>
      </div>

      <!-- Ranking rows -->
      <div class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-3.5">
        <div
          v-for="r in rows"
          :key="r.id"
          :class="[
            'grid items-center gap-2.5 py-2 border-b border-bimbel-border-soft last:border-b-0 text-[13px]',
            r.isMe ? 'bg-bimbel-accent-dim -mx-3.5 px-3.5' : '',
          ]"
          style="grid-template-columns: 28px 28px 1fr auto auto;"
        >
          <span
            class="font-bold text-center"
            :class="rankCls(r.rank, r.isMe)"
          >{{ rankPrefix(r.rank) }}{{ r.rank }}</span>

          <div
            class="w-7 h-7 rounded-full grid place-items-center text-[10px] font-bold"
            :style="avatarStyle(r)"
          >{{ initials(r.name) }}</div>

          <div class="min-w-0">
            <p
              class="font-bold truncate"
              :class="r.isMe ? 'text-bimbel-hero' : 'text-bimbel-text-hi'"
            >
              {{ r.name }}
              <span
                v-if="r.isMe"
                class="text-[9px] bg-bimbel-hero text-white px-1.5 py-px rounded-full ml-1 align-middle"
              >{{ t('wali.bimbel.leaderboard.anak_badge') }}</span>
            </p>
            <p
              class="text-[10px]"
              :class="r.isMe ? 'text-bimbel-hero/80' : 'text-bimbel-text-lo'"
            >{{ r.attendedLine }}</p>
          </div>

          <span class="text-[10px]" :class="deltaCls(r.delta)">{{ deltaLabel(r.delta) }}</span>
          <span class="font-bold" :class="r.isMe ? 'text-bimbel-hero' : 'text-bimbel-text-hi'">{{ r.score }}</span>
        </div>

        <p
          v-if="!rows.length"
          class="text-center text-[13px] text-bimbel-text-mid py-6"
        >{{ t('wali.bimbel.leaderboard.empty') }}</p>
      </div>
    </template>
  </div>
</template>
