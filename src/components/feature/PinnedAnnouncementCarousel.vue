<!--
  PinnedAnnouncementCarousel.vue — "Pengumuman disematkan" strip at the TOP
  of every role's dashboard. "Prioritas memimpin" model:

  • Priority-adaptive cards: PENTING (high/urgent) red, ACARA (event) violet
    with a countdown, UMUM (normal) gold.
  • When an unacknowledged PENTING item exists, auto-advance is DISABLED so the
    urgent card can never be rotated out of view; otherwise the strip gently
    auto-advances every 6s. Dot indicators allow manual browsing.
  • PENTING cards carry a "Mengerti" acknowledge that marks the row read and
    drops it locally (like the welcome banner) so it stops nagging.
  • All icons are inline SVG (no emoji). Renders nothing when empty / on error
    (the endpoint returns [] when the tenant lacks the communication module).
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
    classId?: string;
    limit?: number;
    viewerRole?: 'admin' | 'teacher' | 'parent';
  }>(),
  { limit: 8, viewerRole: 'parent' },
);

const { t } = useI18n();

type Tier = 'penting' | 'acara' | 'umum';

const items = ref<Announcement[]>([]);
const active = ref(0);
const detail = ref<Announcement | null>(null);
const acknowledging = ref<string | null>(null);

const AUTO_ADVANCE_MS = 6000;
let timer: ReturnType<typeof setInterval> | null = null;

function tierOf(a: Announcement): Tier {
  if (a.priority === 'high' || a.priority === 'urgent') return 'penting';
  if (a.type === 'event' || a.event_at) return 'acara';
  return 'umum';
}

const current = computed<Announcement | null>(
  () => items.value[Math.min(active.value, items.value.length - 1)] ?? null,
);
const currentTier = computed<Tier>(() =>
  current.value ? tierOf(current.value) : 'umum',
);
const hasMultiple = computed(() => items.value.length > 1);
// An unacknowledged PENTING anywhere freezes auto-advance so it stays visible.
const hasUrgent = computed(() => items.value.some((a) => tierOf(a) === 'penting'));

const authorName = computed(
  () => current.value?.source || t('announcements.defaultAuthor'),
);
const authorInitials = computed(() => {
  const parts = authorName.value.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
});

