<!--
  AdminControlCenterCard — the new hero slot for the admin dashboard.

  Combines the old readiness teaser + priority-inbox actionable signals
  into ONE navy-gradient card so the admin lands on "what needs my
  attention today" the moment the dashboard renders, without scrolling
  past a subscription strip.

  Composition (top → bottom):
    1. Header row  · left  = 🎛 icon + eyebrow "Kesiapan Sekolah" + title "Pusat Kendali"
                   · right = score (78%) + streak chip (🔥 5 hari) — hidden when !supported
    2. Alerts grid · 2 × 2 on lg, 1-col on mobile. Merges:
                       - readiness.attention_needed (Lane B — operational)
                       - overdue_bills             (finance)
                       - pending_lesson_plans      (academic)
                       - draft_announcements       (communication)
                     Each alert = badge angka + title + subtitle + arrow,
                     click → route to the relevant page. Ability-gated
                     per alert so a card that can't be reached never
                     renders.
    3. Quick-actions strip · 5-6 chips from the passed `quickActions`
                             array (already ability-filtered by parent).
                             "Semua" chip deep-links to the full grid
                             below (#quickActions slot) via a scroll anchor.

  Fallback modes:
    - `!readiness || !readiness.supported`: header degrades to the icon +
       "Pusat Kendali" only (no score / no streak / no attention items).
       Alerts still render for `overdue_bills` / `pending_lesson_plans` /
       `draft_announcements` so the actionable signal is preserved.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMeStore } from '@/stores/me';
import NavIcon from '@/components/feature/NavIcon.vue';
import type { ReadinessPayload, ReadinessAttentionItem } from '@/services/readiness.service';

interface QuickActionLike {
  labelKey: string;
  icon: string;
  to: string;
}

const props = defineProps<{
  /** Readiness payload from GET /admin/readiness (null when unsupported / not loaded). */
  readiness: ReadinessPayload | null;
  /** From admin dashboard stats payload. */
  pendingLessonPlans: number;
  draftAnnouncements: number;
  overdueBills: number;
  /**
   * Already ability-filtered quick-action list from the parent view.
   * We show at most `maxChips` (default 5) then append a "Lainnya" chip
   * that scrolls to the full quick-actions grid.
   */
  quickActions: QuickActionLike[];
  /** When true, the "Aktifkan Pusat Kendali" CTA replaces the header. */
  showEnableCta?: boolean;
}>();

const emit = defineEmits<{
  (e: 'enableClick'): void;
}>();

const router = useRouter();
const me = useMeStore();
const { t } = useI18n();

const supported = computed<boolean>(
  () => !!props.readiness && props.readiness.supported,
);
const score = computed<number | null>(
  () => (supported.value ? (props.readiness?.score ?? null) : null),
);
const streak = computed<number | null>(
  () => (supported.value ? (props.readiness?.streak ?? null) : null),
);
const attentionItems = computed<ReadinessAttentionItem[]>(
  () => (supported.value ? (props.readiness?.attention_needed ?? []) : []),
);

/**
 * Merged, prioritized alert list. Order:
 *   1. Readiness attention_needed items (server-side sorted by severity)
 *   2. Static stat-derived alerts (overdue bills, lesson plans, announcements)
 * Each is ability-gated so we never surface a click destination the user
 * can't open — silent-drop rather than showing a dead card.
 */
interface AlertCard {
  key: string;
  icon: string;
  title: string;
  subtitle: string;
  count: number;
  route: string;
  urgent: boolean;
}

