<!--
  ParentNotificationsView — wali notifications. Mockup parent_web_pages_account
  frame 1: hero + date-grouped timeline (HARI INI / KEMARIN / MINGGU LALU).
  Per spec: visual redesign only. The load()/markAll() stubs stay as-is —
  backend wiring lives in a separate task.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { NotificationService } from '@/services/notification.service';
import type { AppNotification } from '@/types/notification';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const loading = ref(true);
const items = ref<AppNotification[]>([]);
const filter = ref<'all' | 'unread'>('all');

async function load() {
  loading.value = true;
  try {
    const res = await NotificationService.list(1, 50);
    items.value = res.items;
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}

async function markAll() {
  try { await NotificationService.markAllRead(); }
  catch {/* non-fatal */}
  await load();
}

onMounted(load);

const filtered = computed(() => {
  if (filter.value === 'unread') return items.value.filter((n) => !n.read_at);
  return items.value;
});
const unreadCount = computed(() => items.value.filter((n) => !n.read_at).length);

const iconByCategory: Record<string, string> = {
  PERHATIAN_FINANCE: 'wallet',
  PERHATIAN_GRADE: 'star',
  PERHATIAN_ATTENDANCE: 'check-circle',
  PERHATIAN_ANNOUNCEMENT: 'megaphone',
  TUGAS: 'book',
  UJIAN: 'check-circle',
  MATERI: 'book',
  KEGIATAN: 'calendar',
  KELAS: 'megaphone',
  LAIN: 'circle',
};

// Background + foreground per event type (mirrors Beranda spec).
const STYLE_BY_CATEGORY: Record<string, { bg: string; fg: string }> = {
  PERHATIAN_FINANCE: { bg: '#FEF3C7', fg: '#92400E' }, // amber
  PERHATIAN_GRADE: { bg: '#DCFCE7', fg: '#166534' }, // green
  PERHATIAN_ATTENDANCE: { bg: '#DBEAFE', fg: '#1E40AF' }, // blue
  PERHATIAN_ANNOUNCEMENT: { bg: '#EDE9FE', fg: '#5B21B6' }, // purple
  TUGAS: { bg: '#FFE4E1', fg: '#9A3412' }, // coral
  UJIAN: { bg: '#FEF3C7', fg: '#92400E' },
  MATERI: { bg: '#DBEAFE', fg: '#1E40AF' },
  KEGIATAN: { bg: '#DCFCE7', fg: '#166534' },
  KELAS: { bg: '#EDE9FE', fg: '#5B21B6' },
  LAIN: { bg: '#E5E7EB', fg: '#374151' },
};

function iconFor(n: AppNotification): string {
  return iconByCategory[n.category] || 'circle';
}

function iconStyle(n: AppNotification) {
  return STYLE_BY_CATEGORY[n.category] || STYLE_BY_CATEGORY.LAIN;
}

function rel(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diffMin = (Date.now() - d.valueOf()) / 60_000;
  if (diffMin < 1) return 'baru';
  if (diffMin < 60) return `${Math.floor(diffMin)}m`;
  const h = Math.floor(diffMin / 60);
  if (h < 24) return `${h}j`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days}h`;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

// ── Date grouping ─────────────────────────────────────────────────
type GroupKey = 'today' | 'yesterday' | 'week' | 'older';

function bucketOf(iso: string): GroupKey {
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return 'older';
  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).valueOf();
  const startOfYesterday = startOfToday - 24 * 60 * 60 * 1000;
  const sevenDaysAgo = startOfToday - 7 * 24 * 60 * 60 * 1000;
  const t = d.valueOf();
  if (t >= startOfToday) return 'today';
  if (t >= startOfYesterday) return 'yesterday';
  if (t >= sevenDaysAgo) return 'week';
  return 'older';
}

const grouped = computed(() => {
  const buckets: Record<GroupKey, AppNotification[]> = {
    today: [], yesterday: [], week: [], older: [],
  };
  for (const n of filtered.value) {
    buckets[bucketOf(n.created_at)].push(n);
  }
  return buckets;
});

const GROUP_LABELS: Record<GroupKey, string> = {
  today: 'HARI INI',
  yesterday: 'KEMARIN',
  week: 'MINGGU LALU',
  older: 'LEBIH LAMA',
};

const groupOrder: GroupKey[] = ['today', 'yesterday', 'week', 'older'];
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · NOTIFIKASI"
      title="Notifikasi"
      :subtitle="`${unreadCount} belum dibaca · ${items.length} total`"
      :stats="[]"
    >
      <template #actions>
        <button
          v-if="unreadCount > 0"
          type="button"
          class="rounded-full bg-white text-bimbel-hero px-2.5 py-1 text-[12px] font-bold hover:bg-white/95"
          @click="markAll"
        >Tandai semua dibaca</button>
      </template>
    </ParentBerandaHero>

    <!-- Filter pills -->
    <div class="flex gap-1.5">
      <button
        v-for="opt in [
          { id: 'all' as const, label: `Semua (${items.length})` },
          { id: 'unread' as const, label: `Belum dibaca (${unreadCount})` },
        ]"
        :key="opt.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] font-semibold transition-colors"
        :class="
          filter === opt.id
            ? 'bg-bimbel-hero text-white'
            : 'bg-bimbel-bg text-bimbel-text-mid hover:text-bimbel-text-hi'
        "
        @click="filter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div
      v-else-if="filtered.length"
      class="bg-bimbel-panel border border-bimbel-border-soft rounded-lg p-3.5 overflow-hidden"
    >
      <template v-for="key in groupOrder" :key="key">
        <template v-if="grouped[key].length">
          <h4 class="text-[11px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
            {{ GROUP_LABELS[key] }}
          </h4>
          <div
            v-for="(n, idx) in grouped[key]"
            :key="n.id"
            class="flex items-start gap-2.5 py-2.5"
            :class="[
              !n.read_at ? 'bg-bimbel-accent-dim -mx-3.5 px-3.5' : '',
              key === 'week' && idx === grouped[key].length - 1 ? 'opacity-70' : '',
            ]"
          >
            <span
              class="grid place-items-center rounded-lg flex-shrink-0"
              style="width:30px;height:30px"
              :style="{ background: iconStyle(n).bg, color: iconStyle(n).fg }"
            >
              <NavIcon :name="iconFor(n)" :size="14" />
            </span>
            <div class="min-w-0 flex-1">
              <p class="text-[13px] font-bold text-bimbel-text-hi">{{ n.title }}</p>
              <p v-if="n.body" class="text-[11px] text-bimbel-text-mid">{{ n.body }}</p>
            </div>
            <span
              v-if="!n.read_at"
              class="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide bg-red-900 text-white flex-shrink-0"
            >BARU</span>
            <span
              v-else
              class="text-[11px] text-bimbel-text-lo flex-shrink-0"
            >{{ rel(n.created_at) }}</span>
          </div>
        </template>
      </template>
    </div>

    <div
      v-else
      class="rounded-lg bg-bimbel-panel border border-bimbel-border-soft p-8 text-center text-[13px] text-bimbel-text-mid"
    >
      <template v-if="filter === 'unread'">Tidak ada notifikasi baru.</template>
      <template v-else>Belum ada notifikasi.</template>
    </div>
  </div>
</template>
