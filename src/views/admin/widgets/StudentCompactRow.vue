<!--
  StudentCompactRow.vue — Opsi B dense single-row layout for the
  admin Data Siswa page. Used when the admin flips the header toggle
  to "Padat" (compact). Trades the structured 2×2 grid for a single
  scannable row so an admin can eyeball a full page (~10-15 rows)
  without scrolling.

  Layout:
    [S] Nama Siswa · NIS   [7A]  Wali: Bpk. Ahmad · 0812-…   [Detail]

  Every backend-new field carries a defensive fallback because the
  enriched response ships in a separate backend MR.
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

// ── Derived values ────────────────────────────────────────────────

const nisDisplay = computed(() => props.student.student_number?.trim() || '—');

const classChipLabel = computed<string | null>(() => {
  const fromRef = props.student.class_ref?.name?.trim();
  if (fromRef) return fromRef;
  const flat = props.student.class_name?.trim();
  return flat ? flat : null;
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

const guardianSummary = computed<string | null>(() => {
  const parts: string[] = [];
  if (guardianName.value) parts.push(guardianName.value);
  if (guardianPhone.value) parts.push(guardianPhone.value);
  return parts.length > 0 ? parts.join(' · ') : null;
});

const statusVariant = computed<'active' | 'inactive' | 'unverified'>(() => {
  if (props.student.status === 'inactive') return 'inactive';
  if (props.student.status === 'unverified') return 'unverified';
  return 'active';
});

// ── Long-press bulk-select ────────────────────────────────────────
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
    class="student-row"
    :class="{
      'student-row--selected': selected,
      'student-row--inactive': statusVariant === 'inactive',
      'student-row--unverified': statusVariant === 'unverified',
    }"
    :style="selected ? { '--student-row-accent': accentColor } : {}"
    @click="emit('click', $event)"
    @pointerdown="onPointerDown"
    @pointerup="onPointerUp"
    @pointerleave="onPointerUp"
  >
    <!-- Avatar -->
    <div class="student-row__avatar-wrap">
      <InitialsAvatar
        :name="student.name || '?'"
        :size="32"
        :color="accentColor"
        :border-radius="8"
      />
      <span
        v-if="selected"
        class="student-row__check"
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
    </div>

    <!-- Name + NIS -->
    <div class="student-row__identity">
      <p class="student-row__name">
        {{ student.name || '—' }}
        <span class="student-row__nis">· {{ nisDisplay }}</span>
      </p>
    </div>

    <!-- Class chip -->
    <span
      v-if="classChipLabel"
      class="student-row__chip"
    >{{ classChipLabel }}</span>
    <span v-else class="student-row__chip student-row__chip--empty">—</span>

    <!-- Wali summary -->
    <p class="student-row__wali" :title="guardianSummary ?? ''">
      <span class="student-row__wali-label">Wali:</span>
      <span v-if="guardianSummary">{{ guardianSummary }}</span>
      <span v-else class="student-row__empty">Belum diisi</span>
    </p>

    <!-- Status dot (compact indicator only — full label lives in the
         card view). Hidden below sm so the row stays scannable. -->
    <span
      class="student-row__status-dot"
      :class="{
        'student-row__status-dot--active': statusVariant === 'active',
        'student-row__status-dot--inactive': statusVariant === 'inactive',
        'student-row__status-dot--unverified': statusVariant === 'unverified',
      }"
      :title="statusVariant === 'active'
        ? 'Aktif'
        : statusVariant === 'inactive'
          ? 'Nonaktif'
          : 'Belum verifikasi'"
    />

    <!-- Actions -->
    <div class="student-row__actions">
      <button
        type="button"
        class="student-row__detail"
        :style="{ color: accentColor }"
        @click.stop="emit('detail')"
      >Detail</button>
      <button
        type="button"
        class="student-row__delete"
        aria-label="Hapus"
        @click.stop="emit('delete')"
      >Hapus</button>
    </div>
  </div>
</template>

<style scoped>
.student-row {
  display: grid;
  grid-template-columns: auto minmax(0, 1.4fr) auto minmax(0, 1.8fr) auto auto;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  background: #fff;
  border-radius: 12px;
  border: 1px solid rgb(226 232 240);
  cursor: pointer;
  transition: background 120ms ease, border-color 120ms ease;
  --student-row-accent: #1B6FB8;
}
.student-row:hover {
  background: rgb(248 250 252);
}
.student-row--selected {
  border-color: var(--student-row-accent);
  background: color-mix(in srgb, var(--student-row-accent) 6%, #fff);
}

.student-row__avatar-wrap {
  position: relative;
  flex-shrink: 0;
}
.student-row__check {
  position: absolute;
  top: -3px;
  right: -3px;
  width: 16px;
  height: 16px;
  border-radius: 999px;
  background: #fff;
  display: grid;
  place-items: center;
  box-shadow: 0 0 0 1.5px currentColor;
}

.student-row__identity {
  min-width: 0;
}
.student-row__name {
  font-size: 13px;
  font-weight: 700;
  color: rgb(15 23 42);
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.student-row__nis {
  font-weight: 500;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11.5px;
  color: rgb(100 116 139);
  margin-left: 2px;
}

.student-row__chip {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  border-radius: 6px;
  background: rgb(248 250 252);
  border: 1px solid rgb(226 232 240);
  font-size: 11px;
  font-weight: 700;
  color: rgb(30 41 59);
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}
.student-row__chip--empty {
  color: rgb(148 163 184);
  font-style: italic;
  font-family: inherit;
  font-weight: 500;
}

.student-row__wali {
  min-width: 0;
  font-size: 12px;
  color: rgb(51 65 85);
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.student-row__wali-label {
  font-weight: 700;
  color: rgb(100 116 139);
  margin-right: 6px;
  text-transform: uppercase;
  font-size: 10px;
  letter-spacing: 0.06em;
}
.student-row__empty {
  font-style: italic;
  color: rgb(148 163 184);
}

.student-row__status-dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
  flex-shrink: 0;
}
.student-row__status-dot--active {
  background: #10B981;                           /* green-500 */
}
.student-row__status-dot--inactive {
  background: #94A3B8;                           /* slate-400 */
}
.student-row__status-dot--unverified {
  background: #F59E0B;                           /* amber-500 */
}

.student-row__actions {
  display: flex;
  align-items: center;
  gap: 10px;
  padding-left: 4px;
  border-left: 1px solid rgb(226 232 240);
  margin-left: 4px;
}
.student-row__detail {
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
  white-space: nowrap;
}
.student-row__detail:hover {
  text-decoration: underline;
}
.student-row__delete {
  font-size: 11.5px;
  font-weight: 500;
  color: rgb(239 68 68);
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.student-row__delete:hover {
  text-decoration: underline;
}

/* ── Responsive: collapse to two lines on narrow screens ──────── */
@media (max-width: 720px) {
  .student-row {
    grid-template-columns: auto minmax(0, 1fr) auto auto;
    grid-template-areas:
      'avatar identity chip actions'
      'avatar wali    wali actions';
    row-gap: 4px;
  }
  .student-row__avatar-wrap {
    grid-area: avatar;
    align-self: start;
  }
  .student-row__identity {
    grid-area: identity;
  }
  .student-row__chip {
    grid-area: chip;
  }
  .student-row__wali {
    grid-area: wali;
    white-space: normal;
  }
  .student-row__actions {
    grid-area: actions;
    border-left: none;
    margin-left: 0;
    padding-left: 8px;
  }
  .student-row__status-dot {
    display: none;
  }
}
</style>
