<!--
  SubjectCurriculumCard.vue — admin "Data Mapel" list card.

  Redesigned 2026-07-20 (Yahya feedback: "kartu mapel terlalu berwarna,
  kiri-kanan seperti kartu terpisah"). The prior split card (violet
  body when linked · amber body when orphan) with the "REKAP BELUM
  AKTIF" panel on the right made the warning read as a separate card
  next to the subject itself.

  Now: one unified card, warning becomes an inline pill next to the
  name, CTA only when relevant.

    ┌─────────────────────────────────────────────────────────┐
    │ [AQ]  Al Qur'an Hadis   D-9                    [⋮]     │
    │       ▲ Belum tertaut ke master                         │
    │                                                          │
    │  Pengampu 1 guru       Diajarkan di 0 kelas             │
    │                                                          │
    │  [Tautkan ke master]                             Edit ✎  │
    └─────────────────────────────────────────────────────────┘

  Linked state drops the warning pill + CTA:

    ┌─────────────────────────────────────────────────────────┐
    │ [BA]  Bahasa Arab       D-8                    [⋮]     │
    │       ✓ Tertaut · Rekap Nilai aktif                     │
    │                                                          │
    │  Pengampu 3 guru       Diajarkan di 4 kelas             │
    │  ▓▓▓▓▓▓░░░ 12/20 bab · KKM 78%                          │
    │                                                                │
    │                                                  Edit ✎  │
    └─────────────────────────────────────────────────────────┘

  Design locks:
    * Warning tint stays a single amber pill (~180px), not a full
      panel that owns half the card.
    * CTA "Tautkan" ONLY shows for orphan state; linked state cleans
      up to just the two mini-stats + optional curriculum progress.
    * Actions collapse into kebab (Hapus) + inline Edit link; CTA
      button when needed sits at the same footer level so tap targets
      align.
    * Same props / emits as pre-redesign so caller doesn't change.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import type { Subject } from '@/types/entities';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';

const props = withDefaults(
  defineProps<{
    subject: Subject;
    primaryColor?: string;
    selected?: boolean;
    /** True on read-only academic years — hides Edit/Hapus buttons. */
    readOnly?: boolean;
  }>(),
  {
    primaryColor: '#4F46E5',
    selected: false,
    readOnly: false,
  },
);

const emit = defineEmits<{
  select: [];
  open: [];
  edit: [];
  delete: [];
  'link-master': [];
}>();

const { t } = useI18n();

// ── Derived values ────────────────────────────────────────────────

const isLinked = computed(() => {
  const flag = props.subject.is_linked;
  if (typeof flag === 'boolean') return flag;
  const mid = props.subject.master_subject_id;
  return mid != null && mid !== '';
});

const masterName = computed(
  () => props.subject.master_name ?? props.subject.master_subject_name ?? null,
);

const teachersCount = computed(
  () => props.subject.teachers_count ?? props.subject.teachers_preview?.length ?? 0,
);

const classesCount = computed(() => (props.subject.classes_taught ?? []).length);

// ── Curriculum aggregate (linked state only) ─────────────────────
const curriculum = computed(() => props.subject.curriculum ?? null);
const chapterPct = computed(() => {
  const c = curriculum.value;
  if (!c || !c.total_chapters || c.total_chapters <= 0) return 0;
  const raw = (c.chapters_completed / c.total_chapters) * 100;
  return Math.max(0, Math.min(100, Math.round(raw)));
});
const kkmPct = computed(() => {
  const c = curriculum.value;
  if (!c) return 0;
  return Math.max(0, Math.min(100, Math.round(c.kkm_achievement_rate * 100)));
});

const nameHeadingId = computed(() => `subject-card-name-${props.subject.id}`);

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

// ── Long-press bulk-select (retained) ───────────────────────────
let longPressTimer: ReturnType<typeof setTimeout> | null = null;
function onPointerDown() {
  if (longPressTimer) clearTimeout(longPressTimer);
  longPressTimer = setTimeout(() => {
    longPressTimer = null;
    emit('select');
  }, 500);
}
function onPointerUp() {
  if (longPressTimer) {
    clearTimeout(longPressTimer);
    longPressTimer = null;
  }
}

function onCardClick(e: MouseEvent) {
  // Skip if the click came from inside the menu (already stopPropagation'd
  // but this guards a stray keyboard toggle path).
  if ((e.target as HTMLElement)?.closest?.('.subject-card__menu-wrap')) return;
  closeMenu();
  if (props.selected) {
    emit('select');
  } else {
    emit('open');
  }
}
</script>

