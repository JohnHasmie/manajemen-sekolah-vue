<!--
  StaffRbacCard.vue — RBAC-forward split card for the admin "Data Staf"
  page. Wireframe: Entitas 2 · Opsi B.

  Layout (>= 720px):
    ┌────────────────────────┬─────────────────────────────────┬─────────┐
    │ [avatar] Nama          │ ┌ AKSES YANG DIMILIKI   N modul │ Detail →│
    │          NIP           │ │ • Pengaturan RBAC             │         │
    │          [pill jabatan]│ │ • Keuangan                    │         │
    │          [pill status] │ │ • Akademik                    │         │
    │          08xxx · email │ │ Belum punya akses ke modul … │  Hapus  │
    │                        │ └───────────────────────────────│         │
    └────────────────────────┴─────────────────────────────────┴─────────┘

  Below 720px the three columns stack vertically and the action column
  collapses into a right-aligned inline row (mirrors TeacherStructuredCard
  breakpoints so the two admin pages feel consistent).

  Falls back gracefully to "0 modul · Belum ada akses" when the backend
  hasn't rolled out `rbac_summary` yet — the card still renders.
-->
<script setup lang="ts">
import { computed } from 'vue';
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

/**
 * Kepegawaian tone.
 * - permanent / tetap / active  → "ok" (green dot)
 * - contract / kontrak / temporary / honorer → "warn" (amber dot)
 * - everything else (blank, unknown) → "neutral" (slate dot)
 * Mapping mirrors the employmentOptions dict on AdminStaffManagementView.
 */
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

const contactLine = computed<string>(() => {
  const parts: string[] = [];
  if (props.staff.phone) parts.push(props.staff.phone);
  if (props.staff.email) parts.push(props.staff.email);
  return parts.join(' · ');
});

const missingHint = computed<string>(() => {
  const m = summary.value.missing_expected;
  if (m.length === 0) return '';
  const labels = m.map((x) => x.label).join(', ');
  return `Belum punya akses ke modul ${labels} — mungkin perlu tambah?`;
});
</script>

<template>
  <div
    class="rbac-card"
    :style="{ '--rbac-card-accent': primaryColor }"
    role="button"
    tabindex="0"
    @click="emit('click')"
    @keydown.enter.prevent="emit('click')"
    @keydown.space.prevent="emit('click')"
  >
    <!-- LEFT · Identity strip ---------------------------------- -->
    <div class="side">
      <div class="identity-row">
        <InitialsAvatar
          :name="staff.name || '?'"
          :size="44"
          :color="primaryColor"
          :border-radius="10"
        />
        <div class="name-block">
          <p class="name">{{ staff.name || 'Tanpa nama' }}</p>
          <p v-if="staff.employee_number" class="nip">
            NIP {{ staff.employee_number }}
          </p>
        </div>
      </div>

      <div class="pills-row">
        <span class="pill pill--brand">{{ staff.position || '—' }}</span>
        <span
          v-if="employmentLabel"
          class="pill pill--dot"
          :class="`pill--tone-${employmentTone}`"
        >
          <span class="pill__dot" aria-hidden="true" />
          {{ employmentLabel }}
        </span>
      </div>

      <p v-if="contactLine" class="contact-row">{{ contactLine }}</p>
    </div>

    <!-- MIDDLE · Access panel ---------------------------------- -->
    <div class="body">
      <div class="access-panel">
        <div class="head-row">
          <span class="access-label">AKSES YANG DIMILIKI</span>
          <span class="access-count">{{ summary.modules_count }} modul</span>
        </div>

        <ul v-if="summary.modules.length > 0" class="access-list">
          <li v-for="m in summary.modules" :key="m.key">{{ m.label }}</li>
        </ul>
        <p v-else class="empty-hint">Belum ada akses ke modul apapun.</p>

        <p v-if="missingHint" class="missing-hint">{{ missingHint }}</p>
      </div>
    </div>

    <!-- RIGHT · Actions column --------------------------------- -->
    <div class="actions-col">
      <button
        type="button"
        class="link-btn"
        :style="{ color: primaryColor }"
        @click.stop="emit('click')"
      >
        Detail →
      </button>
      <button
        type="button"
        class="link-btn link-btn--danger"
        @click.stop="emit('delete')"
      >
        Hapus
      </button>
    </div>
  </div>
</template>

<style scoped>
/*
 * Container — mirrors form-card (rounded-card, white surface, shadow-card)
 * plus the split-column grid described in the wireframe. Kept as scoped
 * bespoke CSS (same approach as TeacherStructuredCard.vue) so the RBAC
 * tokens don't leak into the global Tailwind space.
 *
 * --rbac-card-accent is injected per-instance from the primaryColor prop so
 * the "AKSES YANG DIMILIKI" panel and the bullet dots pick up whatever the
 * caller's role color is (indigo for admin, staff amber for staff, …).
 */
