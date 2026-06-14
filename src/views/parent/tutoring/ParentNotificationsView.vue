<!--
  ParentNotificationsView — wali notifications. Mockup
  parent_web_pages_account frame 1: hero + date-grouped timeline
  (HARI INI / KEMARIN / MINGGU LALU / LEBIH LAMA).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { NotificationService } from '@/services/notification.service';
import type { AppNotification, NotificationCategory } from '@/types/notification';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const loading = ref(true);
const items = ref<AppNotification[]>([]);

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

const unreadCount = computed(() => items.value.filter((n) => !n.read_at).length);

// ── Icon + colour ramp per backend category ──────────────────────
const ICON_BY_CATEGORY: Record<NotificationCategory, string> = {
  billing: 'wallet',
  grade: 'star',
  attendance: 'check-circle',
  announcement: 'megaphone',
  class_activity: 'book',
  lesson_plan: 'file-text',
  system: 'info',
  other: 'circle',
};

const STYLE_BY_CATEGORY: Record<NotificationCategory, { bg: string; fg: string }> = {
  billing: { bg: '#FEF3C7', fg: '#92400E' }, // amber
  grade: { bg: '#DCFCE7', fg: '#166534' }, // green
  attendance: { bg: '#DBEAFE', fg: '#1E40AF' }, // blue
  announcement: { bg: '#EDE9FE', fg: '#5B21B6' }, // purple
  class_activity: { bg: '#FFE4E1', fg: '#9A3412' }, // coral
  lesson_plan: { bg: '#DBEAFE', fg: '#1E40AF' },
  system: { bg: '#E5E7EB', fg: '#374151' },
  other: { bg: '#E5E7EB', fg: '#374151' },
};

function iconName(n: AppNotification): string {
  return ICON_BY_CATEGORY[n.category] ?? 'circle';
}

function iconStyle(n: AppNotification): Record<string, string> {
  const p = STYLE_BY_CATEGORY[n.category] ?? STYLE_BY_CATEGORY.other;
  return { background: p.bg, color: p.fg };
}

function relTime(iso: string): string {
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

const grouped = computed<Record<GroupKey, AppNotification[]>>(() => {
  const buckets: Record<GroupKey, AppNotification[]> = {
    today: [], yesterday: [], week: [], older: [],
  };
  for (const n of items.value) {
    buckets[bucketOf(n.created_at)].push(n);
  }
  return buckets;
});

const groupOrder: GroupKey[] = ['today', 'yesterday', 'week', 'older'];
const groupLabels: Record<GroupKey, string> = {
  today: 'HARI INI',
  yesterday: 'KEMARIN',
  week: 'MINGGU LALU',
  older: 'LEBIH LAMA',
};
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
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="markAll"
        >Tandai semua dibaca</button>
      </template>
    </ParentBerandaHero>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div
      v-else-if="items.length"
      class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-3.5"
    >
      <template v-for="key in groupOrder" :key="key">
        <template v-if="grouped[key].length">
          <p class="text-[10px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
            {{ groupLabels[key] }}
          </p>
          <div
            v-for="(n, i) in grouped[key]"
            :key="n.id"
            :class="[
              'flex items-start gap-2.5 py-2.5',
              !n.read_at ? 'bg-bimbel-accent-dim -mx-3.5 px-3.5' : '',
              key === 'week' && i === grouped[key].length - 1 ? 'opacity-70' : '',
            ]"
          >
            <div
              class="w-[30px] h-[30px] rounded-lg grid place-items-center flex-shrink-0"
              :style="iconStyle(n)"
            >
              <NavIcon :name="iconName(n)" :size="14" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[14px] font-bold text-bimbel-text-hi">{{ n.title }}</p>
              <p v-if="n.body" class="text-[12px] text-bimbel-text-mid">{{ n.body }}</p>
            </div>
            <span
              v-if="!n.read_at"
              class="rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide bg-red-900 text-white flex-shrink-0"
            >BARU</span>
            <span
              v-else
              class="text-[12px] text-bimbel-text-lo flex-shrink-0"
            >{{ relTime(n.created_at) }}</span>
          </div>
        </template>
      </template>
    </div>

    <div
      v-else
      class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-8 text-center text-[14px] text-bimbel-text-mid"
    >Belum ada notifikasi.</div>
  </div>
</template>
