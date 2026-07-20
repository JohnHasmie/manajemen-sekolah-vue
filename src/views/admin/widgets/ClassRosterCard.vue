<!--
  ClassRosterCard.vue — admin "Data Kelas" list card.

  Redesigned 2026-07-20 (Yahya feedback: "kartu kelas terlalu berwarna,
  kiri-kanan seperti kartu terpisah, kurang user-friendly"). The prior
  two-column split (identity strip · body strip) with a dashed vertical
  divider read as two related-but-separate cards; the roster avatar
  cluster + capacity bar + subject chips all competed for attention at
  the same visual weight.

  Now: one unified card, single visual hierarchy.

    ┌─────────────────────────────────────────────────────────┐
    │ [avatar]  Kelas 7A                              [⋮]     │
    │           Tingkat 7 · TP 2026/2027 · Aktif              │
    │                                                          │
    │ 👤 Wali kelas: Elyariza Devy A.F.                       │
    │                                                          │
    │ ┌ Siswa terdaftar                        9 / 36 ────┐   │
    │ │ ▓▓▓░░░░░░░░░░░░░░░                                 │   │
    │ └────────────────────────────────────────────────────┘   │
    │                                                          │
    │ 📖 8 mapel · 12 sesi/minggu              Detail →       │
    └─────────────────────────────────────────────────────────┘

  Design locks:
    * Single accent per card (accentColor) — no palette derived from
      initials; roster avatars removed entirely (surface via Detail).
    * Meta is one text row (Tingkat · TP · status) instead of three
      pills fighting for attention.
    * Capacity gets its own compact strip with hairline progress bar;
      color follows a single semantic ramp (safe → warn → full).
    * Actions collapse into `Detail →` link + kebab menu (Hapus lives
      inside the kebab so misclick risk drops).
    * Layout is a stack — no 260px identity strip that stacked awkwardly
      below 900px. Full-width elements read the same at every width.

  Same props / emits as the pre-redesign card so callers don't change.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import type { Classroom } from '@/types/entities';

const props = withDefaults(
  defineProps<{
    classroom: Classroom;
    /** Human-readable TA label (e.g. "2025/2026") — passed from the
     * view because the classroom row only carries academic_year_id. */
    academicYearLabel?: string;
    accentColor?: string;
    selected?: boolean;
    /** When true, the card behaves as a long-press bulk-select target. */
    bulkSelectable?: boolean;
  }>(),
  {
    academicYearLabel: '',
    accentColor: '#1B6FB8',
    selected: false,
    bulkSelectable: false,
  },
);

const emit = defineEmits<{
  click: [MouseEvent];
  longPress: [];
  detail: [];
  delete: [];
}>();

// ── Capacity ─────────────────────────────────────────────────────
// BE ships `capacity: {current, max}`; fall back to flat student_count
// + soft 36 max when the enriched payload is missing so the bar still
// renders on a pre-deploy backend.
const capacityCurrent = computed(
  () => props.classroom.capacity?.current ?? props.classroom.student_count ?? 0,
);
const capacityMax = computed(() => props.classroom.capacity?.max ?? 36);
const capacityPct = computed(() => {
  if (capacityMax.value <= 0) return 0;
  return Math.min(
    100,
    Math.round((capacityCurrent.value / capacityMax.value) * 100),
  );
});
// Single semantic ramp — the color IS the message: 0-70% neutral
// (using the card's accent so it reads as "part of the card"), 70-90%
// amber (filling up), 90+ red (over-crowded). This is the ONLY hue
// besides accent + slate on the card.
const capacityBarColor = computed(() => {
  const pct = capacityPct.value;
  if (pct >= 90) return '#EF4444'; // status danger — over-crowded
  if (pct >= 70) return '#F59E0B'; // status warning — filling up
  return props.accentColor;
});

// ── Subjects meta line ───────────────────────────────────────────
const subjectsCount = computed(
  () => props.classroom.subjects_count ?? props.classroom.subjects_top3?.length ?? 0,
);
const subjectsMeta = computed<string | null>(() => {
  if (subjectsCount.value === 0) return null;
  return `${subjectsCount.value} mapel dijadwalkan`;
});

// ── Wali kelas ──────────────────────────────────────────────────
const wali = computed(() => props.classroom.wali_teacher ?? null);
const waliName = computed(
  () => wali.value?.name ?? props.classroom.homeroom_teacher_name ?? null,
);

// ── Grade label ──────────────────────────────────────────────────
const gradeLabel = computed(() => {
  const g = props.classroom.grade_level;
  if (g === null || g === undefined) return null;
  return `Tingkat ${g}`;
});

// ── Class code (avatar) ─────────────────────────────────────────
const codeChars = computed(() => (props.classroom.name || '?').slice(0, 3).toUpperCase());

// ── Kebab menu ──────────────────────────────────────────────────
const menuOpen = ref(false);
function toggleMenu(e: Event) {
  e.stopPropagation();
  menuOpen.value = !menuOpen.value;
}
function onDelete(e: Event) {
  e.stopPropagation();
  menuOpen.value = false;
  emit('delete');
}
function closeMenu() {
  if (menuOpen.value) menuOpen.value = false;
}

// ── Long-press bulk-select (retained for compat) ────────────────
let longPressTimer: ReturnType<typeof setTimeout> | null = null;
function onPointerDown() {
  if (!props.bulkSelectable) return;
  if (longPressTimer) clearTimeout(longPressTimer);
  longPressTimer = setTimeout(() => {
    longPressTimer = null;
    emit('longPress');
  }, 500);
}
function onPointerUp() {
  if (longPressTimer) {
    clearTimeout(longPressTimer);
    longPressTimer = null;
  }
}
</script>

<template>
  <div
    class="class-card"
    :class="{ 'class-card--selected': selected }"
    :style="{ '--class-card-accent': accentColor }"
    @click="(e) => { closeMenu(); emit('click', e); }"
    @pointerdown="onPointerDown"
    @pointerup="onPointerUp"
    @pointerleave="onPointerUp"
  >
    <!-- Header row: avatar · name+meta · kebab -->
    <div class="class-card__head">
      <span class="class-card__avatar" aria-hidden="true">{{ codeChars }}</span>
      <div class="class-card__title">
        <p class="class-card__name">{{ classroom.name || '—' }}</p>
        <p class="class-card__meta">
          <template v-if="gradeLabel">{{ gradeLabel }}</template>
          <template v-if="gradeLabel && academicYearLabel"> · </template>
          <template v-if="academicYearLabel">TP {{ academicYearLabel }}</template>
          <template v-if="gradeLabel || academicYearLabel"> · </template>
          <span class="class-card__meta-status">Aktif</span>
        </p>
      </div>
      <div class="class-card__menu-wrap" @click.stop>
        <button
          type="button"
          class="class-card__menu-trigger"
          aria-label="Menu"
          :aria-expanded="menuOpen"
          @click="toggleMenu"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="18" height="18">
            <circle cx="12" cy="5" r="1" />
            <circle cx="12" cy="12" r="1" />
            <circle cx="12" cy="19" r="1" />
          </svg>
        </button>
        <div v-if="menuOpen" class="class-card__menu" role="menu">
          <button type="button" role="menuitem" class="class-card__menu-item class-card__menu-item--danger" @click="onDelete">
            Hapus kelas
          </button>
        </div>
      </div>
    </div>

    <!-- Wali kelas — always shown; muted placeholder when unset. -->
    <div class="class-card__row">
      <svg class="class-card__row-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" width="14" height="14">
        <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
        <circle cx="12" cy="7" r="4" />
      </svg>
      <span class="class-card__row-label">Wali kelas:</span>
      <span v-if="waliName" class="class-card__row-value">{{ waliName }}</span>
      <span v-else class="class-card__row-empty">belum ditetapkan</span>
    </div>

    <!-- Capacity strip -->
    <div class="class-card__capacity">
      <div class="class-card__capacity-head">
        <span class="class-card__capacity-label">Siswa terdaftar</span>
        <span class="class-card__capacity-count">
          <span class="class-card__capacity-current">{{ capacityCurrent }}</span>
          <span class="class-card__capacity-slash"> / {{ capacityMax }}</span>
        </span>
      </div>
      <div class="class-card__bar" :aria-label="`${capacityPct}% kapasitas`">
        <div
          class="class-card__bar-fill"
          :style="{
            width: `${capacityPct}%`,
            background: capacityBarColor,
          }"
        />
      </div>
    </div>

    <!-- Footer: mapel meta line + Detail link -->
    <div class="class-card__foot">
      <span class="class-card__foot-meta">
        <svg class="class-card__foot-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" width="14" height="14">
          <path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20" />
        </svg>
        <template v-if="subjectsMeta">{{ subjectsMeta }}</template>
        <template v-else>Belum ada jadwal mapel</template>
      </span>
      <button
        type="button"
        class="class-card__detail"
        :style="{ color: accentColor }"
        @click.stop="emit('detail')"
      >
        Detail
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="12" height="12">
          <line x1="5" y1="12" x2="19" y2="12" />
          <polyline points="12 5 19 12 12 19" />
        </svg>
      </button>
    </div>
  </div>
