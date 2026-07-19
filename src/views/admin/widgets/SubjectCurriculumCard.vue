<!--
  SubjectCurriculumCard.vue — the curriculum-forward card that replaces
  the compact BrandListRow on the admin "Data Mapel" page. Wireframe:
  Entitas 4 · Opsi B (split card with left identity strip + right
  adaptive body).

  Two body states drive the tint:
    * LINKED   → violet body: "Kurikulum · Semester 1" + progress bar
                  + assessments / KKM summary
    * ORPHAN   → amber body: "Rekap belum aktif" + explanatory copy
                  + "Tautkan sekarang" CTA that opens the shared
                  LinkMasterPickerModal (parent handles the modal — the
                  card just emits `link-master`).

  Selection: long-press or a bulk-check toggle. When selected, the card
  gains a colored ring + a check overlay on the avatar (mirrors
  BrandListRow / TeacherStructuredCard so bulk-select feels consistent
  across the admin surface).
-->
<script setup lang="ts">
import { computed } from 'vue';
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

// `is_linked` may be undefined on legacy backends — derive it from
// master_subject_id in that case so the card still routes to the
// right state.
const isLinked = computed(() => {
  const flag = props.subject.is_linked;
  if (typeof flag === 'boolean') return flag;
  const mid = props.subject.master_subject_id;
  return mid != null && mid !== '';
});

const masterName = computed(
  () => props.subject.master_name ?? props.subject.master_subject_name ?? null,
);

const teachersPreview = computed(() => props.subject.teachers_preview ?? []);
const teachersCount = computed(
  () => props.subject.teachers_count ?? teachersPreview.value.length ?? 0,
);
const overflowTeachers = computed(() =>
  Math.max(0, teachersCount.value - teachersPreview.value.length),
);

const classesTaughtLabel = computed(() => {
  const list = props.subject.classes_taught ?? [];
  if (list.length === 0) return null;
  return list.map((c) => c.name).join(' · ');
});

// ── Curriculum aggregate (LINKED body only) ───────────────────────
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

// ── Long-press bulk-select (mirrors BrandListRow / TeacherStructuredCard)
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

// A card click either toggles selection (if we're already in bulk
// mode) or opens the drill-in. The "in bulk mode" branch is decided
// upstream via the `selected` prop + parent's `selectedIds.size`
// state, so here we simply forward: if the card is already selected
// or the parent said we're bulk-selecting, prefer `select`; otherwise
// `open`. Parent resolves ambiguity by rendering the card differently.
function onCardClick() {
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
    <!-- LEFT · Identity strip ────────────────────────────────── -->
    <div class="subject-card__identity">
      <div class="subject-card__header">
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
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="3"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="w-3.5 h-3.5"
            >
              <polyline points="20 6 9 17 4 12" />
            </svg>
          </span>
        </div>
        <span
          class="subject-card__code"
          :style="{
            color: primaryColor,
            borderColor: primaryColor,
          }"
        >{{ subject.code || '—' }}</span>
      </div>

      <h3 :id="nameHeadingId" class="subject-card__name">
        {{ subject.name || '—' }}
      </h3>

      <p
        class="subject-card__master"
        :class="isLinked ? 'subject-card__master--linked' : 'subject-card__master--orphan'"
      >
        <span class="subject-card__master-prefix">{{ t('admin.subjects.linked_master_prefix') }}</span>
        <template v-if="isLinked">
          <span class="subject-card__master-name">{{ masterName || '—' }}</span>
          <span class="subject-card__master-suffix">{{ t('admin.subjects.linked_master_suffix') }}</span>
        </template>
        <template v-else>
          <span class="subject-card__master-name">{{ t('admin.subjects.master_not_linked') }}</span>
        </template>
      </p>

      <div class="subject-card__teachers">
        <p class="subject-card__label">
          {{ t('admin.subjects.teachers_label') }} ({{ teachersCount }})
        </p>
        <div v-if="teachersPreview.length > 0" class="subject-card__teachers-row">
          <InitialsAvatar
            v-for="t in teachersPreview"
            :key="t.id"
            :name="t.name || t.avatar_initials || '?'"
            :size="24"
            :color="primaryColor"
            :border-radius="8"
          />
          <span
            v-if="overflowTeachers > 0"
            class="subject-card__overflow"
          >+{{ overflowTeachers }}</span>
        </div>
        <p v-else class="subject-card__empty">
          {{ t('admin.subjects.no_teachers') }}
        </p>
      </div>

      <div class="subject-card__classes">
        <p class="subject-card__label">
          {{ t('admin.subjects.classes_label') }}
        </p>
        <p v-if="classesTaughtLabel" class="subject-card__classes-value">
          {{ classesTaughtLabel }}
        </p>
        <p v-else class="subject-card__empty">
          {{ t('admin.subjects.no_classes') }}
        </p>
      </div>

      <div
        v-if="!readOnly && !selected"
        class="subject-card__row-actions"
      >
        <button
          type="button"
          class="subject-card__row-action"
          @click.stop="emit('edit')"
        >Edit</button>
        <button
          type="button"
          class="subject-card__row-action subject-card__row-action--danger"
          @click.stop="emit('delete')"
        >Hapus</button>
      </div>
    </div>

    <!-- RIGHT · Adaptive body ─────────────────────────────────── -->
    <div
      class="subject-card__body"
      :class="isLinked ? 'subject-card__body--linked' : 'subject-card__body--orphan'"
    >
      <template v-if="isLinked">
        <p class="subject-card__body-heading subject-card__body-heading--linked">
          {{ t('admin.subjects.curriculum_heading') }}
        </p>

        <template v-if="curriculum">
          <p class="subject-card__progress-line">
            {{ t('admin.subjects.chapters_progress', {
              done: curriculum.chapters_completed,
              total: curriculum.total_chapters,
              pct: chapterPct,
            }) }}
          </p>
          <div
            class="subject-card__progress-bar"
            role="progressbar"
            :aria-valuenow="chapterPct"
            aria-valuemin="0"
            aria-valuemax="100"
          >
            <div
              class="subject-card__progress-fill"
              :style="{
                width: `${chapterPct}%`,
                backgroundColor: primaryColor,
              }"
            />
          </div>
          <p class="subject-card__assessments">
            {{ t('admin.subjects.assessments_summary', {
              n: curriculum.assessment_count,
              pct: kkmPct,
              kkm: curriculum.kkm_value,
            }) }}
          </p>
        </template>

        <template v-else>
          <!--
            Linked but backend hasn't shipped the curriculum aggregate
            yet (older deploy). Show a muted placeholder instead of a
            zero-progress bar so we don't imply "0% dituntaskan".
          -->
          <p class="subject-card__body-placeholder">
            {{ t('admin.subjects.curriculum_heading') }}
          </p>
        </template>
      </template>

      <template v-else>
        <p class="subject-card__body-heading subject-card__body-heading--orphan">
          {{ t('admin.subjects.orphan_heading') }}
        </p>
        <p class="subject-card__body-copy">
          {{ t('admin.subjects.orphan_body') }}
        </p>
        <button
          type="button"
          class="subject-card__cta"
          @click.stop="emit('link-master')"
        >{{ t('admin.subjects.link_now') }} →</button>
      </template>
    </div>
  </article>
