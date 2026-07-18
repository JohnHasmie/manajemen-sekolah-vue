<!--
  TeacherStructuredCard.vue — the two-column structured card that
  replaces the compact BrandListRow variant on the admin "Data Guru"
  page. Wireframe: Opsi 2 · Dua kolom terstruktur.

  Layout (>= md):
    ┌─────────────────────────┬───────────────────────────────────┬─────────┐
    │ [avatar]  Nama guru     │ MAPEL YANG DIAMPU    KELAS         │ Detail →│
    │           NIP           │ [chip] [chip]        [chip]        │         │
    │           [pill role]   │                                    │  Hapus  │
    │                         │ WALI KELAS           KONTAK        │         │
    │                         │ [chip] / Bukan wali  081... / —    │         │
    └─────────────────────────┴───────────────────────────────────┴─────────┘

  Below 800px the three columns stack vertically and the action column
  collapses into a right-aligned inline row.

  Selection: long-press or bulk-check the card to toggle selection.
  When selected, a check overlay lands on the avatar and the whole
  card gains an accent ring, mirroring BrandListRow.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { Teacher } from '@/types/entities';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';

const props = withDefaults(
  defineProps<{
    teacher: Teacher;
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

// ── Derived values ────────────────────────────────────────────────

const isHomeroom = computed(() => {
  // Prefer the enriched `homeroom_of` object; fall back to the flat
  // scalar/array pair the pre-deploy backend still emits.
  if (props.teacher.homeroom_of !== undefined) {
    return Boolean(props.teacher.homeroom_of);
  }
  if (props.teacher.homeroom_class_name) return true;
  return (props.teacher.homeroom_class_names?.length ?? 0) > 0;
});

const pillLabel = computed(() =>
  isHomeroom.value ? 'Wali Kelas' : 'Guru',
);

const subjectChips = computed(() => {
  const structured = props.teacher.subjects;
  if (structured && structured.length > 0) {
    // Backend has deduped; render as [CODE · Name] when a code is
    // present, otherwise just the name.
    return structured.map((s) => ({
      key: s.id,
      label: s.code ? `${s.code} · ${s.name}` : s.name,
    }));
  }
  // Legacy fallback: dedupe by name on the client so the old
  // "Bahasa Inggris, Bahasa Inggris, Bahasa Inggris" cards no longer
  // repeat entries even when the backend hasn't shipped the enriched
  // response yet.
  const names = props.teacher.subject_names ?? [];
  const seen = new Set<string>();
  const out: { key: string; label: string }[] = [];
  for (const n of names) {
    const label = (n ?? '').trim();
    if (!label || seen.has(label)) continue;
    seen.add(label);
    out.push({ key: label, label });
  }
  return out;
});

const classChips = computed(() => {
  const tc = props.teacher.teaching_classes;
  if (Array.isArray(tc)) {
    return tc.map((c) => ({ key: c.id, label: c.name }));
  }
  return [];
});

const homeroomChip = computed<{ key: string; label: string } | null>(() => {
  const h = props.teacher.homeroom_of;
  if (h && h.id) return { key: h.id, label: h.name };
  // Legacy fallbacks — surface a chip even before the backend rolls out.
  if (props.teacher.homeroom_class_name) {
    return {
      key: props.teacher.homeroom_class_id ?? props.teacher.homeroom_class_name,
      label: props.teacher.homeroom_class_name,
    };
  }
  const arr = props.teacher.homeroom_class_names ?? [];
  if (arr.length > 0) return { key: arr[0], label: arr[0] };
  return null;
});

const phoneDisplay = computed(() => {
  const p = props.teacher.phone_number?.trim();
  return p && p.length > 0 ? p : null;
});

// ── Long-press bulk-select (mirrors BrandListRow) ─────────────────
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
    class="teacher-card"
    :class="{ 'teacher-card--selected': selected }"
    :style="selected ? { '--teacher-card-accent': accentColor } : {}"
    @click="emit('click', $event)"
    @pointerdown="onPointerDown"
    @pointerup="onPointerUp"
    @pointerleave="onPointerUp"
  >
    <!-- LEFT · Identity ----------------------------------------- -->
    <div class="teacher-card__identity">
      <div class="teacher-card__avatar-wrap">
        <InitialsAvatar
          :name="teacher.name || '?'"
          :size="44"
          :color="accentColor"
          :border-radius="12"
        />
        <span
          v-if="selected"
          class="teacher-card__check"
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
      <div class="teacher-card__identity-text">
        <p class="teacher-card__name">
          {{ teacher.name || '—' }}
        </p>
        <p class="teacher-card__nip">
          {{ teacher.employee_number || 'NIP belum diisi' }}
        </p>
        <span
          class="teacher-card__pill"
          :class="isHomeroom ? 'teacher-card__pill--wali' : 'teacher-card__pill--guru'"
        >
          {{ pillLabel }}
        </span>
      </div>
    </div>

    <!-- RIGHT · Assignment 2×2 grid ----------------------------- -->
    <div class="teacher-card__assignment">
      <div class="teacher-card__field">
        <p class="teacher-card__label">Mapel yang Diampu</p>
        <div v-if="subjectChips.length > 0" class="teacher-card__chips">
          <span
            v-for="s in subjectChips"
            :key="s.key"
            class="teacher-card__chip"
          >{{ s.label }}</span>
        </div>
        <span v-else class="teacher-card__empty">Belum ada mapel</span>
      </div>

      <div class="teacher-card__field">
        <p class="teacher-card__label">Kelas yang Dipegang</p>
        <div v-if="classChips.length > 0" class="teacher-card__chips">
          <span
            v-for="c in classChips"
            :key="c.key"
            class="teacher-card__chip teacher-card__chip--class"
          >{{ c.label }}</span>
        </div>
        <span v-else class="teacher-card__empty">Belum diberi kelas</span>
      </div>

      <div class="teacher-card__field">
        <p class="teacher-card__label">Wali Kelas</p>
        <div v-if="homeroomChip" class="teacher-card__chips">
          <span class="teacher-card__chip teacher-card__chip--wali">
            {{ homeroomChip.label }}
          </span>
        </div>
        <span v-else class="teacher-card__empty">Bukan wali</span>
      </div>

      <div class="teacher-card__field">
        <p class="teacher-card__label">Kontak</p>
        <p v-if="phoneDisplay" class="teacher-card__phone">
          {{ phoneDisplay }}
        </p>
        <span v-else class="teacher-card__empty">—</span>
      </div>
    </div>

    <!-- Actions column ----------------------------------------- -->
    <div class="teacher-card__actions">
      <button
        type="button"
        class="teacher-card__detail"
        :style="{ color: accentColor }"
        @click.stop="emit('detail')"
      >Detail →</button>
      <button
        type="button"
        class="teacher-card__delete"
        @click.stop="emit('delete')"
      >Hapus</button>
    </div>
  </div>
</template>

<style scoped>
/*
 * Card container — mirrors the existing `form-card` (rounded-card,
 * white surface, shadow-card) but adds the two-column grid layout
 * described in the wireframe. Kept scoped to this component so the
 * bespoke chip styles don't leak out.
 */
.teacher-card {
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
  --teacher-card-accent: #1B6FB8;
}
.teacher-card:hover {
  box-shadow:
    0 2px 4px 0 rgb(0 0 0 / 0.06),
    0 8px 24px -4px rgb(0 0 0 / 0.08);
}
.teacher-card--selected {
  border-color: var(--teacher-card-accent);
  box-shadow:
    0 0 0 2px var(--teacher-card-accent),
    0 4px 16px -2px rgb(0 0 0 / 0.06);
}

/* ── Identity column ─────────────────────────────────────────── */
.teacher-card__identity {
  display: flex;
  gap: 12px;
  align-items: flex-start;
  padding-right: 16px;
  border-right: 1px dashed rgb(203 213 225);    /* slate-300 */
}
.teacher-card__avatar-wrap {
  position: relative;
  flex-shrink: 0;
}
.teacher-card__check {
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
.teacher-card__identity-text {
  min-width: 0;
  flex: 1;
}
.teacher-card__name {
  font-size: 15px;
  font-weight: 700;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.teacher-card__nip {
  margin-top: 2px;
  font-size: 11px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: rgb(100 116 139);                       /* slate-500 */
}
.teacher-card__pill {
  display: inline-block;
  margin-top: 8px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.01em;
}
.teacher-card__pill--guru {
  background: #E6F7FD;                           /* role-teacher-soft */
  color: #1B6FB8;                                /* role-teacher */
}
.teacher-card__pill--wali {
  background: #CCFBF1;                           /* teal-100 */
  color: #0F766E;                                /* teal-700 */
}

/* ── Assignment 2×2 grid ─────────────────────────────────────── */
.teacher-card__assignment {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px 20px;
  min-width: 0;
}
.teacher-card__field {
  min-width: 0;
}
.teacher-card__label {
  font-size: 10.5px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: rgb(100 116 139);                       /* slate-500 */
  margin-bottom: 6px;
}
.teacher-card__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
.teacher-card__chip {
  display: inline-flex;
  align-items: center;
  padding: 3px 8px;
  border-radius: 6px;
  background: rgb(248 250 252);                  /* slate-50 (panel-2 analog) */
  border: 1px solid rgb(226 232 240);            /* slate-200 (border-soft) */
  font-size: 12px;
  color: rgb(30 41 59);                          /* slate-800 */
  line-height: 1.4;
}
.teacher-card__chip--class {
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 11.5px;
  font-weight: 600;
}
.teacher-card__chip--wali {
  background: #F0FDFA;                           /* teal-50 */
  border-color: #99F6E4;                         /* teal-200 */
  color: #0F766E;                                /* teal-700 */
  font-weight: 600;
}
.teacher-card__empty {
  font-size: 12.5px;
  font-style: italic;
  color: rgb(148 163 184);                       /* slate-400 */
}
.teacher-card__phone {
  font-size: 13px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: rgb(30 41 59);
}

/* ── Actions column ──────────────────────────────────────────── */
.teacher-card__actions {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: flex-end;
  gap: 12px;
  padding-left: 12px;
  min-width: 72px;
}
.teacher-card__detail {
  font-size: 12.5px;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.teacher-card__detail:hover {
  text-decoration: underline;
}
.teacher-card__delete {
  font-size: 12px;
  font-weight: 500;
  color: rgb(239 68 68);                         /* status-danger */
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.teacher-card__delete:hover {
  text-decoration: underline;
}

/* ── Responsive: stack columns on narrow screens ─────────────── */
@media (max-width: 800px) {
  .teacher-card {
    grid-template-columns: 1fr;
    gap: 12px;
  }
  .teacher-card__identity {
    border-right: none;
    border-bottom: 1px dashed rgb(203 213 225);
    padding-right: 0;
    padding-bottom: 12px;
  }
  .teacher-card__assignment {
    grid-template-columns: 1fr 1fr;
    gap: 10px 16px;
  }
  .teacher-card__actions {
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
  .teacher-card__assignment {
    grid-template-columns: 1fr;
  }
}
</style>