</template>

<style scoped>
/*
 * Container — flat white surface, 12px radius, hairline border.
 * NO shadow-card at rest (only on hover) so a grid of cards doesn't
 * flood the page with drop shadows.
 */
.class-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
  background: #fff;
  border-radius: 12px;
  border: 1px solid rgb(226 232 240);           /* slate-200 */
  cursor: pointer;
  transition: border-color 150ms ease, box-shadow 150ms ease;
  --class-card-accent: #1B6FB8;
}
.class-card:hover {
  border-color: rgb(203 213 225);               /* slate-300 */
  box-shadow: 0 4px 12px -4px rgb(0 0 0 / 0.08);
}
.class-card--selected {
  border-color: var(--class-card-accent);
  box-shadow: 0 0 0 2px var(--class-card-accent);
}

/* ── Header ─────────────────────────────────────────────────── */
.class-card__head {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  min-width: 0;
}
.class-card__avatar {
  width: 44px;
  height: 44px;
  border-radius: 10px;
  background: color-mix(in srgb, var(--class-card-accent) 12%, transparent);
  color: var(--class-card-accent);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 700;
  letter-spacing: 0.02em;
  flex-shrink: 0;
}
.class-card__title {
  flex: 1;
  min-width: 0;
}
.class-card__name {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.class-card__meta {
  margin: 2px 0 0;
  font-size: 12px;
  color: rgb(100 116 139);                       /* slate-500 */
  line-height: 1.4;
}
.class-card__meta-status {
  color: #047857;                                /* emerald-700 — one green for "aktif" */
  font-weight: 500;
}

/* ── Kebab ──────────────────────────────────────────────────── */
.class-card__menu-wrap {
  position: relative;
  flex-shrink: 0;
}
.class-card__menu-trigger {
  background: transparent;
  border: none;
  color: rgb(148 163 184);                       /* slate-400 */
  cursor: pointer;
  padding: 4px;
  margin: -4px;
  display: grid;
  place-items: center;
  border-radius: 6px;
}
.class-card__menu-trigger:hover {
  background: rgb(241 245 249);                  /* slate-100 */
  color: rgb(71 85 105);                         /* slate-600 */
}
.class-card__menu {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  min-width: 160px;
  background: #fff;
  border: 1px solid rgb(226 232 240);
  border-radius: 8px;
  box-shadow: 0 8px 24px -6px rgb(0 0 0 / 0.12);
  padding: 4px;
  z-index: 10;
}
.class-card__menu-item {
  display: block;
  width: 100%;
  text-align: left;
  padding: 8px 10px;
  background: transparent;
  border: none;
  font-size: 13px;
  color: rgb(30 41 59);                          /* slate-800 */
  cursor: pointer;
  border-radius: 6px;
}
.class-card__menu-item:hover {
  background: rgb(248 250 252);                  /* slate-50 */
}
.class-card__menu-item--danger {
  color: #B91C1C;                                /* red-700 — text-only; hover tint stays subtle */
}
.class-card__menu-item--danger:hover {
  background: #FEF2F2;                           /* red-50 */
}

/* ── Info row (wali) ────────────────────────────────────────── */
.class-card__row {
  display: flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
  font-size: 12.5px;
  color: rgb(71 85 105);                         /* slate-600 */
  line-height: 1.4;
}
.class-card__row-icon {
  color: rgb(148 163 184);                       /* slate-400 */
  flex-shrink: 0;
}
.class-card__row-label {
  color: rgb(100 116 139);                       /* slate-500 */
}
.class-card__row-value {
  color: rgb(15 23 42);                          /* slate-900 */
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}
.class-card__row-empty {
  color: rgb(148 163 184);                       /* slate-400 */
  font-style: italic;
}

/* ── Capacity strip ─────────────────────────────────────────── */
.class-card__capacity {
  padding: 10px 12px;
  background: rgb(248 250 252);                  /* slate-50 */
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.class-card__capacity-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}
.class-card__capacity-label {
  font-size: 12px;
  color: rgb(100 116 139);                       /* slate-500 */
}
.class-card__capacity-count {
  font-size: 13px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.class-card__capacity-current {
  font-weight: 700;
  color: rgb(15 23 42);                          /* slate-900 */
}
.class-card__capacity-slash {
  color: rgb(148 163 184);                       /* slate-400 */
  font-weight: 400;
}
.class-card__bar {
  height: 4px;
  border-radius: 999px;
  background: rgb(226 232 240);                  /* slate-200 */
  overflow: hidden;
}
.class-card__bar-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 250ms ease, background 200ms ease;
}

/* ── Footer ─────────────────────────────────────────────────── */
.class-card__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding-top: 4px;
  border-top: 1px solid rgb(241 245 249);        /* slate-100 */
}
.class-card__foot-meta {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: rgb(100 116 139);                       /* slate-500 */
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.class-card__foot-icon {
  color: rgb(148 163 184);                       /* slate-400 */
  flex-shrink: 0;
}
.class-card__detail {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 12.5px;
  font-weight: 500;
  white-space: nowrap;
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 4px 0;
}
.class-card__detail:hover {
  text-decoration: underline;
}
</style>