const alerts = computed<AlertCard[]>(() => {
  const list: AlertCard[] = [];

  // 1. Readiness Lane B (operational) — already localised server-side.
  //    Every attention item is `urgent: true` because they mean actual
  //    operational blockers (unverified payments, expired kelas, dst.).
  for (const item of attentionItems.value.slice(0, 4)) {
    list.push({
      key: `attn-${item.id}`,
      icon: 'zap',
      title: item.label,
      subtitle: item.subtitle,
      count: item.count > 0 ? item.count : 1,
      route: mapAttentionRoute(item.target_route),
      urgent: item.severity === 'critical',
    });
  }

  // 2. Static per-stat alerts — each ability-gated on the destination.
  if (
    props.overdueBills > 0 &&
    me.can('finance.bill.view')
  ) {
    list.push({
      key: 'overdue-bills',
      icon: 'wallet',
      title: t('admin.controlCenter.alerts.overdueBillsTitle'),
      subtitle: t('admin.controlCenter.alerts.overdueBillsSub', { n: props.overdueBills }),
      count: props.overdueBills,
      route: '/admin/finance',
      urgent: true,
    });
  }
  if (
    props.pendingLessonPlans > 0 &&
    me.can('academic.lesson_plan.view')
  ) {
    list.push({
      key: 'pending-lp',
      icon: 'clipboard-list',
      title: t('admin.controlCenter.alerts.pendingLpTitle'),
      subtitle: t('admin.controlCenter.alerts.pendingLpSub', { n: props.pendingLessonPlans }),
      count: props.pendingLessonPlans,
      route: '/admin/lesson-plans',
      urgent: props.pendingLessonPlans >= 5,
    });
  }
  if (
    props.draftAnnouncements > 0 &&
    me.can('communication.announcement.view')
  ) {
    list.push({
      key: 'draft-ann',
      icon: 'megaphone',
      title: t('admin.controlCenter.alerts.draftAnnouncementsTitle'),
      subtitle: t('admin.controlCenter.alerts.draftAnnouncementsSub', { n: props.draftAnnouncements }),
      count: props.draftAnnouncements,
      route: '/admin/announcements',
      urgent: false,
    });
  }

  return list.slice(0, 4);
});

const noAlerts = computed(() => alerts.value.length === 0);

/**
 * Maps a backend route hint (e.g. `bills.list`) to a Vue router path.
 * Falls back to `/admin` if the hint isn't recognised so a
 * mid-session schema drift stays inside the shell instead of throwing.
 */
function mapAttentionRoute(target: string): string {
  const map: Record<string, string> = {
    'bills.list': '/admin/finance',
    'admin.finance': '/admin/finance',
    'lesson-plans.list': '/admin/lesson-plans',
    'admin.lesson_plans': '/admin/lesson-plans',
    'announcements.list': '/admin/announcements',
    'admin.announcements': '/admin/announcements',
    'admin.readiness': '/admin/readiness',
  };
  return map[target] ?? '/admin/readiness';
}

/**
 * Chips shown in the strip below alerts. We keep 5 most-recognisable
 * quick actions and append a "Lainnya" chip that scrolls the page to
 * the full quick-actions grid (marked by `#quick-actions-anchor` in the
 * parent view).
 */
const featuredChips = computed(() => {
  const priority = [
    'nav.students',
    'nav.teachers',
    'nav.schedule',
    'nav.attendance',
    'nav.gradeRecap',
    'nav.finance',
    'nav.announcements',
  ];
  const picked: QuickActionLike[] = [];
  for (const key of priority) {
    if (picked.length >= 5) break;
    const found = props.quickActions.find((a) => a.labelKey === key);
    if (found) picked.push(found);
  }
  // If tenant lacks the "priority" set (e.g. staff-only bimbel), fill
  // from whatever ability-filtered actions parent passed so the strip
  // still has content.
  if (picked.length === 0) {
    picked.push(...props.quickActions.slice(0, 5));
  }
  return picked;
});

const showOverflowChip = computed(
  () => props.quickActions.length > featuredChips.value.length,
);

function goto(route: string) {
  router.push(route);
}

function gotoReadiness() {
  router.push({ name: 'admin.readiness' });
}