const badgeLabel = computed(() => {
  switch (currentTier.value) {
    case 'penting':
      return t('announcement.categoryImportant');
    case 'acara':
      return t('announcement.categoryEvent');
    default:
      return t('announcement.categoryGeneral');
  }
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

// Event countdown — "Hari ini" / "Besok" / "N hari lagi" / "Berlangsung".
const countdown = computed(() => {
  const a = current.value;
  if (!a || currentTier.value !== 'acara' || !a.event_at) return '';
  const ev = new Date(a.event_at);
  if (Number.isNaN(ev.getTime())) return '';
  const startOfDay = (d: Date) =>
    new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  const days = Math.round((startOfDay(ev) - startOfDay(new Date())) / 86400000);
  if (days < 0) return t('announcements.eventOngoing');
  if (days === 0) return t('announcements.eventToday');
  if (days === 1) return t('announcements.eventTomorrow');
  return t('announcements.eventInDays', { n: days });
});
const eventWhen = computed(() =>
  current.value?.event_at ? formatDateShort(current.value.event_at) : '',
);

// ── Auto-advance (paused while an urgent item is present). ──
function start() {
  stop();
  if (!hasMultiple.value || hasUrgent.value) return;
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
  start();
}

function openDetail(a: Announcement | null) {
  if (a) detail.value = a;
}

async function acknowledge(a: Announcement | null) {
  if (!a || acknowledging.value) return;
  acknowledging.value = a.id;
  try {
    await AnnouncementService.markAsRead(a.id);
  } catch {
    // ignore — still drop it locally so the dashboard clears.
  }
  items.value = items.value.filter((x) => x.id !== a.id);
  if (active.value >= items.value.length) active.value = 0;
  acknowledging.value = null;
  start();
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
    :class="`tier-${currentTier}`"
    @mouseenter="stop"
    @mouseleave="start"
  >
    <button type="button" class="pc-card" @click="openDetail(current)">
      <span class="pc-rail" aria-hidden="true"></span>

      <div class="pc-head">
        <span class="pc-typeicon" aria-hidden="true">
          <!-- PENTING: alert-triangle -->
          <svg v-if="currentTier === 'penting'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z" />
            <line x1="12" y1="9" x2="12" y2="13" /><line x1="12" y1="17" x2="12.01" y2="17" />
          </svg>
          <!-- ACARA: calendar -->
          <svg v-else-if="currentTier === 'acara'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="3" y="4" width="18" height="18" rx="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" />
          </svg>
          <!-- UMUM: megaphone -->
          <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m3 11 18-5v12L3 14v-3z" /><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6" />
          </svg>
        </span>
        <span class="pc-badge">{{ badgeLabel }}</span>
        <span class="pc-pin" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 17v5" /><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z" />
          </svg>
        </span>
        <span class="pc-spacer"></span>
        <span v-if="validUntilLabel" class="pc-valid">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9" /><polyline points="12 7 12 12 15 14" /></svg>
          {{ validUntilLabel }}
        </span>
      </div>

      <p class="pc-title">{{ current?.title || t('announcements.untitled') }}</p>

      <!-- Event countdown replaces the snippet for ACARA -->
      <div v-if="currentTier === 'acara' && countdown" class="pc-event">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" /></svg>
        <span class="pc-event-when">{{ eventWhen }}</span>
        <span class="pc-countdown">{{ countdown }}</span>
      </div>
      <p v-else-if="snippet" class="pc-snippet">{{ snippet }}</p>

      <div class="pc-meta">
        <span class="pc-avatar">{{ authorInitials }}</span>
        <span class="pc-author">{{ authorName }}</span>
        <span class="pc-dot">·</span>
        <span class="pc-time">{{ timeLabel }}</span>
        <span class="pc-spacer"></span>

        <span
          v-if="currentTier === 'penting'"
          class="pc-ack"
          role="button"
          @click.stop="acknowledge(current)"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12" /></svg>
          {{ t('announcements.acknowledge') }}
        </span>
        <span v-else class="pc-readmore">
          {{ t('announcements.readMore') }}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6" /></svg>
        </span>
      </div>
    </button>

    <div v-if="hasMultiple" class="pc-dots">
      <button
        v-for="(a, i) in items"
        :key="a.id || i"
        type="button"
        class="pc-dotbtn"
        :class="{ 'is-active': i === active }"
        :aria-label="t('announcements.goToSlide', { n: i + 1 })"
        @click="goTo(i)"
      />
    </div>

    <AnnouncementDetailModal
      v-if="detail"
      :announcement="detail"
      :viewer-role="viewerRole"
      :auto-mark-read="false"
      @close="detail = null"
    />
  </section>
</template>

<style scoped>
/* Per-tier accent — one variable drives stripe, badge, icon, countdown. */
.pinned-carousel {
  --accent: #b45309;
  --accent-bg: #fef3c7;
  --accent-line: #fcd9a1;
}
.pinned-carousel.tier-penting {
  --accent: #dc2626;
  --accent-bg: #fee2e2;
  --accent-line: #fecaca;
}
.pinned-carousel.tier-acara {
  --accent: #6d28d9;
  --accent-bg: #ede9fe;
  --accent-line: #ddd6fe;
}
.pinned-carousel.tier-umum {
  --accent: #1b6fb8;
  --accent-bg: #e0edff;
  --accent-line: #c7ddf7;
}

.pc-card {
  position: relative;
  width: 100%;
  display: block;
  text-align: left;
  cursor: pointer;
  border: 1px solid var(--accent-line);
  border-radius: 16px;
  background:
    linear-gradient(180deg, color-mix(in srgb, var(--accent-bg) 85%, transparent), transparent 60%),
    #ffffff;
  padding: 13px 15px 12px 18px;
  box-shadow: 0 2px 10px rgba(11, 20, 45, 0.06);
  transition: box-shadow 0.15s ease;
}
.pc-card:hover {
  box-shadow: 0 8px 22px rgba(11, 20, 45, 0.12);
}
.pc-card:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}
.pc-rail {
  position: absolute;
  inset: 0 auto 0 0;
  width: 4px;
  border-radius: 16px 0 0 16px;
  background: var(--accent);
}

.pc-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
}
.pc-typeicon {
  width: 26px;
  height: 26px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  background: var(--accent-bg);
  color: var(--accent);
}
.pc-typeicon svg { width: 15px; height: 15px; }
.pc-badge {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--accent);
  background: var(--accent-bg);
  padding: 3px 8px;
  border-radius: 999px;
}
.pc-pin { color: var(--accent); display: inline-flex; }
.pc-pin svg { width: 14px; height: 14px; }
.pc-spacer { flex: 1; }
.pc-valid {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 10.5px;
  font-weight: 700;
  color: var(--accent);
}
.pc-valid svg { width: 12px; height: 12px; }

