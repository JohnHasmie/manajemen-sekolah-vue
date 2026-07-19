<!--
  ClassRosterCard.vue — the roster-preview card that replaces the
  compact BrandListRow variant on the admin "Data Kelas" page.
  Wireframe: Entitas 3 · Opsi B (Roster preview + capacity progress
  + top-3 mapel chips).

  Layout (>= lg / desktop):
    ┌ IDENTITY (260px) ─────────┬ BODY (flex-1) ──────────────────┐
    │ [Nama Kelas]              │ [current]/[max] siswa · [pct]%  │
    │ Tingkat X · TA · Aktif    │ [progress bar]                  │
    │                           │ [av][av][av][av][av] +[N-5]     │
    │ 👤 [avatar] Wali kelas    │                                 │
    │ 📍 Lantai · Ruangan       │ [count] MAPEL DIAJARKAN         │
    │                           │ [MTK · Matematika] [+N lainnya] │
    │ [Detail →] [Hapus]        │                                 │
    └───────────────────────────┴─────────────────────────────────┘

  Below ~900px the two columns stack vertically; the identity dashed
  divider becomes a bottom border.

  Selection: long-press or bulk-check the card to toggle selection.
  When selected, a check overlay lands on the class avatar chip and
  the whole card gains an accent ring, mirroring TeacherStructuredCard.
-->
<script setup lang="ts">
import { computed } from 'vue';
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

// ── Roster preview + capacity ────────────────────────────────────
// The BE MR ships `capacity: {current, max}` — fall back to the flat
// `student_count` with a soft 36 max when the enriched payload is
// missing so the bar still renders on a pre-deploy backend.
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
const capacityBarColor = computed(() => {
  const pct = capacityPct.value;
  if (pct >= 90) return '#ef4444'; // red — over-crowded
  if (pct >= 70) return '#f59e0b'; // amber — filling up
  return '#10b981'; // green — healthy
});
const isFull = computed(() => capacityPct.value >= 100);

const previewStudents = computed(() => props.classroom.students_preview ?? []);
const overflowCount = computed(() =>
  Math.max(0, capacityCurrent.value - previewStudents.value.length),
);

// ── Subjects ─────────────────────────────────────────────────────
const subjectChips = computed(() => {
  const arr = props.classroom.subjects_top3 ?? [];
  return arr.map((s) => ({
    key: s.id || s.name,
    label: s.code ? `${s.code} · ${s.name}` : s.name,
  }));
});
const subjectsCount = computed(
  () => props.classroom.subjects_count ?? subjectChips.value.length,
);
const subjectsOverflow = computed(
  () => Math.max(0, subjectsCount.value - subjectChips.value.length),
);

// ── Wali + location ──────────────────────────────────────────────
const wali = computed(() => props.classroom.wali_teacher ?? null);
const location = computed(() => props.classroom.location ?? null);
const locationText = computed(() => {
  const loc = location.value;
  if (!loc) return null;
  const parts: string[] = [];
  if (loc.floor) parts.push(loc.floor);
  if (loc.room) parts.push(loc.room);
  if (parts.length === 0) return null;
  return parts.join(' · ');
});

// ── Avatar background palette derived from initials ──────────────
// Six soft brand-neutral tones — index = charCode(first letter) % 6.
// White text on the darker three (blue/purple/teal), navy on the
// lighter three (green/pink/amber).
const AVATAR_PALETTE: Array<{ bg: string; fg: string }> = [
  { bg: '#DBEAFE', fg: '#1E3A8A' }, // blue-100 / navy-800
  { bg: '#DCFCE7', fg: '#166534' }, // green-100 / green-800
  { bg: '#EDE9FE', fg: '#5B21B6' }, // violet-100 / violet-800
  { bg: '#FCE7F3', fg: '#9D174D' }, // pink-100 / pink-800
  { bg: '#FEF3C7', fg: '#92400E' }, // amber-100 / amber-800
  { bg: '#CCFBF1', fg: '#115E59' }, // teal-100 / teal-800
];
function avatarStyle(initials: string): { background: string; color: string } {
  const seed = (initials || '?').trim().charCodeAt(0) || 0;
  const t = AVATAR_PALETTE[seed % AVATAR_PALETTE.length];
  return { background: t.bg, color: t.fg };
}

