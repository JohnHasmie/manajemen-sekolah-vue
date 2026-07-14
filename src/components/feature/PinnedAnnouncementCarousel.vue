<!--
  PinnedAnnouncementCarousel.vue — "Pengumuman disematkan" strip shown at
  the TOP of every role's dashboard.

  Self-fetches the pinned feed on mount via `AnnouncementService.pinned()`
  (which degrades to [] when the tenant lacks the `communication` module),
  and renders NOTHING when the list is empty — so it never breaks a
  dashboard or leaves an empty gap.

  Shows ONE pinned card at a time. With >1 item it auto-advances every
  6s, exposes clickable dot indicators, and pauses on hover. Tapping the
  card (or "Baca selengkapnya") opens the shared AnnouncementDetailModal,
  wired exactly like TeacherAnnouncementView.

  Theme-aware via Tailwind `dark:` variants (the app's `.tutoring-dark`
  selector strategy) — matching the surrounding light-only dashboard
  cards outside a dark scope.
-->
<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { AnnouncementService } from '@/services/announcements.service';
import { formatRelative, formatDateShort } from '@/lib/format';
import type { Announcement } from '@/types/announcements';
import AnnouncementDetailModal from '@/components/feature/AnnouncementDetailModal.vue';

const props = withDefaults(
  defineProps<{
    /** Optional class scope forwarded to the endpoint as `class_id`. */
    classId?: string;
    /** Max pinned rows to request. */
    limit?: number;
    /** Viewer role forwarded to the detail modal (read metrics visibility). */
    viewerRole?: 'admin' | 'teacher' | 'parent';
  }>(),
  { limit: 8, viewerRole: 'parent' },
);

const { t } = useI18n();

const items = ref<Announcement[]>([]);
const active = ref(0);
const detail = ref<Announcement | null>(null);

const AUTO_ADVANCE_MS = 6000;
let timer: ReturnType<typeof setInterval> | null = null;

const hasMultiple = computed(() => items.value.length > 1);
const current = computed<Announcement | null>(
  () => items.value[Math.min(active.value, items.value.length - 1)] ?? null,
);

// ── Author name + initials avatar (reuse the `source` label the
//    AnnouncementCard/mapper expose as the friendly creator name). ──
const authorName = computed(
  () => current.value?.source || t('announcements.defaultAuthor'),
);

const authorInitials = computed(() => {
  const parts = authorName.value.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
});

// ── Priority badge — high/urgent → Penting, event → Acara, else Umum.
//    Colours match the spec (red #dc2626 / violet #6d28d9 / blue #1b6fb8)
//    with dark-scope fallbacks. ──
const badge = computed(() => {
  const a = current.value;
  if (!a) return null;
  if (a.priority === 'high' || a.priority === 'urgent') {
    return {
      label: t('announcement.categoryImportant'),
      cls: 'text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-500/10',
    };
  }
  if (a.type === 'event') {
    return {
      label: t('announcement.categoryEvent'),
      cls: 'text-violet-700 dark:text-violet-400 bg-violet-50 dark:bg-violet-500/10',
    };
  }
  return {
    label: t('announcement.categoryGeneral'),
    cls: 'text-[#1b6fb8] dark:text-sky-400 bg-sky-50 dark:bg-sky-500/10',
  };
});

const snippet = computed(() => current.value?.body?.trim() || '');

const timeLabel = computed(() => {
  const a = current.value;
  if (!a) return '';
  const ts = a.published_at ?? a.created_at;
  return formatRelative(ts) || formatDateShort(ts);
});

const validUntilLabel = computed(() => {
  const until = current.value?.pinned_until;
  if (!until) return '';
  return t('announcements.validUntil', { date: formatDateShort(until) });
});

// ── Auto-advance timer (only meaningful with >1 item). ──
function start() {
  stop();
  if (!hasMultiple.value) return;
  timer = setInterval(() => {
    active.value = (active.value + 1) % items.value.length;
  }, AUTO_ADVANCE_MS);
}

function stop() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

function goTo(i: number) {
  active.value = i;
  // Restart the clock so a manual pick doesn't get yanked forward early.
  start();
}

function openDetail(a: Announcement | null) {
  if (a) detail.value = a;
}

onMounted(async () => {
  items.value = await AnnouncementService.pinned({
    classId: props.classId,
    limit: props.limit,
  });
  start();
});

