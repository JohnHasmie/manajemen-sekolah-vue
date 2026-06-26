<!--
  AdminTutoringNotificationsView — admin-scoped notifications list.
  Mockup admin_web_pages_account frame 3.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { NotificationService } from '@/services/notification.service';
import type { AppNotification } from '@/types/notification';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const loading = ref(true);
const items = ref<AppNotification[]>([]);
const filter = ref<'all' | 'unread' | 'leads' | 'bills'>('all');

async function load() {
  loading.value = true;
  try { items.value = (await NotificationService.list(1, 50)).items; }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
async function markAll() {
  try { await NotificationService.markAllRead(); }
  catch {/* non-fatal */}
  await load();
}
onMounted(load);

const filtered = computed(() => {
  let list = items.value;
  if (filter.value === 'unread') list = list.filter((n) => !n.read_at);
  if (filter.value === 'leads') list = list.filter((n) => /lead/i.test(n.category) || /lead|calon/i.test(n.title));
  if (filter.value === 'bills') list = list.filter((n) => /finance|tagihan|bill/i.test(n.category + n.title));
  return list;
});
const unread = computed(() => items.value.filter((n) => !n.read_at).length);

const iconMap: Record<string, string> = {
  PERHATIAN_FINANCE: 'wallet',
  PERHATIAN_GRADE: 'star',
  PERHATIAN_ATTENDANCE: 'check-circle',
  PERHATIAN_ANNOUNCEMENT: 'megaphone',
  KEGIATAN: 'calendar',
  LAIN: 'circle',
};
function iconFor(n: AppNotification): string { return iconMap[n.category] || 'circle'; }
function rel(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diff = (Date.now() - d.valueOf()) / 60_000;
  if (diff < 60) return `${Math.max(1, Math.floor(diff))}m`;
  const h = Math.floor(diff / 60);
  if (h < 24) return `${h}j`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days}h`;
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('admin.bimbel.notifications.hero_kicker')"
      :title="t('admin.bimbel.notifications.hero_title')"
      :subtitle="t('admin.bimbel.notifications.hero_subtitle', { unread, total: items.length })"
      :stats="[]"
    >
      <template #actions>
        <button
          v-if="unread > 0"
          class="rounded-lg bg-white text-tutoring-accent px-3 py-1.5 text-[14px] font-bold"
          @click="markAll"
        >{{ t('admin.bimbel.notifications.mark_all') }}</button>
      </template>
    </TutorHomeHero>

    <div class="flex gap-1.5 flex-wrap">
      <button
        v-for="opt in [
          { id: 'all' as const, label: t('admin.bimbel.notifications.filter_all', { count: items.length }) },
          { id: 'unread' as const, label: t('admin.bimbel.notifications.filter_unread', { count: unread }) },
          { id: 'leads' as const, label: t('admin.bimbel.notifications.filter_leads') },
          { id: 'bills' as const, label: t('admin.bimbel.notifications.filter_bills') },
        ]"
        :key="opt.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
        :class="filter === opt.id ? 'border-tutoring-accent bg-tutoring-accent-dim text-tutoring-accent' : 'border-tutoring-border bg-tutoring-panel text-tutoring-text-mid'"
        @click="filter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.notifications.loading') }}</div>

    <div v-else-if="filtered.length" class="space-y-2">
      <div
        v-for="n in filtered"
        :key="n.id"
        class="flex items-start gap-3 rounded-2xl border p-3"
        :class="n.read_at ? 'border-tutoring-border-soft bg-tutoring-panel' : 'border-tutoring-accent/40 bg-tutoring-accent-dim'"
      >
        <span class="grid h-9 w-9 flex-shrink-0 place-items-center rounded-xl bg-tutoring-accent-dim text-tutoring-accent">
          <NavIcon :name="iconFor(n)" :size="15" />
        </span>
        <div class="min-w-0 flex-1">
          <p class="text-[14px] font-bold text-tutoring-text-hi">{{ n.title }}</p>
          <p v-if="n.body" class="text-[14px] text-tutoring-text-mid">{{ n.body }}</p>
        </div>
        <span class="flex-shrink-0 text-[13px] text-tutoring-text-lo">{{ rel(n.created_at) }}</span>
        <span v-if="!n.read_at" class="mt-1.5 h-2 w-2 flex-shrink-0 rounded-full bg-tutoring-accent" />
      </div>
    </div>

    <div v-else class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid">
      {{ t('admin.bimbel.notifications.empty') }}
    </div>
  </div>
</template>