<template>
  <article
    class="subject-card"
    :class="[
      isLinked ? 'subject-card--linked' : 'subject-card--orphan',
      { 'subject-card--selected': selected },
    ]"
    :style="{ '--subject-card-accent': primaryColor }"
    :aria-labelledby="nameHeadingId"
    @click="onCardClick"
    @pointerdown="onPointerDown"
    @pointerup="onPointerUp"
    @pointerleave="onPointerUp"
  >
    <!-- Header: avatar · name+code+status · kebab -->
    <div class="subject-card__head">
      <div class="subject-card__avatar-wrap">
        <InitialsAvatar
          :name="subject.name || '?'"
          :size="40"
          :color="primaryColor"
          :border-radius="10"
        />
        <span
          v-if="selected"
          class="subject-card__check"
          :style="{ color: primaryColor }"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" width="12" height="12">
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </span>
      </div>

      <div class="subject-card__title">
        <div class="subject-card__title-row">
          <h3 :id="nameHeadingId" class="subject-card__name">
            {{ subject.name || '—' }}
          </h3>
          <span
            v-if="subject.code"
            class="subject-card__code"
          >{{ subject.code }}</span>
        </div>

        <div class="subject-card__status">
          <template v-if="isLinked">
            <svg class="subject-card__status-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" width="12" height="12">
              <polyline points="20 6 9 17 4 12" />
            </svg>
            <span class="subject-card__status-text subject-card__status-text--ok">
              {{ masterName ? `Tertaut · ${masterName}` : 'Tertaut ke master · Rekap Nilai aktif' }}
            </span>
          </template>
          <template v-else>
            <span class="subject-card__status-pill">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" width="11" height="11">
                <path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                <line x1="12" y1="9" x2="12" y2="13" />
                <line x1="12" y1="17" x2="12.01" y2="17" />
              </svg>
              {{ t('admin.subjects.master_not_linked') }}
            </span>
          </template>
        </div>
      </div>

      <div v-if="!readOnly" class="subject-card__menu-wrap" @click.stop>
        <button
          type="button"
          class="subject-card__menu-trigger"
          aria-label="Menu"
          :aria-expanded="menuOpen"
          @click="toggleMenu"
        >
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="16" height="16">
            <circle cx="12" cy="5" r="1" />
            <circle cx="12" cy="12" r="1" />
            <circle cx="12" cy="19" r="1" />
          </svg>
        </button>
        <div v-if="menuOpen" class="subject-card__menu" role="menu">
          <button type="button" role="menuitem" class="subject-card__menu-item subject-card__menu-item--danger" @click="onDelete">
            Hapus mata pelajaran
          </button>
        </div>
      </div>
    </div>

    <!-- Stats row -->
    <div class="subject-card__stats">
      <div class="subject-card__stat">
        <p class="subject-card__stat-label">Pengampu</p>
        <p class="subject-card__stat-value">
          {{ teachersCount }}<span class="subject-card__stat-unit"> guru</span>
        </p>
      </div>
      <div class="subject-card__stat">
        <p class="subject-card__stat-label">Diajarkan di</p>
        <p class="subject-card__stat-value">
          {{ classesCount }}<span class="subject-card__stat-unit"> kelas</span>
        </p>
      </div>
    </div>

    <!-- Curriculum progress (linked + curriculum aggregate present) -->
    <div v-if="isLinked && curriculum" class="subject-card__curriculum">
      <div class="subject-card__curriculum-head">
        <span class="subject-card__curriculum-label">
          Bab tuntas
        </span>
        <span class="subject-card__curriculum-count">
          {{ curriculum.chapters_completed }}<span class="subject-card__curriculum-slash"> / {{ curriculum.total_chapters }}</span>
          <span class="subject-card__curriculum-kkm"> · KKM {{ kkmPct }}%</span>
        </span>
      </div>
      <div class="subject-card__bar">
        <div
          class="subject-card__bar-fill"
          :style="{ width: `${chapterPct}%`, background: primaryColor }"
        />
      </div>
    </div>

    <!-- Footer: primary CTA (orphan only) + edit -->
    <div v-if="!readOnly && !selected" class="subject-card__foot">
      <button
        v-if="!isLinked"
        type="button"
        class="subject-card__cta"
        :style="{ background: primaryColor }"
        @click.stop="emit('link-master')"
      >
        Tautkan ke master →
      </button>
      <span v-else class="subject-card__foot-spacer" aria-hidden="true"></span>
      <button
        type="button"
        class="subject-card__edit"
        :style="{ color: primaryColor }"
        @click.stop="emit('edit')"
      >
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" width="12" height="12">
          <path d="M12 20h9" />
          <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z" />
        </svg>
        Edit
      </button>
    </div>
  </article>
</template>

<style scoped>
/*
 * Root — single flat card, no dashed vertical divider, no full-height
 * body panel. Warning tint contained to a small inline pill (see
 * .subject-card__status-pill). Scoped so the amber pill palette
 * doesn't leak beyond the Data Mapel surface.
 */
.subject-card {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
  background: #fff;
  border-radius: 12px;
  border: 1px solid rgb(226 232 240);            /* slate-200 */
  cursor: pointer;
  transition: border-color 150ms ease, box-shadow 150ms ease;
  --subject-card-accent: #4F46E5;
}
.subject-card:hover {
  border-color: rgb(203 213 225);                /* slate-300 */
  box-shadow: 0 4px 12px -4px rgb(0 0 0 / 0.08);
}
.subject-card--selected {
  border-color: var(--subject-card-accent);
  box-shadow: 0 0 0 2px var(--subject-card-accent);
}