// ── Grade label ──────────────────────────────────────────────────
const gradeLabel = computed(() => {
  const g = props.classroom.grade_level;
  if (!g) return null;
  return `Tingkat ${g}`;
});

// ── Long-press bulk-select (mirrors TeacherStructuredCard) ───────
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
    :style="selected ? { '--class-card-accent': accentColor } : {}"
    @click="emit('click', $event)"
    @pointerdown="onPointerDown"
    @pointerup="onPointerUp"
    @pointerleave="onPointerUp"
  >
    <!-- LEFT · Identity -------------------------------------------- -->
    <div class="class-card__identity">
      <div class="class-card__identity-head">
        <span
          class="class-card__class-avatar"
          :style="avatarStyle(classroom.name)"
        >
          {{ (classroom.name || '?').slice(0, 2).toUpperCase() }}
          <span
            v-if="selected"
            class="class-card__check"
            :style="{ color: accentColor }"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="3"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="w-3 h-3"
            >
              <polyline points="20 6 9 17 4 12" />
            </svg>
          </span>
        </span>
        <div class="class-card__identity-title">
          <p class="class-card__name">{{ classroom.name || '—' }}</p>
        </div>
      </div>

      <div class="class-card__meta-chips">
        <span v-if="gradeLabel" class="class-card__meta-chip">
          {{ gradeLabel }}
        </span>
        <span v-if="academicYearLabel" class="class-card__meta-chip">
          {{ academicYearLabel }}
        </span>
        <span class="class-card__meta-chip class-card__meta-chip--status">
          Aktif
        </span>
      </div>

      <!-- Wali row — always shown; muted placeholder when unset. -->
      <div class="class-card__row">
        <span class="class-card__row-icon" aria-hidden="true">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-3.5 h-3.5"
          >
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
            <circle cx="12" cy="7" r="4" />
          </svg>
        </span>
        <template v-if="wali">
          <span
            class="class-card__wali-avatar"
            :style="avatarStyle(wali.avatar_initials || wali.name)"
          >
            {{ wali.avatar_initials || (wali.name || '?').slice(0, 2).toUpperCase() }}
          </span>
          <span class="class-card__row-text">{{ wali.name }}</span>
        </template>
        <template v-else>
          <span class="class-card__row-empty">Wali kelas belum ditetapkan</span>
        </template>
      </div>

      <!-- Location row — hidden entirely when both floor + room are null. -->
      <div v-if="locationText" class="class-card__row">
        <span class="class-card__row-icon" aria-hidden="true">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="1.8"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="w-3.5 h-3.5"
          >
            <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z" />
            <circle cx="12" cy="10" r="3" />
          </svg>
        </span>
        <span class="class-card__row-text">{{ locationText }}</span>
      </div>

      <!-- Identity-column footer actions — parity with the previous
           BrandListRow trailing/inline actions on this view. -->
      <div class="class-card__actions">
        <button
          type="button"
          class="class-card__detail"
          :style="{ color: accentColor }"
          @click.stop="emit('detail')"
        >Detail →</button>
        <button
          type="button"
          class="class-card__delete"
          @click.stop="emit('delete')"
        >Hapus</button>
      </div>
    </div>

    <!-- RIGHT · Body ---------------------------------------------- -->
    <div class="class-card__body">
      <!-- Capacity summary + progress -->
      <div class="class-card__capacity">
        <div class="class-card__capacity-head">
          <span class="class-card__capacity-count">
            <span class="class-card__capacity-current">{{ capacityCurrent }}</span>
            <span class="class-card__capacity-slash">/</span>
            <span class="class-card__capacity-max">{{ capacityMax }}</span>
            <span class="class-card__capacity-word">siswa</span>
          </span>
          <span class="class-card__capacity-pct">· {{ capacityPct }}%</span>
          <span
            v-if="isFull"
            class="class-card__full-pill"
            :style="{ background: capacityBarColor }"
          >PENUH</span>
        </div>
        <div class="class-card__bar">
          <div
            class="class-card__bar-fill"
            :style="{
              width: `${capacityPct}%`,
              background: capacityBarColor,
            }"
          />
        </div>
      </div>

      <!-- Roster avatars -->
      <div class="class-card__roster">
        <template v-if="previewStudents.length > 0">
          <span
            v-for="s in previewStudents"
            :key="s.id"
            class="class-card__student-avatar"
            :style="avatarStyle(s.avatar_initials || s.name)"
            :title="s.name"
          >{{ s.avatar_initials || (s.name || '?').slice(0, 2).toUpperCase() }}</span>
          <span
            v-if="overflowCount > 0"
            class="class-card__student-avatar class-card__student-avatar--overflow"
            :title="`+${overflowCount} siswa lain`"
          >+{{ overflowCount }}</span>
        </template>
        <span v-else class="class-card__row-empty">Belum ada siswa</span>
      </div>

      <!-- Subject chips + count -->
      <div class="class-card__subjects">
        <p class="class-card__subjects-label">
          <template v-if="subjectsCount > 0">
            {{ subjectsCount }} Mapel Diajarkan
          </template>
          <template v-else>
            Mapel Diajarkan
          </template>
        </p>
        <div v-if="subjectChips.length > 0" class="class-card__chips">
          <span
            v-for="s in subjectChips"
            :key="s.key"
            class="class-card__chip"
          >{{ s.label }}</span>
          <span
            v-if="subjectsOverflow > 0"
            class="class-card__chip class-card__chip--more"
          >+{{ subjectsOverflow }} lainnya</span>
        </div>
        <span v-else class="class-card__row-empty">
          Belum ada jadwal mapel
        </span>
      </div>
    </div>
  </div>