.rbac-card {
  display: grid;
  grid-template-columns: 260px 1fr auto;
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
  --rbac-card-accent: #4F46E5;
}
.rbac-card:hover {
  box-shadow:
    0 2px 4px 0 rgb(0 0 0 / 0.06),
    0 8px 24px -4px rgb(0 0 0 / 0.08);
}
.rbac-card:focus-visible {
  outline: 2px solid var(--rbac-card-accent);
  outline-offset: 2px;
}

/* ── LEFT · Identity ─────────────────────────────────────────── */
.side {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-right: 16px;
  border-right: 1px dashed rgb(203 213 225);    /* slate-300 */
  min-width: 0;
}
.identity-row {
  display: flex;
  gap: 12px;
  align-items: flex-start;
}
.name-block {
  min-width: 0;
  flex: 1;
}
.name {
  font-size: 15px;
  font-weight: 700;
  color: rgb(15 23 42);                          /* slate-900 */
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.nip {
  margin-top: 2px;
  font-size: 11px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: rgb(100 116 139);                       /* slate-500 */
}
.pills-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}
.pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.01em;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pill--brand {
  background: color-mix(in srgb, var(--rbac-card-accent) 12%, transparent);
  color: var(--rbac-card-accent);
}
.pill--dot .pill__dot {
  width: 6px;
  height: 6px;
  border-radius: 999px;
  flex-shrink: 0;
}
.pill--tone-ok {
  background: #ECFDF5;                           /* status-success-soft */
  color: #047857;                                /* emerald-700 */
}
.pill--tone-ok .pill__dot {
  background: #10B981;                           /* status-success */
}
.pill--tone-warn {
  background: #FEF3C7;                           /* status-warning-soft */
  color: #B45309;                                /* amber-700 */
}
.pill--tone-warn .pill__dot {
  background: #F59E0B;                           /* status-warning */
}
.pill--tone-neutral {
  background: rgb(241 245 249);                  /* slate-100 */
  color: rgb(71 85 105);                         /* slate-600 */
}
.pill--tone-neutral .pill__dot {
  background: rgb(148 163 184);                  /* slate-400 */
}
.contact-row {
  font-size: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
  color: rgb(100 116 139);                       /* slate-500 */
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* ── MIDDLE · Access panel ───────────────────────────────────── */
.body {
  min-width: 0;
  display: flex;
}
.access-panel {
  flex: 1;
  min-width: 0;
  padding: 12px 14px;
  border-radius: 12px;
  background: color-mix(in srgb, var(--rbac-card-accent) 8%, transparent);
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.head-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}
.access-label {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--rbac-card-accent);
}
.access-count {
  font-size: 13px;
  font-weight: 700;
  color: var(--rbac-card-accent);
  font-variant-numeric: tabular-nums;
}
.access-list {
  list-style: none;
  padding: 0;
  margin: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 4px 16px;
}
.access-list li {
  position: relative;
  padding-left: 12px;
  font-size: 12.5px;
  line-height: 1.4;
  color: rgb(30 41 59);                          /* slate-800 */
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.access-list li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 8px;
  width: 4px;
  height: 4px;
  border-radius: 50%;
  background: var(--rbac-card-accent);
}
.empty-hint {
  font-size: 12.5px;
  font-style: italic;
  color: rgb(100 116 139);                       /* slate-500 */
}
.missing-hint {
  font-size: 11.5px;
  color: #B45309;                                /* amber-700 — brand-2 nudge tone */
  line-height: 1.4;
}

/* ── RIGHT · Actions column ──────────────────────────────────── */
.actions-col {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: flex-end;
  gap: 12px;
  padding-left: 12px;
  min-width: 72px;
}
.link-btn {
  font-size: 12.5px;
  font-weight: 600;
  white-space: nowrap;
  cursor: pointer;
  background: transparent;
  border: none;
  padding: 0;
}
.link-btn:hover {
  text-decoration: underline;
}
.link-btn--danger {
  font-size: 12px;
  font-weight: 500;
  color: rgb(239 68 68);                         /* status-danger */
}

/* ── Responsive: stack on narrow screens ─────────────────────── */
@media (max-width: 720px) {
  .rbac-card {
    grid-template-columns: 1fr;
    gap: 12px;
  }
  .side {
    border-right: none;
    border-bottom: 1px dashed rgb(203 213 225);
    padding-right: 0;
    padding-bottom: 12px;
  }
  .actions-col {
    flex-direction: row;
    align-items: center;
    justify-content: flex-end;
    padding-left: 0;
    padding-top: 8px;
    border-top: 1px dashed rgb(203 213 225);
    gap: 20px;
  }
}
</style>
