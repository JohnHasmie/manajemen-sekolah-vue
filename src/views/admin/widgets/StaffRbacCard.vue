<!--
  StaffRbacCard.vue — admin "Data Staf" list card.

  Redesigned 2026-07-20 (Yahya feedback: "nama muncul truncated, panel
  akses seperti kartu terpisah"). The prior 3-column split (identity |
  access-panel | actions) with a tinted access panel forced nama into
  a narrow 260px column that clipped anything past ~20 characters
  ("Muchamad Zaenal Ari…") and made the access panel read as a second
  card riding alongside.

  Now: one unified card, nama gets full width with word-wrap so long
  names print entirely; akses becomes a compact chip cluster below
  the meta strip.

    ┌─────────────────────────────────────────────────────────┐
    │ [MZ]  Muchamad Zaenal Arifin, S.Kom.    Detail →  [⋮]  │
    │       [Penjaga]  NIP 46502800022                        │
    │                                                          │
    │  📞 08123371263    ✉ muza21@gmail.com                    │
    │                                                          │
    │  AKSES MODUL                                    8 aktif  │
    │  [Sekolah & Personel] [Dashboard] [Akademik]            │
    │  [Presensi] [Komunikasi] [Aktivitas Kelas] [AI]         │
    │  [Prestasi Guru]                                         │
    └─────────────────────────────────────────────────────────┘

  Design locks:
    * Name uses word-break: break-word — long names WRAP, never
      truncate. This was the explicit ask from the redesign feedback.
    * Role pill + NIP sit as meta line under the name (not stuffed
      into a narrow 260px column that ate the name width).
    * Modules become chip pills that wrap naturally — a Bendahara with
      3 modules gets a tight row; the Sekolah user with 15 modules
      wraps to 3-4 rows but every module is visible without a
      dedicated tinted "panel" fighting for attention.
    * Actions: `Detail →` inline link on the header + kebab (Hapus
      inside). Hapus behind a kebab = anti-misclick on a destructive
      admin action.
    * Same props / emits as pre-redesign so caller doesn't change.
-->
<script setup lang="ts">
import { computed, ref } from 'vue';
import type { StaffMember, StaffRbacSummary } from '@/types/staff';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';

const props = withDefaults(
  defineProps<{
    staff: StaffMember;
    primaryColor?: string;
  }>(),
  {
    primaryColor: '#4F46E5',
  },
);

const emit = defineEmits<{
  click: [];
  delete: [];
}>();

// ── Derived values ────────────────────────────────────────────────

const summary = computed<StaffRbacSummary>(
  () =>
    props.staff.rbac_summary ?? {
      modules_count: 0,
      modules: [],
      missing_expected: [],
    },
);

const employmentTone = computed<'ok' | 'warn' | 'neutral'>(() => {
  const s = (props.staff.employment_status ?? '').toLowerCase();
  if (['permanent', 'tetap', 'active'].includes(s)) return 'ok';
  if (['contract', 'kontrak', 'temporary', 'honorer'].includes(s)) return 'warn';
  return 'neutral';
});

const employmentLabel = computed<string>(() => {
  const raw = props.staff.employment_status;
  if (!raw) return '';
  switch (raw.toLowerCase()) {
    case 'permanent':
    case 'tetap':
      return 'Tetap';
    case 'contract':
    case 'kontrak':
      return 'Kontrak';
    case 'temporary':
    case 'honorer':
      return 'Honorer';
    case 'active':
      return 'Aktif';
    default:
      return raw;
  }
});

const missingHint = computed<string>(() => {
  const m = summary.value.missing_expected;
  if (m.length === 0) return '';
  const labels = m.map((x) => x.label).join(', ');
  return `Belum punya akses ke modul ${labels} — mungkin perlu tambah?`;
});

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

function onCardClick(e: MouseEvent) {
  if ((e.target as HTMLElement)?.closest?.('.staff-card__menu-wrap')) return;
  closeMenu();
  emit('click');
}
</script>