</template>

<style scoped>
/*
 * Card container — mirrors TeacherStructuredCard's rounded/shadowed
 * surface but switches to a 260px identity split per the roster
 * wireframe (narrower than the teacher card so more chart real
 * estate lives in the right column).
 */
.class-card {
  display: grid;
  grid-template-columns: 260px 1fr;
  gap: 20px;
  padding: 16px;
  background: #fff;
  border-radius: 16px;
  border: 1px solid rgb(226 232 240);           /* slate-200 */
  box-shadow:
    0 1px 2px 0 rgb(0 0 0 / 0.04),
    0 4px 16px -2px rgb(0 0 0 / 0.06);
  cursor: pointer;
  transition: box-shadow 150ms ease, border-color 150ms ease;
  --class-card-accent: #1B6FB8;
}
.class-card:hover {
  box-shadow:
    0 2px 4px 0 rgb(0 0 0 / 0.06),
    0 8px 24px -4px rgb(0 0 0 / 0.08);
}
.class-card--selected {
  border-color: var(--class-card-accent);
  box-shadow:
    0 0 0 2px var(--class-card-accent),
    0 4px 16px -2px rgb(0 0 0 / 0.06);
}

/* ── Identity column ─────────────────────────────────────────── */
.class-card__identity {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-right: 20px;
  border-right: 1px dashed rgb(203 213 225);    /* slate-300 */
  min-width: 0;
}
.class-card__identity-head {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}
.class-card__class-avatar {
  position: relative;
  width: 40px;
  height: 40px;
  border-radius: 10px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  font-weight: 700;
  flex-shrink: 0;
}
.class-card__check {
  position: absolute;
  top: -4px;
  right: -4px;
  width: 18px;
  height: 18px;
  border-radius: 999px;
  background: #fff;
  display: grid;
  place-items: center;
  box-shadow: 0 0 0 2px currentColor;
}
.class-card__identity-title {
  min-width: 0;
  flex: 1;
}
.class-card__name {
  font-size: 20px;
  font-weight: 600;
  color: rgb(15 23 42);                         /* slate-900 */
  line-height: 1.2;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.class-card__meta-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
.class-card__meta-chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  background: rgb(241 245 249);                  /* slate-100 */
  border: 1px solid rgb(226 232 240);            /* slate-200 */
  font-size: 11px;
  color: rgb(51 65 85);                          /* slate-700 */
  font-weight: 500;
  line-height: 1.4;
}
.class-card__meta-chip--status {
  background: #DCFCE7;                           /* green-100 */
  border-color: #86EFAC;                         /* green-300 */
  color: #166534;                                /* green-800 */
  font-weight: 600;
}
.class-card__row {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  color: rgb(51 65 85);                          /* slate-700 */
  font-size: 12.5px;
  line-height: 1.4;
}
.class-card__row-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: rgb(100 116 139);                       /* slate-500 */
  flex-shrink: 0;
}
.class-card__wali-avatar {
  width: 24px;
  height: 24px;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  font-weight: 700;
  flex-shrink: 0;
}
.class-card__row-text {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}
.class-card__row-empty {
  font-size: 12.5px;
  font-style: italic;
  color: rgb(148 163 184);                       /* slate-400 */
}
.class-card__actions {
  margin-top: auto;
  padding-top: 8px;
  display: flex;
  gap: 12px;
  align-items: center;
  justify-content: flex-start;
}
.class-card__detail {
  font-size: 12.5px;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.class-card__detail:hover {
  text-decoration: underline;
}
.class-card__delete {
  font-size: 12px;
  font-weight: 500;
  color: rgb(239 68 68);                         /* status-danger */
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.class-card__delete:hover {
  text-decoration: underline;
}

/* ── Body column ─────────────────────────────────────────────── */
.class-card__body {
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-width: 0;
}
.class-card__capacity {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.class-card__capacity-head {
  display: flex;
  align-items: baseline;
  gap: 6px;
  flex-wrap: wrap;
}
.class-card__capacity-count {
  display: inline-flex;
  align-items: baseline;
  gap: 2px;
  color: rgb(15 23 42);                          /* slate-900 */
}
.class-card__capacity-current {
  font-size: 18px;
  font-weight: 700;
}
.class-card__capacity-slash {
  color: rgb(148 163 184);                       /* slate-400 */
  font-size: 15px;
}
.class-card__capacity-max {
  font-size: 15px;
  font-weight: 600;
  color: rgb(71 85 105);                         /* slate-600 */
}
.class-card__capacity-word {
  font-size: 12px;
  color: rgb(100 116 139);                       /* slate-500 */
  margin-left: 4px;
}
.class-card__capacity-pct {
  font-size: 12px;
  color: rgb(100 116 139);
  font-weight: 500;
}
.class-card__full-pill {
  display: inline-block;
  margin-left: 4px;
  padding: 1px 6px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
  color: #fff;
  letter-spacing: 0.04em;
}
.class-card__bar {
  height: 6px;
  border-radius: 999px;
  background: rgb(241 245 249);                  /* slate-100 */
  overflow: hidden;
}
.class-card__bar-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 300ms ease, background 300ms ease;
}

/* ── Roster avatars ──────────────────────────────────────────── */
.class-card__roster {
  display: flex;
  align-items: center;
  gap: -6px;
}
.class-card__student-avatar {
  width: 32px;
  height: 32px;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 11px;
  font-weight: 700;
  border: 2px solid #fff;
  margin-left: -6px;
  box-shadow: 0 0 0 1px rgb(226 232 240);
  flex-shrink: 0;
}
.class-card__student-avatar:first-child {
  margin-left: 0;
}
.class-card__student-avatar--overflow {
  background: rgb(241 245 249);                  /* slate-100 */
  color: rgb(71 85 105);                         /* slate-600 */
}

/* ── Subjects ────────────────────────────────────────────────── */
.class-card__subjects {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.class-card__subjects-label {
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: rgb(100 116 139);                       /* slate-500 */
}
.class-card__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
.class-card__chip {
  display: inline-flex;
  align-items: center;
  padding: 3px 8px;
  border-radius: 6px;
  background: rgb(248 250 252);                  /* slate-50 */
  border: 1px solid rgb(226 232 240);            /* slate-200 */
  font-size: 12px;
  color: rgb(30 41 59);                          /* slate-800 */
  line-height: 1.4;
}
.class-card__chip--more {
  background: transparent;
  color: rgb(100 116 139);                       /* slate-500 */
  font-style: italic;
  border-style: dashed;
}

/* ── Responsive: stack columns on narrow viewports ───────────── */
@media (max-width: 900px) {
  .class-card {
    grid-template-columns: 1fr;
    gap: 14px;
  }
  .class-card__identity {
    padding-right: 0;
    padding-bottom: 14px;
    border-right: none;
    border-bottom: 1px dashed rgb(203 213 225);
  }
  .class-card__actions {
    margin-top: 4px;
  }
}
</style>