</template>

<style scoped>
/*
 * Root — split card with a fixed 260px identity strip on md+ that
 * stacks vertically on narrow viewports. Kept scoped so the bespoke
 * violet/amber tints don't leak beyond the "Data Mapel" surface.
 */
.subject-card {
  display: flex;
  flex-direction: column;
  border-radius: 12px;
  border: 1px solid rgb(226 232 240);            /* slate-200 */
  background: #fff;
  box-shadow:
    0 1px 2px 0 rgb(0 0 0 / 0.04),
    0 4px 16px -2px rgb(0 0 0 / 0.06);
  cursor: pointer;
  overflow: hidden;
  transition: box-shadow 150ms ease, border-color 150ms ease;
  --subject-card-accent: #4F46E5;
}
.subject-card:hover {
  box-shadow:
    0 2px 4px 0 rgb(0 0 0 / 0.06),
    0 8px 24px -4px rgb(0 0 0 / 0.08);
}
.subject-card--selected {
  border-color: var(--subject-card-accent);
  box-shadow:
    0 0 0 2px var(--subject-card-accent),
    0 4px 16px -2px rgb(0 0 0 / 0.06);
}

@media (min-width: 640px) {
  .subject-card {
    flex-direction: row;
  }
}

/* ── LEFT identity strip ─────────────────────────────────────── */
.subject-card__identity {
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 10px;
  min-width: 0;
}
@media (min-width: 640px) {
  .subject-card__identity {
    width: 260px;
    flex-shrink: 0;
    border-right: 1px dashed rgb(226 232 240);   /* slate-200 */
  }
}

