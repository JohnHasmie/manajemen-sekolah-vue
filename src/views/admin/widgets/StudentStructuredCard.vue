<!--
  StudentStructuredCard.vue — the two-column structured card that
  replaces the compact BrandListRow variant on the admin "Data Siswa"
  page. Sibling to TeacherStructuredCard so the two admin lists read
  as one system.

  Layout (>= md):
    ┌─────────────────────────┬───────────────────────────────────┬─────────┐
    │ [avatar]  Nama          │ WALI/ORTU        KONTAK WALI       │ Detail →│
    │           NIS · Gender  │ Bpk. Ahmad       0812-…           │         │
    │           [kelas] [Aktif]│                                    │  Hapus  │
    │                         │ TAHUN AJARAN     ALAMAT           │         │
    │                         │ 2025/2026 · S1   Kartasura, Sukoharjo │      │
    └─────────────────────────┴───────────────────────────────────┴─────────┘

  Below 800px the three columns stack and the action column collapses
  into a right-aligned inline row.

  Selection: long-press or bulk-check the card to toggle selection.
  When selected, a check overlay lands on the avatar and the whole
  card gains an accent ring, mirroring BrandListRow.

  Every new-field access carries a defensive fallback because the
  backend MR that emits them ships separately from this frontend MR.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { Student } from '@/types/entities';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';