<template>
  <div
    class="staff-card"
    :style="{ '--staff-card-accent': primaryColor }"
    role="button"
    tabindex="0"
    @click="onCardClick"
    @keydown.enter.prevent="emit('click')"
    @keydown.space.prevent="emit('click')"
  >
    <!-- Header: avatar · name+meta · detail link · kebab -->
    <div class="staff-card__head">
      <InitialsAvatar
        :name="staff.name || '?'"
        :size="44"
        :color="primaryColor"
        :border-radius="10"
      />

      <div class="staff-card__title">
        <p class="staff-card__name">{{ staff.name || 'Tanpa nama' }}</p>
        <div class="staff-card__meta">
          <span
            v-if="staff.position"
            class="staff-card__pill"
          >{{ staff.position }}</span>
          <span
            v-if="employmentLabel"
            class="staff-card__pill staff-card__pill--dot"
            :class="`staff-card__pill--tone-${employmentTone}`"
          >
            <span class="staff-card__pill-dot" aria-hidden="true" />
            {{ employmentLabel }}
          </span>
          <span v-if="staff.employee_number" class="staff-card__nip">
            NIP {{ staff.employee_number }}
          </span>
        </div>
      </div>

      <div class="staff-card__head-actions">
        <button
          type="button"
          class="staff-card__detail"
          :style="{ color: primaryColor }"
          @click.stop="emit('click')"
        >
          Detail
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" width="12" height="12">
            <line x1="5" y1="12" x2="19" y2="12" />
            <polyline points="12 5 19 12 12 19" />
          </svg>
        </button>
        <div class="staff-card__menu-wrap" @click.stop>
          <button
            type="button"
            class="staff-card__menu-trigger"
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
          <div v-if="menuOpen" class="staff-card__menu" role="menu">
            <button type="button" role="menuitem" class="staff-card__menu-item staff-card__menu-item--danger" @click="onDelete">
              Hapus staf
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Contact strip -->
    <div v-if="staff.phone || staff.email" class="staff-card__contact">
      <span v-if="staff.phone" class="staff-card__contact-item">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" width="12" height="12">
          <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
        </svg>
        {{ staff.phone }}
      </span>
      <span v-if="staff.email" class="staff-card__contact-item staff-card__contact-item--email">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" width="12" height="12">
          <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
          <polyline points="22,6 12,13 2,6" />
        </svg>
        <span class="staff-card__email">{{ staff.email }}</span>
      </span>
    </div>

    <!-- Access modules -->
    <div class="staff-card__access">
      <div class="staff-card__access-head">
        <span class="staff-card__access-label">Akses modul</span>
        <span class="staff-card__access-count">{{ summary.modules_count }} aktif</span>
      </div>
      <div v-if="summary.modules.length > 0" class="staff-card__chips">
        <span
          v-for="m in summary.modules"
          :key="m.key"
          class="staff-card__chip"
        >{{ m.label }}</span>
      </div>
      <p v-else class="staff-card__access-empty">
        Belum ada akses ke modul apapun.
      </p>
      <p v-if="missingHint" class="staff-card__missing-hint">{{ missingHint }}</p>
    </div>
  </div>
</template>

<style scoped>
/*
 * Container — single flat card. No 3-column split, no tinted access
 * panel. All rows use the same left/right margin (16px padding) so
 * nothing reads as "a card riding inside another card".
 *
 * --staff-card-accent injected per-instance from primaryColor.
 */
.staff-card {
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
  --staff-card-accent: #4F46E5;
}
.staff-card:hover {
  border-color: rgb(203 213 225);                /* slate-300 */
  box-shadow: 0 4px 12px -4px rgb(0 0 0 / 0.08);
}
.staff-card:focus-visible {
  outline: 2px solid var(--staff-card-accent);
  outline-offset: 2px;
}

