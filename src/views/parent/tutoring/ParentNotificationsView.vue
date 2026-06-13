<!--
  ParentNotificationsView — wali notifications. Mockup parent_web_pages_account
  frame 1: hero + Semua/Belum-dibaca pill + Tandai-semua-dibaca CTA +
  styled notification rows (unread → faint cyan bg + dot).
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

function iconFor(n: AppNotification): string {
  return iconByCategory[n.category] || 'circle';
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
</script>

<template>
  <div class="space-y-4 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · NOTIFIKASI"
      title="Notifikasi"
      :subtitle="`${unreadCount} baru · ${items.length} total`"
      :stats="[]"
    >
      <template #actions>
        <button
          v-if="unreadCount > 0"
          type="button"
          class="rounded-lg bg-white text-[#0c447c] px-3 py-1.5 text-[12px] font-bold hover:bg-white/95"
          @click="markAll"
        >Tandai semua dibaca</button>
      </template>
    </ParentBerandaHero>

    <div class="flex gap-1.5">
      <button
        v-for="opt in [
          { id: 'all' as const, label: `Semua (${items.length})` },
          { id: 'unread' as const, label: `Belum dibaca (${unreadCount})` },
        ]"
        :key="opt.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[12px] font-semibold"
        :class="
          filter === opt.id
            ? 'border-[#21afe6] bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]'
            : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'
        "
        @click="filter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="space-y-2">
      <div
        v-for="n in filtered"
        :key="n.id"
        class="flex items-start gap-3 rounded-2xl border p-3"
        :class="
          n.read_at
            ? 'border-bimbel-border-soft bg-bimbel-panel'
            : 'border-[#21afe6]/40 bg-[#21afe6]/8'
        "
      >
        <span class="grid h-9 w-9 flex-shrink-0 place-items-center rounded-xl bg-[#21afe6]/15 text-[#1a8fbe] dark:text-[#85d4f4]">
          <NavIcon :name="iconFor(n)" :size="15" />
        </span>
        <div class="min-w-0 flex-1">
          <p class="text-[13px] font-bold text-bimbel-text-hi">{{ n.title }}</p>
          <p v-if="n.body" class="text-[12px] text-bimbel-text-mid">{{ n.body }}</p>
        </div>
        <span class="flex-shrink-0 text-[12px] text-bimbel-text-lo">{{ rel(n.created_at) }}</span>
        <span v-if="!n.read_at" class="mt-1.5 h-2 w-2 flex-shrink-0 rounded-full bg-[#21afe6]" />
      </div>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      <template v-if="filter === 'unread'">Tidak ada notifikasi baru.</template>
      <template v-else>Belum ada notifikasi.</template>
    </div>
  </div>
</template>