const props = withDefaults(
  defineProps<{
    student: Student;
    accentColor?: string;
    selected?: boolean;
    /** When true, the card behaves as a long-press bulk-select target. */
    bulkSelectable?: boolean;
  }>(),
  {
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

// ── Derived values (defensive fallbacks per CLAUDE.md rule) ───────

const genderLabel = computed(() => {
  const g = (props.student.gender ?? '').toLowerCase();
  if (g === 'l' || g === 'male' || g === 'laki-laki' || g === 'laki') {
    return 'L';
  }
  if (g === 'p' || g === 'female' || g === 'perempuan') return 'P';
  return null;
});

const nisLine = computed(() => {
  const nis = props.student.student_number?.trim();
  const parts: string[] = [];
  if (nis) parts.push(nis);
  if (genderLabel.value) parts.push(genderLabel.value);
  return parts.length > 0 ? parts.join(' · ') : 'NIS belum diisi';
});

const classChip = computed<string | null>(() => {
  const fromRef = props.student.class_ref?.name?.trim();
  if (fromRef) return fromRef;
  const flat = props.student.class_name?.trim();
  return flat ? flat : null;
});

/**
 * Coarse status enum → pill descriptor. Missing status is treated as
 * `active` because the pre-deploy list response often omits it and
 * the row would otherwise look "off" for the majority of students.
 */
const statusPill = computed<{
  label: string;
  variant: 'active' | 'inactive' | 'unverified';
}>(() => {
  switch (props.student.status) {
    case 'inactive':
      return { label: 'Nonaktif', variant: 'inactive' };
    case 'unverified':
      return { label: 'Belum verifikasi', variant: 'unverified' };
    case 'active':
    default:
      return { label: 'Aktif', variant: 'active' };
  }
});

const guardianName = computed<string | null>(() => {
  const structured = props.student.wali_contact?.name?.trim();
  if (structured) return structured;
  const flat = props.student.guardian_name?.trim();
  return flat ? flat : null;
});

const guardianPhone = computed<string | null>(() => {
  const structured = props.student.wali_contact?.phone?.trim();
  if (structured) return structured;
  const flat = props.student.phone_number?.trim();
  return flat ? flat : null;
});

const academicYearDisplay = computed<string | null>(() => {
  const ay = props.student.academic_year;
  if (!ay) return null;
  const name = ay.name?.trim();
  if (!name) return null;
  const sem = ay.semester?.trim();
  return sem ? `${name} · ${sem}` : name;
});

const addressDisplay = computed<string | null>(() => {
  const short = props.student.address_short?.trim();
  if (short) return short;
  const full = props.student.address?.trim();
  return full ? full : null;
});

// ── Long-press bulk-select (mirrors BrandListRow / TeacherStructuredCard)
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
    class="student-card"
    :class="{ 'student-card--selected': selected }"
    :style="selected ? { '--student-card-accent': accentColor } : {}"
    @click="emit('click', $event)"
    @pointerdown="onPointerDown"
    @pointerup="onPointerUp"
    @pointerleave="onPointerUp"
  >
    <!-- LEFT · Identity ----------------------------------------- -->
    <div class="student-card__identity">
      <div class="student-card__avatar-wrap">
        <InitialsAvatar
          :name="student.name || '?'"
          :size="44"
          :color="accentColor"
          :border-radius="12"
        />
        <span
          v-if="selected"
          class="student-card__check"
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
            class="w-3.5 h-3.5"
          >
            <polyline points="20 6 9 17 4 12" />
          </svg>
        </span>
      </div>
      <div class="student-card__identity-text">
        <p class="student-card__name">
          {{ student.name || '—' }}
        </p>
        <p class="student-card__nis">
          {{ nisLine }}
        </p>
        <div class="student-card__chips-row">
          <span
            v-if="classChip"
            class="student-card__chip student-card__chip--class"
          >{{ classChip }}</span>
          <span
            class="student-card__chip"
            :class="{
              'student-card__chip--active': statusPill.variant === 'active',
              'student-card__chip--inactive': statusPill.variant === 'inactive',
              'student-card__chip--unverified':
                statusPill.variant === 'unverified',
            }"
          >{{ statusPill.label }}</span>
        </div>
      </div>
    </div>

    <!-- RIGHT · Info 2×2 grid ----------------------------------- -->
    <div class="student-card__info">
      <div class="student-card__field">
        <p class="student-card__label">Wali/Ortu</p>
        <p v-if="guardianName" class="student-card__value">
          {{ guardianName }}
        </p>
        <span v-else class="student-card__empty">Belum diisi</span>
      </div>

      <div class="student-card__field">
        <p class="student-card__label">Kontak Wali</p>
        <p
          v-if="guardianPhone"
          class="student-card__value student-card__value--mono"
        >
          {{ guardianPhone }}
        </p>
        <span v-else class="student-card__empty">—</span>
      </div>

      <div class="student-card__field">
        <p class="student-card__label">Tahun Ajaran</p>
        <p v-if="academicYearDisplay" class="student-card__value">
          {{ academicYearDisplay }}
        </p>
        <span v-else class="student-card__empty">—</span>
      </div>

      <div class="student-card__field">
        <p class="student-card__label">Alamat</p>
        <p v-if="addressDisplay" class="student-card__value" :title="addressDisplay">
          {{ addressDisplay }}
        </p>
        <span v-else class="student-card__empty">—</span>
      </div>
    </div>

    <!-- Actions column ----------------------------------------- -->
    <div class="student-card__actions">
      <button
        type="button"
        class="student-card__detail"
        :style="{ color: accentColor }"
        @click.stop="emit('detail')"
      >Detail →</button>
      <button
        type="button"
        class="student-card__delete"
        @click.stop="emit('delete')"
      >Hapus</button>
    </div>
  </div>
</template>

<style scoped>
/*
 * Container — mirrors TeacherStructuredCard so the two admin surfaces
 * feel like one visual system. Scoped so the bespoke chip styles
 * don't leak into siblings.
 */
.student-card {
  display: grid;
  grid-template-columns: 320px 1fr auto;
  gap: 16px;
  padding: 16px;
  background: #fff;
  border-radius: 16px;
  border: 1px solid rgb(226 232 240);           /* slate-200 */
  box-shadow:
    0 1px 2px 0 rgb(0 0 0 / 0.04),
    0 4px 16px -2px rgb(0 0 0 / 0.06);
  cursor: pointer;
  transition: box-shadow 150ms ease, border-color 150ms ease;
  --student-card-accent: #1B6FB8;
}
.student-card:hover {
  box-shadow:
    0 2px 4px 0 rgb(0 0 0 / 0.06),
    0 8px 24px -4px rgb(0 0 0 / 0.08);
}
.student-card--selected {
  border-color: var(--student-card-accent);
  box-shadow:
    0 0 0 2px var(--student-card-accent),
    0 4px 16px -2px rgb(0 0 0 / 0.06);
}

/* ── Identity column ─────────────────────────────────────────── */
.student-card__identity {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  padding-right: 16px;
  border-right: 1px dashed rgb(203 213 225);    /* slate-300 */
}
.student-card__avatar-wrap {
  position: relative;
  flex-shrink: 0;
}
.student-card__check {
  position: absolute;
  top: -4px;
  right: -4px;
  width: 20px;
  height: 20px;
  border-radius: 999px;
  background: #fff;
  display: grid;
  place-items: center;
  box-shadow: 0 0 0 2px currentColor;
}
.student-card__identity-text {
  min-width: 0;
  flex: 1;
}
.student-card__name {
  font-size: 15px;
  font-weight: 700;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.student-card__nis {
  margin-top: 2px;
  font-size: 11px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: rgb(100 116 139);                       /* slate-500 */
}
.student-card__chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 8px;
}

/* ── Info 2×2 grid ───────────────────────────────────────────── */
.student-card__info {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px 20px;
  min-width: 0;
}
.student-card__field {
  min-width: 0;
}
.student-card__label {
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: rgb(100 116 139);                       /* slate-500 */
  margin-bottom: 4px;
}
.student-card__value {
  font-size: 12.5px;
  color: rgb(30 41 59);                          /* slate-800 */
  line-height: 1.4;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.student-card__value--mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 12px;
}
.student-card__empty {
  font-size: 12px;
  font-style: italic;
  color: rgb(148 163 184);                       /* slate-400 */
}

/* ── Chips (identity row) ────────────────────────────────────── */
.student-card__chip {
  display: inline-flex;
  align-items: center;
  padding: 3px 8px;
  border-radius: 6px;
  background: rgb(248 250 252);                  /* slate-50 */
  border: 1px solid rgb(226 232 240);            /* slate-200 */
  font-size: 11px;
  color: rgb(30 41 59);                          /* slate-800 */
  line-height: 1.4;
  font-weight: 600;
}
.student-card__chip--class {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11.5px;
}
.student-card__chip--active {
  background: #ECFDF5;                           /* green-50 */
  border-color: #A7F3D0;                         /* green-200 */
  color: #047857;                                /* green-700 */
}
.student-card__chip--inactive {
  background: #F1F5F9;                           /* slate-100 */
  border-color: #CBD5E1;                         /* slate-300 */
  color: #475569;                                /* slate-600 */
}
.student-card__chip--unverified {
  background: #FEF3C7;                           /* amber-100 */
  border-color: #FCD34D;                         /* amber-300 */
  color: #92400E;                                /* amber-800 */
}

/* ── Actions column ──────────────────────────────────────────── */
.student-card__actions {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: flex-end;
  gap: 12px;
  padding-left: 12px;
  min-width: 72px;
}
.student-card__detail {
  font-size: 12.5px;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.student-card__detail:hover {
  text-decoration: underline;
}
.student-card__delete {
  font-size: 12px;
  font-weight: 500;
  color: rgb(239 68 68);                         /* status-danger */
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.student-card__delete:hover {
  text-decoration: underline;
}

/* ── Responsive: stack columns on narrow screens ─────────────── */
@media (max-width: 800px) {
  .student-card {
    grid-template-columns: 1fr;
    gap: 12px;
  }
  .student-card__identity {
    border-right: none;
    border-bottom: 1px dashed rgb(203 213 225);
    padding-right: 0;
    padding-bottom: 12px;
  }
  .student-card__info {
    grid-template-columns: 1fr 1fr;
    gap: 10px 16px;
  }
  .student-card__actions {
    flex-direction: row;
    align-items: center;
    justify-content: flex-end;
    padding-left: 0;
    padding-top: 8px;
    border-top: 1px dashed rgb(203 213 225);
    gap: 20px;
  }
}

@media (max-width: 480px) {
  .student-card__info {
    grid-template-columns: 1fr;
  }
}
</style>
