<!--
  TutorNotificationsView — tutor-scoped notifications list. Reuses
  NotificationService which auto-detects audience from active role.
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
const filter = ref<'all' | 'unread'>('all');

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

const filtered = computed(() => filter.value === 'unread' ? items.value.filter((n) => !n.read_at) : items.value);
const unread = computed(() => items.value.filter((n) => !n.read_at).length);

// New tutor-specific types ship with the bimbel notification triggers
// (NotifyTutorAction). They use Schedule::command-style snake_case
// rather than the legacy SCREAMING_SNAKE because they're prefixed
// with the module name ("tutoring_*") and read as ids in logs.
const iconByCategory: Record<string, string> = {
  PERHATIAN_GRADE: 'star',
  PERHATIAN_ATTENDANCE: 'check-circle',
  PERHATIAN_ANNOUNCEMENT: 'megaphone',
  TUGAS: 'book',
  UJIAN: 'check-circle',
  KEGIATAN: 'calendar',
  KELAS: 'megaphone',
  LAIN: 'circle',
  // Tutor-recipient (bimbel).
  tutoring_enrollment_new: 'user-plus',
  tutoring_group_assigned: 'users',
  tutoring_rating_received: 'star',
  tutoring_session_cancelled: 'x-circle',
  // Self-service honor-withdrawal lifecycle. Both backend types
  // (`tutoring_payout_request_created` + `_status`) collapse to the
  // `tutoring_payout` category via notificationCategoryFromType.
  tutoring_payout: 'wallet',
  // Finance (admin sees payment_submitted, parent sees the other three;
  // tutor doesn't recipient on these but we map for completeness).
  bill_generated: 'wallet',
  payment_submitted: 'upload',
  payment_verified: 'check-circle',
  payment_rejected: 'x-circle',
  payment_confirmed: 'check-circle',
};
function iconFor(n: AppNotification): string {
  if (iconByCategory[n.category]) return iconByCategory[n.category];
  // Configurable session reminders all share the
  // `tutoring_session_reminder_<N>m` shape — collapse to one icon.
  if (n.category?.startsWith('tutoring_session_reminder_')) return 'bell';
  if (n.category?.startsWith('tutoring_bill_reminder_')) return 'wallet';
  return 'circle';
}
function rel(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '';
  const diff = (Date.now() - d.valueOf()) / 60_000;
  if (diff < 1) return t('tutor.bimbel.notifications.rel_just_now');
  if (diff < 60) return `${Math.floor(diff)}m`;
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
      :greeting="t('tutor.bimbel.notifications.greeting')"
      :title="t('tutor.bimbel.notifications.title')"
      :subtitle="t('tutor.bimbel.notifications.subtitle', { unread, total: items.length })"
      :stats="[]"
    >
      <template #actions>
        <button
          v-if="unread > 0"
          type="button"
          class="rounded-lg bg-white text-tutoring-accent px-3 py-1.5 text-[13px] font-bold hover:opacity-90"
          @click="markAll"
        >{{ t('tutor.bimbel.notifications.mark_all_read') }}</button>
      </template>
    </TutorHomeHero>

    <div class="flex gap-1.5">
      <button
        v-for="opt in [
          { id: 'all' as const, label: t('tutor.bimbel.notifications.filter_all', { count: items.length }) },
          { id: 'unread' as const, label: t('tutor.bimbel.notifications.filter_unread', { count: unread }) },
        ]"
        :key="opt.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[13px] font-semibold"
        :class="filter === opt.id ? 'border-tutoring-accent bg-tutoring-accent-dim text-tutoring-accent' : 'border-tutoring-border bg-tutoring-panel text-tutoring-text-mid'"
        @click="filter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('tutor.bimbel.notifications.loading') }}</div>

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
          <p v-if="n.body" class="text-[13px] text-tutoring-text-mid">{{ n.body }}</p>
        </div>
        <span class="flex-shrink-0 text-[12px] text-tutoring-text-lo">{{ rel(n.created_at) }}</span>
        <span v-if="!n.read_at" class="mt-1.5 h-2 w-2 flex-shrink-0 rounded-full bg-tutoring-accent" />
      </div>
    </div>

    <div v-else class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid">
      <template v-if="filter === 'unread'">{{ t('tutor.bimbel.notifications.empty_unread') }}</template>
      <template v-else>{{ t('tutor.bimbel.notifications.empty_all') }}</template>
    </div>
  </div>
</template>