function scrollToQuickActions() {
  // Anchor id lives in the parent view (`#quick-actions-anchor`).
  const el = document.getElementById('quick-actions-anchor');
  if (el) {
    el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
}
</script>

<template>
  <section
    class="acc"
    :class="{ 'acc--enable-only': showEnableCta && noAlerts }"
  >
    <!-- Header row: title on the left, score + streak on the right. -->
    <header class="acc-head">
      <button
        type="button"
        class="acc-head-title"
        :aria-label="t('admin.controlCenter.openFull')"
        @click="gotoReadiness"
      >
        <span class="acc-head-icon" aria-hidden="true">
          <NavIcon name="gauge" :size="20" />
        </span>
        <span class="acc-head-copy">
          <span class="acc-eyebrow">{{ t('admin.controlCenter.eyebrow') }}</span>
          <span class="acc-title">{{ t('admin.controlCenter.title') }}</span>
        </span>
      </button>

      <div v-if="supported && score !== null" class="acc-head-metrics">
        <div class="acc-score">
          <span class="acc-score-value">{{ score }}<span class="acc-score-pct">%</span></span>
          <span class="acc-score-label">{{ t('admin.readiness.scoreLabel') }}</span>
        </div>
        <span
          v-if="streak !== null && streak > 0"
          class="acc-streak"
          :title="t('admin.readiness.teaserStreakBadge', { days: streak })"
        >
          <NavIcon name="flame" :size="12" />
          {{ t('admin.controlCenter.streakShort', { days: streak }) }}
        </span>
      </div>

      <!-- Enable-CTA fallback: readiness ability granted but tenant not supported. -->
      <button
        v-else-if="showEnableCta"
        type="button"
        class="acc-enable-cta"
        @click="emit('enableClick')"
      >
        {{ t('admin.controlCenter.enableCta') }}
        <NavIcon name="arrow-right" :size="12" />
      </button>
    </header>

    <!-- Alerts grid: 2×2 on lg, 1 column on mobile. -->
    <div v-if="alerts.length > 0" class="acc-alerts">
      <button
        v-for="a in alerts"
        :key="a.key"
        type="button"
        class="acc-alert"
        :class="{ 'acc-alert--urgent': a.urgent }"
        @click="goto(a.route)"
      >
        <span class="acc-alert-badge" aria-hidden="true">{{ a.count }}</span>
        <span class="acc-alert-body">
          <span class="acc-alert-title">
            <NavIcon :name="a.icon" :size="14" />
            {{ a.title }}
          </span>
          <span class="acc-alert-sub">{{ a.subtitle }}</span>
        </span>
        <NavIcon class="acc-alert-arrow" name="arrow-right" :size="14" />
      </button>
    </div>

    <!-- Empty state when supported=true but no active alerts: keep it
         positive and encourage the deep-dive rather than showing an
         empty band. -->
    <div v-else-if="supported" class="acc-empty">
      <NavIcon name="check-circle" :size="16" />
      <span>{{ t('admin.controlCenter.allCalm') }}</span>
    </div>

    <!-- Quick-actions chip strip. Hidden when the parent passes zero
         actions (tenant with no entitled destinations). -->
    <div v-if="featuredChips.length > 0" class="acc-chips">
      <button
        v-for="c in featuredChips"
        :key="c.to"
        type="button"
        class="acc-chip"
        @click="goto(c.to)"
      >
        <NavIcon :name="c.icon" :size="14" />
        <span>{{ t(c.labelKey) }}</span>
      </button>
      <button
        v-if="showOverflowChip"
        type="button"
        class="acc-chip acc-chip--more"
        @click="scrollToQuickActions"
      >
        <NavIcon name="more-horizontal" :size="14" />
        <span>{{ t('admin.controlCenter.moreActions') }}</span>
      </button>
    </div>
  </section>
</template>

<style scoped>
/* Navy gradient hero — same tokens as `bg-role-admin-gradient` in
   tailwind.config.ts, inlined here so scoped styles don't need a JIT
   round-trip. Rounded like the sibling cards and lifted with a soft
   shadow so it reads as the top-of-page anchor. */
.acc {
  background: linear-gradient(120deg, #0A1F4D 0%, #143068 60%, #143068 100%);
  color: #FFFFFF;
  border-radius: 20px;
  padding: 18px 20px;
  box-shadow: 0 10px 24px -12px rgba(20, 48, 104, 0.55);
  display: flex;
  flex-direction: column;
  gap: 16px;
  position: relative;
  overflow: hidden;
}

/* Subtle top-right glow so the card has some depth without pulling
   attention from the alert list. */
.acc::before {
  content: '';
  position: absolute;
  top: -60px;
  right: -60px;
  width: 220px;
  height: 220px;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.12) 0%, transparent 70%);
  pointer-events: none;
}

/* ── Header row ────────────────────────────────────────────────── */
.acc-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
  position: relative;
}

.acc-head-title {
  display: flex;
  align-items: center;
  gap: 12px;
  background: transparent;
  border: none;
  padding: 0;
  cursor: pointer;
  color: inherit;
  text-align: left;
  min-width: 0;
}
.acc-head-title:hover .acc-title {
  text-decoration: underline;
  text-decoration-color: rgba(255, 255, 255, 0.5);
}

.acc-head-icon {
  width: 44px;
  height: 44px;
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.14);
  display: grid;
  place-items: center;
  flex-shrink: 0;
  color: #FFFFFF;
}

.acc-head-copy {
  display: flex;
  flex-direction: column;
  min-width: 0;
}
.acc-eyebrow {
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.72);
  text-transform: uppercase;
  letter-spacing: 0.9px;
}
.acc-title {
  font-size: 20px;
  font-weight: 800;
  letter-spacing: -0.3px;
  line-height: 1.1;
  color: #FFFFFF;
}

.acc-head-metrics {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-shrink: 0;
}