/* ── Header ─────────────────────────────────────────────────── */
.staff-card__head {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  min-width: 0;
}
.staff-card__title {
  flex: 1;
  min-width: 0;
}
.staff-card__name {
  margin: 0;
  font-size: 15px;
  font-weight: 600;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.3;
  /* Long names wrap instead of getting truncated — the explicit
     ask from the redesign feedback. */
  word-break: break-word;
  overflow-wrap: anywhere;
}
.staff-card__meta {
  margin-top: 6px;
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
}
.staff-card__pill {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 500;
  line-height: 1.3;
  background: color-mix(in srgb, var(--staff-card-accent) 10%, transparent);
  color: var(--staff-card-accent);
}
.staff-card__pill--dot .staff-card__pill-dot {
  width: 5px;
  height: 5px;
  border-radius: 999px;
  flex-shrink: 0;
}
.staff-card__pill--tone-ok {
  background: #ECFDF5;                           /* emerald-50 */
  color: #047857;                                /* emerald-700 */
}
.staff-card__pill--tone-ok .staff-card__pill-dot {
  background: #10B981;
}
.staff-card__pill--tone-warn {
  background: #FEF3C7;                           /* amber-100 */
  color: #B45309;                                /* amber-700 */
}
.staff-card__pill--tone-warn .staff-card__pill-dot {
  background: #F59E0B;
}
.staff-card__pill--tone-neutral {
  background: rgb(241 245 249);                  /* slate-100 */
  color: rgb(71 85 105);                         /* slate-600 */
}
.staff-card__pill--tone-neutral .staff-card__pill-dot {
  background: rgb(148 163 184);
}
.staff-card__nip {
  font-size: 11px;
  color: rgb(100 116 139);                       /* slate-500 */
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

/* ── Head actions ───────────────────────────────────────────── */
.staff-card__head-actions {
  display: flex;
  align-items: center;
  gap: 4px;
  flex-shrink: 0;
}
.staff-card__detail {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  border-radius: 6px;
  background: transparent;
  border: none;
  font-size: 12.5px;
  font-weight: 500;
  cursor: pointer;
  white-space: nowrap;
}
.staff-card__detail:hover {
  background: rgb(248 250 252);                  /* slate-50 */
}
.staff-card__menu-wrap {
  position: relative;
}
.staff-card__menu-trigger {
  background: transparent;
  border: none;
  color: rgb(148 163 184);                       /* slate-400 */
  cursor: pointer;
  padding: 4px;
  display: grid;
  place-items: center;
  border-radius: 6px;
}
.staff-card__menu-trigger:hover {
  background: rgb(241 245 249);
  color: rgb(71 85 105);
}
.staff-card__menu {
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
.staff-card__menu-item {
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
.staff-card__menu-item:hover {
  background: rgb(248 250 252);
}
.staff-card__menu-item--danger {
  color: #B91C1C;                                /* red-700 */
}
.staff-card__menu-item--danger:hover {
  background: #FEF2F2;
}

/* ── Contact strip ──────────────────────────────────────────── */
.staff-card__contact {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 8px 0;
  border-top: 1px solid rgb(241 245 249);        /* slate-100 */
  border-bottom: 1px solid rgb(241 245 249);
  font-size: 12px;
  color: rgb(100 116 139);                       /* slate-500 */
  flex-wrap: wrap;
}
.staff-card__contact-item {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-width: 0;
}
.staff-card__contact-item--email {
  min-width: 0;
  flex: 1;
}
.staff-card__email {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}

/* ── Access modules ─────────────────────────────────────────── */
.staff-card__access {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.staff-card__access-head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}
.staff-card__access-label {
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: rgb(100 116 139);                       /* slate-500 */
}
.staff-card__access-count {
  font-size: 12px;
  font-weight: 500;
  color: rgb(71 85 105);                         /* slate-600 */
  font-variant-numeric: tabular-nums;
}
.staff-card__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}
.staff-card__chip {
  display: inline-flex;
  align-items: center;
  padding: 3px 8px;
  border-radius: 999px;
  background: rgb(248 250 252);                  /* slate-50 */
  border: 1px solid rgb(226 232 240);            /* slate-200 */
  font-size: 11px;
  color: rgb(30 41 59);                          /* slate-800 */
  line-height: 1.4;
}
.staff-card__access-empty {
  margin: 0;
  font-size: 12px;
  color: rgb(148 163 184);                       /* slate-400 */
  font-style: italic;
}
.staff-card__missing-hint {
  margin: 0;
  font-size: 11.5px;
  color: #B45309;                                /* amber-700 */
  line-height: 1.4;
}
</style>