onUnmounted(stop);
</script>

<template>
  <section
    v-if="items.length"
    class="pinned-carousel"
    @mouseenter="stop"
    @mouseleave="start"
  >
    <button
      type="button"
      class="relative w-full overflow-hidden rounded-2xl border border-amber-200 dark:border-amber-500/25 bg-white dark:bg-slate-900 text-left shadow-sm transition-shadow hover:shadow-md focus:outline-none focus:ring-2 focus:ring-amber-500/30"
      @click="openDetail(current)"
    >
      <!-- Gold/amber left accent stripe -->
      <span
        class="absolute inset-y-0 left-0 w-1.5 bg-[#b45309]"
        aria-hidden="true"
      ></span>
      <!-- Faint amber gradient across the top -->
      <span
        class="pointer-events-none absolute inset-x-0 top-0 h-16 bg-gradient-to-b from-amber-100/70 to-transparent dark:from-amber-500/10"
        aria-hidden="true"
      ></span>

      <div class="relative pl-5 pr-4 py-4">
        <!-- Label + priority badge + validity chip -->
        <div class="flex items-center gap-2 flex-wrap mb-2">
          <span
            class="inline-flex items-center gap-1 text-3xs font-black uppercase tracking-wider text-[#b45309] dark:text-amber-300"
          >
            📌 {{ t('announcements.pinnedLabel') }}
          </span>
          <span
            v-if="badge"
            class="text-3xs font-bold uppercase tracking-wider px-2 py-0.5 rounded-full"
            :class="badge.cls"
          >
            {{ badge.label }}
          </span>
          <span class="flex-1"></span>
          <span
            v-if="validUntilLabel"
            class="inline-flex items-center gap-1 text-3xs font-bold text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-500/10 px-2 py-0.5 rounded-full flex-shrink-0"
          >
            🕒 {{ validUntilLabel }}
          </span>
        </div>

        <!-- Title (1 line) -->
        <p
          class="text-[15px] font-black text-slate-900 dark:text-slate-50 leading-snug truncate"
        >
          {{ current?.title || t('announcements.untitled') }}
        </p>

        <!-- Snippet (2 lines) -->
        <p
          v-if="snippet"
          class="text-[12.5px] text-slate-600 dark:text-slate-300 mt-1 line-clamp-2 leading-relaxed"
        >
          {{ snippet }}
        </p>

        <!-- Meta row: avatar + author + relative time + read-more -->
        <div class="flex items-center gap-2 mt-3">
          <span
            class="w-7 h-7 rounded-full grid place-items-center text-[11px] font-black text-white bg-[#b45309] flex-shrink-0"
          >
            {{ authorInitials }}
          </span>
          <span
            class="text-[12px] font-bold text-slate-700 dark:text-slate-200 truncate"
          >
            {{ authorName }}
          </span>
          <span class="text-slate-300 dark:text-slate-600">·</span>
          <span
            class="text-[11.5px] text-slate-400 dark:text-slate-500 flex-shrink-0"
          >
            {{ timeLabel }}
          </span>
          <span class="flex-1"></span>
          <span
            class="inline-flex items-center gap-1 text-[12px] font-black text-[#b45309] dark:text-amber-300 flex-shrink-0"
          >
            {{ t('announcements.readMore') }} →
          </span>
        </div>
      </div>
    </button>

    <!-- Dot indicators (only with >1 item) -->
    <div
      v-if="hasMultiple"
      class="mt-2.5 flex items-center justify-center gap-1.5"
    >
      <button
        v-for="(a, i) in items"
        :key="a.id || i"
        type="button"
        class="h-1.5 rounded-full transition-all"
        :class="
          i === active
            ? 'w-5 bg-[#b45309]'
            : 'w-1.5 bg-amber-200 dark:bg-amber-500/30 hover:bg-amber-300'
        "
        :aria-label="t('announcements.goToSlide', { n: i + 1 })"
        @click="goTo(i)"
      />
    </div>

    <!-- Shared detail modal — wired like TeacherAnnouncementView. -->
    <AnnouncementDetailModal
      v-if="detail"
      :announcement="detail"
      :viewer-role="viewerRole"
      :auto-mark-read="false"
      @close="detail = null"
    />
  </section>
</template>