/* ── Header ─────────────────────────────────────────────────── */
.subject-card__head {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  min-width: 0;
}
.subject-card__avatar-wrap {
  position: relative;
  flex-shrink: 0;
}
.subject-card__check {
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
.subject-card__title {
  flex: 1;
  min-width: 0;
}
.subject-card__title-row {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.subject-card__name {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.3;
  word-break: break-word;
}
.subject-card__code {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 6px;
  background: rgb(241 245 249);                  /* slate-100 */
  color: rgb(71 85 105);                         /* slate-600 */
  font-size: 11px;
  font-weight: 500;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  letter-spacing: 0.02em;
}

/* ── Status pill + text ─────────────────────────────────────── */
.subject-card__status {
  margin-top: 4px;
  display: flex;
  align-items: center;
  gap: 4px;
  min-width: 0;
}
.subject-card__status-icon {
  color: #047857;                                /* emerald-700 */
  flex-shrink: 0;
}
.subject-card__status-text {
  font-size: 12px;
  line-height: 1.4;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}
.subject-card__status-text--ok {
  color: #047857;                                /* emerald-700 */
}
.subject-card__status-pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 999px;
  background: #FEF3C7;                           /* amber-100 */
  color: #B45309;                                /* amber-700 */
  font-size: 11px;
  font-weight: 500;
  line-height: 1.3;
  max-width: 100%;
}

/* ── Kebab ──────────────────────────────────────────────────── */
.subject-card__menu-wrap {
  position: relative;
  flex-shrink: 0;
}
.subject-card__menu-trigger {
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
.subject-card__menu-trigger:hover {
  background: rgb(241 245 249);
  color: rgb(71 85 105);
}
.subject-card__menu {
  position: absolute;
  top: calc(100% + 4px);
  right: 0;
  min-width: 200px;
  background: #fff;
  border: 1px solid rgb(226 232 240);
  border-radius: 8px;
  box-shadow: 0 8px 24px -6px rgb(0 0 0 / 0.12);
  padding: 4px;
  z-index: 10;
}
.subject-card__menu-item {
  display: block;
  width: 100%;
  text-align: left;
  padding: 8px 10px;
  background: transparent;
  border: none;
  font-size: 13px;
  color: rgb(30 41 59);
  cursor: pointer;
  border-radius: 6px;
}
.subject-card__menu-item:hover {
  background: rgb(248 250 252);
}
.subject-card__menu-item--danger {
  color: #B91C1C;                                /* red-700 */
}
.subject-card__menu-item--danger:hover {
  background: #FEF2F2;
}

/* ── Stats ──────────────────────────────────────────────────── */
.subject-card__stats {
  display: flex;
  gap: 24px;
  padding: 10px 12px;
  background: rgb(248 250 252);                  /* slate-50 */
  border-radius: 8px;
}
.subject-card__stat-label {
  margin: 0;
  font-size: 11px;
  color: rgb(100 116 139);                       /* slate-500 */
  line-height: 1.3;
}
.subject-card__stat-value {
  margin: 2px 0 0;
  font-size: 15px;
  font-weight: 600;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.2;
}
.subject-card__stat-unit {
  font-size: 12px;
  font-weight: 400;
  color: rgb(100 116 139);
}

/* ── Curriculum ─────────────────────────────────────────────── */
.subject-card__curriculum {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.subject-card__curriculum-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}
.subject-card__curriculum-label {
  font-size: 12px;
  color: rgb(100 116 139);                       /* slate-500 */
}
.subject-card__curriculum-count {
  font-size: 12px;
  color: rgb(15 23 42);                          /* slate-900 */
  font-weight: 500;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.subject-card__curriculum-slash {
  color: rgb(148 163 184);                       /* slate-400 */
  font-weight: 400;
}
.subject-card__curriculum-kkm {
  color: rgb(100 116 139);
  font-weight: 400;
}
.subject-card__bar {
  height: 4px;
  border-radius: 999px;
  background: rgb(226 232 240);                  /* slate-200 */
  overflow: hidden;
}
.subject-card__bar-fill {
  height: 100%;
  border-radius: 999px;
  transition: width 250ms ease;
}

/* ── Footer ─────────────────────────────────────────────────── */
.subject-card__foot {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding-top: 4px;
  border-top: 1px solid rgb(241 245 249);        /* slate-100 */
}
.subject-card__foot-spacer {
  flex: 1;
}
.subject-card__cta {
  display: inline-flex;
  align-items: center;
  padding: 6px 12px;
  border-radius: 8px;
  color: #fff;
  font-size: 12.5px;
  font-weight: 500;
  border: none;
  cursor: pointer;
  transition: filter 120ms ease;
}
.subject-card__cta:hover {
  filter: brightness(0.92);
}
.subject-card__edit {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  border-radius: 6px;
  background: transparent;
  border: none;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
}
.subject-card__edit:hover {
  background: rgb(248 250 252);                  /* slate-50 */
}
</style>