.acc-score {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  line-height: 1;
}
.acc-score-value {
  font-size: 28px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.6px;
  color: #FFFFFF;
}
.acc-score-pct {
  font-size: 16px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.75);
  margin-left: 2px;
}
.acc-score-label {
  font-size: 10.5px;
  font-weight: 700;
  color: rgba(255, 255, 255, 0.7);
  text-transform: uppercase;
  letter-spacing: 0.6px;
  margin-top: 2px;
}

.acc-streak {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  background: rgba(255, 255, 255, 0.14);
  color: #FFFFFF;
  font-size: 11px;
  font-weight: 700;
  padding: 6px 10px;
  border-radius: 999px;
  white-space: nowrap;
}

.acc-enable-cta {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: rgba(255, 255, 255, 0.18);
  color: #FFFFFF;
  border: 1px solid rgba(255, 255, 255, 0.28);
  border-radius: 10px;
  font-size: 11.5px;
  font-weight: 700;
  padding: 8px 14px;
  cursor: pointer;
  text-transform: uppercase;
  letter-spacing: 0.4px;
  transition: background 0.15s;
}
.acc-enable-cta:hover {
  background: rgba(255, 255, 255, 0.28);
}

/* ── Alerts grid ───────────────────────────────────────────────── */
.acc-alerts {
  display: grid;
  grid-template-columns: 1fr;
  gap: 10px;
  position: relative;
}
@media (min-width: 1024px) {
  .acc-alerts {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.acc-alert {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  background: rgba(255, 255, 255, 0.10);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 14px;
  color: #FFFFFF;
  text-align: left;
  cursor: pointer;
  transition:
    background 0.15s,
    border-color 0.15s,
    transform 0.05s;
}
.acc-alert:hover {
  background: rgba(255, 255, 255, 0.16);
  border-color: rgba(255, 255, 255, 0.3);
}
.acc-alert:active {
  transform: translateY(1px);
}

.acc-alert-badge {
  min-width: 32px;
  height: 32px;
  padding: 0 8px;
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.18);
  color: #FFFFFF;
  font-weight: 800;
  font-size: 13px;
  font-variant-numeric: tabular-nums;
  display: grid;
  place-items: center;
  flex-shrink: 0;
}
.acc-alert--urgent .acc-alert-badge {
  background: #FB7185;  /* rose-400 */
  color: #FFFFFF;
  box-shadow: 0 0 0 1px rgba(251, 113, 133, 0.4);
}

.acc-alert-body {
  display: flex;
  flex-direction: column;
  min-width: 0;
  gap: 2px;
}
.acc-alert-title {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12.5px;
  font-weight: 700;
  color: #FFFFFF;
  line-height: 1.2;
}
.acc-alert-sub {
  font-size: 11px;
  color: rgba(255, 255, 255, 0.78);
  font-weight: 500;
  line-height: 1.35;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}

.acc-alert-arrow {
  color: rgba(255, 255, 255, 0.6);
  flex-shrink: 0;
}
.acc-alert:hover .acc-alert-arrow {
  color: #FFFFFF;
}

/* Empty state (supported but no alerts) — sober "all clear" strip. */
.acc-empty {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  background: rgba(255, 255, 255, 0.10);
  border: 1px solid rgba(255, 255, 255, 0.18);
  border-radius: 12px;
  font-size: 12px;
  font-weight: 600;
  color: rgba(255, 255, 255, 0.88);
  align-self: flex-start;
}

/* ── Chip strip ────────────────────────────────────────────────── */
.acc-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding-top: 4px;
  border-top: 1px solid rgba(255, 255, 255, 0.14);
  padding-top: 12px;
}
.acc-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 7px 12px;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.14);
  border: 1px solid rgba(255, 255, 255, 0.22);
  color: #FFFFFF;
  font-size: 11.5px;
  font-weight: 700;
  cursor: pointer;
  transition:
    background 0.15s,
    border-color 0.15s;
  white-space: nowrap;
}
.acc-chip:hover {
  background: rgba(255, 255, 255, 0.22);
  border-color: rgba(255, 255, 255, 0.35);
}
.acc-chip--more {
  background: rgba(255, 255, 255, 0.06);
  border-style: dashed;
}

/* Enable-only fallback (readiness NOT supported + no alerts): shrink
   padding + hide alerts row so we don't leave a big empty band. */
.acc--enable-only {
  padding: 16px 18px;
  gap: 10px;
}
.acc--enable-only .acc-chips {
  border-top: none;
  padding-top: 0;
}
</style>