.pc-title {
  margin: 0;
  font-size: 15px;
  font-weight: 800;
  line-height: 1.28;
  color: #0f172a;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pc-snippet {
  margin: 4px 0 0;
  font-size: 12.5px;
  line-height: 1.5;
  color: #64748b;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
.pc-event {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 7px;
}
.pc-event svg { width: 15px; height: 15px; color: var(--accent); flex: 0 0 auto; }
.pc-event-when { font-size: 12px; font-weight: 700; color: #334155; }
.pc-countdown {
  font-size: 10.5px;
  font-weight: 800;
  color: var(--accent);
  background: var(--accent-bg);
  padding: 2px 8px;
  border-radius: 999px;
}

.pc-meta {
  display: flex;
  align-items: center;
  gap: 7px;
  margin-top: 11px;
}
.pc-avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-size: 9.5px;
  font-weight: 800;
  color: #ffffff;
  background: var(--accent);
  flex: 0 0 auto;
}
.pc-author {
  font-size: 12px;
  font-weight: 700;
  color: #334155;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 40%;
}
.pc-dot { color: #cbd5e1; }
.pc-time { font-size: 11px; color: #94a3b8; flex: 0 0 auto; }
.pc-readmore {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 12px;
  font-weight: 800;
  color: var(--accent);
  flex: 0 0 auto;
}
.pc-readmore svg { width: 13px; height: 13px; }
.pc-ack {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 12px;
  font-weight: 800;
  color: #ffffff;
  background: var(--accent);
  padding: 6px 12px;
  border-radius: 9px;
  flex: 0 0 auto;
}
.pc-ack svg { width: 13px; height: 13px; }

.pc-dots {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin-top: 10px;
}
.pc-dotbtn {
  width: 6px;
  height: 6px;
  border: 0;
  padding: 0;
  border-radius: 999px;
  background: var(--accent-line);
  cursor: pointer;
  transition: all 0.25s ease;
}
.pc-dotbtn.is-active { width: 18px; background: var(--accent); }

/* Dark theme — this app is LIGHT-only for schools; dark is opt-in and
   class-driven via `.tutoring-dark` (tailwind darkMode: ['selector',
   '.tutoring-dark']), NOT the OS `prefers-color-scheme`. Scoping the dark
   styling to `.tutoring-dark` keeps the card LIGHT on every school dashboard
   even when the viewer's OS is in dark mode (the earlier prefers-color-scheme
   rule wrongly darkened it there). */
.tutoring-dark .pc-card {
  background:
    linear-gradient(180deg, color-mix(in srgb, var(--accent) 16%, transparent), transparent 60%),
    #0f1a2e;
  border-color: color-mix(in srgb, var(--accent) 35%, transparent);
}
.tutoring-dark .pc-title { color: #f1f5f9; }
.tutoring-dark .pc-snippet { color: #94a3b8; }
.tutoring-dark .pc-author,
.tutoring-dark .pc-event-when { color: #cbd5e1; }
</style>