.subject-card__header {
  display: flex;
  align-items: center;
  gap: 10px;
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
.subject-card__code {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 999px;
  border: 1px solid currentColor;
  background: color-mix(in srgb, currentColor 10%, transparent);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

.subject-card__name {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  word-break: break-word;
}

.subject-card__master {
  margin: 0;
  font-size: 12px;
  line-height: 1.4;
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px;
}
.subject-card__master-prefix {
  color: rgb(100 116 139);                       /* slate-500 */
  font-weight: 600;
}
.subject-card__master-name {
  font-weight: 700;
}
.subject-card__master--linked .subject-card__master-name,
.subject-card__master--linked .subject-card__master-suffix {
  color: rgb(109 40 217);                        /* violet-700 */
}
.subject-card__master--orphan .subject-card__master-name {
  color: rgb(180 83 9);                          /* amber-700 */
}
.subject-card__master-suffix {
  font-weight: 600;
}

.subject-card__label {
  margin: 0 0 4px 0;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: rgb(100 116 139);                       /* slate-500 */
}
.subject-card__teachers-row {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-wrap: wrap;
}
.subject-card__overflow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 24px;
  padding: 0 6px;
  border-radius: 8px;
  background: rgb(241 245 249);                  /* slate-100 */
  color: rgb(71 85 105);                         /* slate-600 */
  font-size: 11px;
  font-weight: 700;
}
.subject-card__classes-value {
  margin: 0;
  font-size: 12.5px;
  color: rgb(30 41 59);                          /* slate-800 */
  line-height: 1.4;
  word-break: break-word;
}
.subject-card__empty {
  margin: 0;
  font-size: 12px;
  font-style: italic;
  color: rgb(148 163 184);                       /* slate-400 */
}

.subject-card__row-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  padding-top: 4px;
  margin-top: auto;
  font-size: 12px;
}
.subject-card__row-action {
  background: transparent;
  border: none;
  padding: 0;
  cursor: pointer;
  color: rgb(100 116 139);                       /* slate-500 */
  font-weight: 500;
}
.subject-card__row-action:hover {
  color: var(--subject-card-accent);
  text-decoration: underline;
}
.subject-card__row-action--danger {
  color: rgb(239 68 68);                         /* status-danger */
}
.subject-card__row-action--danger:hover {
  color: rgb(220 38 38);                         /* red-600 */
}

/* ── RIGHT adaptive body ─────────────────────────────────────── */
.subject-card__body {
  flex: 1 1 auto;
  min-width: 0;
  padding: 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.subject-card__body--linked {
  background: rgb(245 243 255);                  /* violet-50 */
  border-top: 1px solid rgb(221 214 254);        /* violet-200 */
}
@media (min-width: 640px) {
  .subject-card__body--linked {
    border-top: none;
    border-left: 3px solid rgb(139 92 246);      /* violet-500 */
  }
}
:global(.tutoring-dark) .subject-card__body--linked {
  background: rgb(46 16 101 / 0.4);              /* violet-950/40 */
  border-color: rgb(76 29 149);                  /* violet-900 */
}

.subject-card__body--orphan {
  background: rgb(255 251 235);                  /* amber-50 */
  border-top: 1px solid rgb(253 230 138);        /* amber-200 */
}
@media (min-width: 640px) {
  .subject-card__body--orphan {
    border-top: none;
    border-left: 3px solid rgb(245 158 11);      /* amber-500 */
  }
}
:global(.tutoring-dark) .subject-card__body--orphan {
  background: rgb(69 26 3 / 0.4);                /* amber-950/40 */
  border-color: rgb(120 53 15);                  /* amber-900 */
}

.subject-card__body-heading {
  margin: 0;
  font-size: 10px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}
.subject-card__body-heading--linked {
  color: rgb(109 40 217);                        /* violet-700 */
}
.subject-card__body-heading--orphan {
  color: rgb(180 83 9);                          /* amber-700 */
}

.subject-card__progress-line {
  margin: 4px 0 0 0;
  font-size: 13px;
  font-weight: 700;
  color: rgb(30 41 59);                          /* slate-800 */
  line-height: 1.35;
}
.subject-card__progress-bar {
  width: 100%;
  height: 6px;
  border-radius: 999px;
  background: rgb(237 233 254);                  /* violet-100 */
  overflow: hidden;
}
.subject-card__progress-fill {
  height: 100%;
  border-radius: 999px;
  background: rgb(139 92 246);                   /* violet-500 fallback */
  transition: width 200ms ease;
}
.subject-card__assessments {
  margin: 4px 0 0 0;
  font-size: 12px;
  color: rgb(71 85 105);                         /* slate-600 */
  line-height: 1.4;
}

.subject-card__body-placeholder {
  margin: 0;
  font-size: 12px;
  color: rgb(148 163 184);                       /* slate-400 */
  font-style: italic;
}

.subject-card__body-copy {
  margin: 2px 0 4px 0;
  font-size: 12.5px;
  color: rgb(146 64 14);                         /* amber-800 */
  line-height: 1.5;
}
.subject-card__cta {
  align-self: flex-start;
  display: inline-flex;
  align-items: center;
  padding: 6px 12px;
  border-radius: 8px;
  background: rgb(217 119 6);                    /* amber-600 */
  color: white;
  font-size: 12.5px;
  font-weight: 700;
  border: none;
  cursor: pointer;
  transition: background 120ms ease;
}
.subject-card__cta:hover {
  background: rgb(180 83 9);                     /* amber-700 */
}
.subject-card__cta:focus-visible {
  outline: 2px solid rgb(217 119 6);
  outline-offset: 2px;
}
</style>
