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

// Content is now rich HTML — show the plain-text excerpt, or strip tags from
// body as a fallback, so no markup leaks into the dashboard carousel.
const snippet = computed(() => {
  const a = current.value;
  if (!a) return '';
  if (a.excerpt) return a.excerpt;
  return (a.body ?? '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
});

const timeLabel = computed(() => {
  const a = current.value;
  if (!a) return '';
  const ts = a.published_at ?? a.created_at;
  return formatRelative(ts) || formatDateShort(ts);
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
      <!-- ── chip row: tier badge (solid) + pin chip + timestamp ── -->
      <div class="pc-head">
        <span class="pc-tier">
          <svg v-if="currentTier === 'penting'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0Z" />
            <line x1="12" y1="9" x2="12" y2="13" /><line x1="12" y1="17" x2="12.01" y2="17" />
          </svg>
          <svg v-else-if="currentTier === 'acara'" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <rect x="3" y="4" width="18" height="18" rx="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" />
          </svg>
          <svg v-else viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="m3 11 18-5v12L3 14v-3z" /><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6" />
          </svg>
          {{ badgeLabel }}
        </span>
        <span class="pc-pinchip">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M12 17v5" /><path d="M9 10.76a2 2 0 0 1-1.11 1.79l-1.78.9A2 2 0 0 0 5 15.24V16a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1v-.76a2 2 0 0 0-1.11-1.79l-1.78-.9A2 2 0 0 1 15 10.76V7a1 1 0 0 1 1-1 2 2 0 0 0 0-4H8a2 2 0 0 0 0 4 1 1 0 0 1 1 1z" />
          </svg>
          {{ t('announcements.pinnedLabel') }}
        </span>
        <span class="pc-spacer"></span>
        <span v-if="timeLabel" class="pc-time">{{ timeLabel }}</span>
      </div>

      <!-- ── title ── -->
      <p class="pc-title">{{ current?.title || t('announcements.untitled') }}</p>

      <!-- ── body or event countdown ── -->
      <div v-if="currentTier === 'acara' && countdown" class="pc-event">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <rect x="3" y="4" width="18" height="18" rx="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" />
        </svg>
        <span class="pc-event-when">{{ eventWhen }}</span>
        <span class="pc-countdown">{{ countdown }}</span>
      </div>
      <p v-else-if="snippet" class="pc-snippet">{{ snippet }}</p>

      <!-- ── divider + meta row ── -->
      <div class="pc-divider" aria-hidden="true"></div>
      <div class="pc-meta">
        <span class="pc-avatar">{{ authorInitials }}</span>
        <span class="pc-author">{{ authorName }}</span>
        <span class="pc-spacer"></span>

        <span
          v-if="currentTier === 'penting'"
          class="pc-ack"
          role="button"
          @click.stop="acknowledge(current)"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12" /></svg>
          {{ t('announcements.acknowledge') }}
        </span>
        <span v-else class="pc-readmore">
          {{ t('announcements.readMore') }}
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="9 18 15 12 9 6" /></svg>
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
/* Layered-chips redesign (Option D). Card is a plain slate-bordered white
   surface; colour only lives in the tier chip, the PENTING avatar, and the
   primary CTA. Per-tier accent still drives that one accent-carrying token. */
.pinned-carousel {
  --accent: #b45309;
  --accent-bg: #fef3c7;
}
.pinned-carousel.tier-penting {
  --accent: #dc2626;
  --accent-bg: #fee2e2;
}
.pinned-carousel.tier-acara {
  --accent: #6d28d9;
  --accent-bg: #ede9fe;
}
.pinned-carousel.tier-umum {
  --accent: #1b6fb8;
  --accent-bg: #e0edff;
}

.pc-card {
  width: 100%;
  display: block;
  text-align: left;
  cursor: pointer;
  border: 1px solid #e2e8f0;
  border-radius: 14px;
  background: #ffffff;
  padding: 14px;
  box-shadow: 0 1px 2px rgba(15, 27, 48, 0.04);
  transition: box-shadow 0.15s ease, border-color 0.15s ease;
}
.pc-card:hover {
  border-color: #cbd5e1;
  box-shadow: 0 4px 14px rgba(15, 27, 48, 0.08);
}
.pc-card:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}

/* ── chip row: tier badge (solid) + pin chip (neutral) + timestamp ── */
.pc-head {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 10px;
}
.pc-tier {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 500;
  color: #ffffff;
  background: var(--accent);
  padding: 3px 9px;
  border-radius: 999px;
  flex: 0 0 auto;
}
.pc-tier svg { width: 12px; height: 12px; flex: 0 0 auto; }
.pc-pinchip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 500;
  color: #475569;
  background: #f1f5f9;
  padding: 3px 9px;
  border-radius: 999px;
  flex: 0 0 auto;
}
.pc-pinchip svg { width: 12px; height: 12px; flex: 0 0 auto; }
.pc-spacer { flex: 1; }

/* ── title, body, event countdown ── */
.pc-title {
  margin: 0;
  font-size: 15px;
  font-weight: 500;
  line-height: 1.3;
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
  gap: 6px;
  margin-top: 5px;
}
.pc-event svg { width: 14px; height: 14px; color: var(--accent); flex: 0 0 auto; }
.pc-event-when { font-size: 12px; font-weight: 500; color: #334155; }
.pc-countdown {
  font-size: 10px;
  font-weight: 500;
  color: var(--accent);
  background: var(--accent-bg);
  padding: 2px 8px;
  border-radius: 999px;
}

/* ── divider + meta row ── */
.pc-divider {
  height: 1px;
  background: #e2e8f0;
  margin: 12px 0 10px;
}
.pc-meta {
  display: flex;
  align-items: center;
  gap: 8px;
}
.pc-avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: grid;
  place-items: center;
  font-size: 10px;
  font-weight: 500;
  color: #ffffff;
  /* PENTING keeps the danger red for "school ops" tone; other tiers land
     on the neutral teacher cobalt so the carousel doesn't repaint the
     dashboard. */
  background: #1b6fb8;
  flex: 0 0 auto;
}
.pinned-carousel.tier-penting .pc-avatar { background: var(--accent); }
.pc-author {
  font-size: 12px;
  font-weight: 500;
  color: #35435f;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 50%;
}
.pc-time { font-size: 11px; color: #94a3b8; flex: 0 0 auto; }
.pc-readmore {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  font-size: 12px;
  font-weight: 500;
  color: var(--accent);
  flex: 0 0 auto;
}
.pc-readmore svg { width: 13px; height: 13px; }
.pc-ack {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  font-size: 12px;
  font-weight: 500;
  color: #ffffff;
  background: var(--accent);
  padding: 7px 14px;
  border-radius: 999px;
  flex: 0 0 auto;
}
.pc-ack svg { width: 13px; height: 13px; }

/* ── dots ── */
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
  background: #cbd5e1;
  cursor: pointer;
  transition: all 0.25s ease;
}
.pc-dotbtn.is-active { width: 18px; background: var(--accent); }

/* Dark theme — this app is LIGHT-only for schools; dark is opt-in and
   class-driven via `.tutoring-dark` (tailwind darkMode: ['selector',
   '.tutoring-dark']), NOT the OS `prefers-color-scheme`. Scoping the dark
   styling to `.tutoring-dark` keeps the card LIGHT on every school dashboard
   even when the viewer's OS is in dark mode. */
.tutoring-dark .pc-card {
  background: #0f1a2e;
  border-color: #24324c;
}
.tutoring-dark .pc-title { color: #f1f5f9; }
.tutoring-dark .pc-snippet { color: #94a3b8; }
.tutoring-dark .pc-author,
.tutoring-dark .pc-event-when { color: #cbd5e1; }
.tutoring-dark .pc-pinchip { background: #1e293b; color: #cbd5e1; }
.tutoring-dark .pc-divider { background: #24324c; }
</style>
