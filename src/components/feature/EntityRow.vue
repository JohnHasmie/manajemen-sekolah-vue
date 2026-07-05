<!--
  EntityRow.vue — canonical HORIZONTAL bordered list-row primitive.

  Distinct from `BrandListRow` (which is a VERTICAL form-card idiom:
  topMeta-above / bold-title / status-dot-below, used by ~4 CRUD views).
  This is the OTHER, more common idiom duplicated ~10× across the admin,
  teacher and parent surfaces: a horizontal table row inside a bordered
  card list —

    ┌───────────────────────────────────────────────────────────┐
    │ ▢   Title (bold)                    [pill] [badge]  ›       │
    │     subtitle · meta                                        │
    └───────────────────────────────────────────────────────────┘

  The idiom, verbatim from the real sites (AdminReportCardClassView,
  TeacherReportCardClassView, AdminAttendanceReportView / DetailView,
  AdminSubjectClassManagementView, …):

    container:  bg-white border border-slate-200 rounded-2xl overflow-hidden
    row:        px-4 py-3 flex items-center gap-3
    divider:    border-t border-slate-100   (every row after the first)
    hover:      hover:bg-slate-50 + cursor-pointer  (when tappable)

  The CONTAINER stays in the calling view (it owns the AsyncView empty
  state and, sometimes, a table/grid alternate view-mode). This component
  is ONE row; the view keeps `v-for`-ing over its data and passes
  `:divided="idx > 0"`.

  ─ Leading ────────────────────────────────────────────────────────────
    • `avatar` prop → composes the existing `InitialsAvatar` (name + the
      per-row dynamic colour every roster row already sets).
    • `icon` prop → a NavIcon in a soft square (entity icon).
    • `#leading` slot → anything bespoke (checkbox, numeric stat box).

  ─ Body ───────────────────────────────────────────────────────────────
    • `title` + optional `subtitle` props (the 95% case), OR
    • `#body` slot for multi-line meta (attendance alert / notes lines).

  ─ Trailing ───────────────────────────────────────────────────────────
    • `#trailing` slot for the tone-coloured pill (reuse `StatusBadge`),
      count badges, right-aligned stats, inline action buttons.
    • `chevron` prop → the built-in `chevron-right` NavIcon nearly every
      tappable row ends with (colour/size match the existing rows).

  ─ Accent edge (optional) ─────────────────────────────────────────────
    • `accent` → a 4px coloured left bar (grade-overview's score edge).
      Pass a Tailwind bg-class string (e.g. `bg-emerald-500`).

  ─ Tappable ───────────────────────────────────────────────────────────
    • `to` (router target) → renders as `<RouterLink>`.
    • otherwise a bound `@click` → renders as `<button>`.
    • neither → renders as a plain `<div>` (non-interactive, no hover).
    The element choice + hover chrome mirrors the originals exactly so
    adoption is pixel-faithful.
-->
<script lang="ts">
// A tappable row must resolve to a real <button>/<RouterLink> for keyboard
// + a11y parity with the originals (which were <button> / <li @click> /
// <div @click>). `inheritAttrs: false` lets us forward listeners + extra
// attrs onto that resolved root element ourselves.
export default { inheritAttrs: false };
</script>

<script setup lang="ts">
import { computed, useAttrs } from 'vue';
import type { RouteLocationRaw } from 'vue-router';
import InitialsAvatar from '@/components/feature/InitialsAvatar.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

/** Leading avatar spec — mirrors `InitialsAvatar`'s props 1:1. */
export interface EntityRowAvatar {
  name: string;
  /** px. Roster rows use 40; grade-overview uses 38. Defaults to 40. */
  size?: number;
  /** Hex fill. Rows tint this per-row (danger/warning/brand). */
  color?: string;
  /** px corner radius. Defaults to 12 (the roster-row value). */
  borderRadius?: number;
  imageUrl?: string | null;
}

const props = withDefaults(
  defineProps<{
    /** Bold primary line. Optional when the `#body` slot is used. */
    title?: string;
    /** Muted meta line under the title (single line; use #body for more). */
    subtitle?: string;
    /** Leading avatar — composes InitialsAvatar. */
    avatar?: EntityRowAvatar | null;
    /** Leading icon (NavIcon name) rendered in a soft square. */
    icon?: string | null;
    /** Tailwind text-colour class for the leading icon. */
    iconClass?: string;
    /** Show the trailing chevron-right that tappable rows end with. */
    chevron?: boolean;
    /** router-link target — renders the row as a <RouterLink>. */
    to?: RouteLocationRaw | null;
    /** 4px coloured left accent bar — pass a Tailwind bg-* class. */
    accent?: string | null;
    /** Draw the `border-t border-slate-100` divider (every row after #1). */
    divided?: boolean;
    /** Selected / dirty background tint (`true` → admin tint, or a class). */
    highlighted?: boolean | string;
  }>(),
  {
    title: '',
    subtitle: '',
    avatar: null,
    icon: null,
    iconClass: 'text-slate-500',
    chevron: false,
    to: null,
    accent: null,
    divided: false,
    highlighted: false,
  },
);

// NOTE: `click` is deliberately NOT declared in defineEmits. We want the
// parent's `@click` to FALL THROUGH via `v-bind="attrs"` onto the resolved
// root element (<button>/<RouterLink>/<div>) — a declared emit would strip
// `onClick` out of `attrs`, breaking the `'onClick' in attrs` interactivity
// detection below. Fall-through also means the handler fires natively on the
// real interactive element, matching the originals' behaviour exactly.
const attrs = useAttrs();

// A click handler arrives as `onClick` in attrs. Presence (or a router
// target) => the row is interactive: real element + hover chrome.
const isLink = computed(() => props.to != null);
const interactive = computed(() => isLink.value || 'onClick' in attrs);

const rootTag = computed(() => {
  if (isLink.value) return 'RouterLink';
  if ('onClick' in attrs) return 'button';
  return 'div';
});

// Background tint: `true` → the common admin selection tint; a string →
// that exact class (views pass their own role-scoped tint).
const highlightClass = computed(() => {
  if (props.highlighted === true) return 'bg-role-admin/5';
  if (typeof props.highlighted === 'string' && props.highlighted)
    return props.highlighted;
  return '';
});
</script>

<template>
  <component
    :is="rootTag"
    v-bind="attrs"
    :to="isLink ? (to ?? undefined) : undefined"
    :type="rootTag === 'button' ? 'button' : undefined"
    class="w-full text-left px-4 py-3 flex items-center gap-3 transition-colors relative"
    :class="[
      interactive ? 'cursor-pointer hover:bg-slate-50' : '',
      divided ? 'border-t border-slate-100' : '',
      highlightClass,
    ]"
  >
    <!-- 4px coloured left accent edge -->
    <span
      v-if="accent"
      class="absolute left-0 top-0 bottom-0 w-1"
      :class="accent"
      aria-hidden="true"
    />

    <!-- LEADING -->
    <slot name="leading">
      <InitialsAvatar
        v-if="avatar"
        :name="avatar.name || '?'"
        :size="avatar.size ?? 40"
        :color="avatar.color ?? '#143068'"
        :border-radius="avatar.borderRadius ?? 12"
        :image-url="avatar.imageUrl ?? null"
      />
      <span
        v-else-if="icon"
        class="w-10 h-10 rounded-xl bg-slate-100 grid place-items-center flex-shrink-0"
        :class="iconClass"
      >
        <NavIcon :name="icon" :size="18" />
      </span>
    </slot>

    <!-- BODY -->
    <div class="flex-1 min-w-0">
      <slot name="body">
        <p
          v-if="title"
          class="text-[13px] font-bold text-slate-900 truncate"
        >
          {{ title }}
        </p>
        <p
          v-if="subtitle"
          class="text-2xs text-slate-500 truncate"
        >
          {{ subtitle }}
        </p>
      </slot>
    </div>

    <!-- TRAILING -->
    <slot name="trailing" />

    <!-- CHEVRON -->
    <NavIcon
      v-if="chevron"
      name="chevron-right"
      :size="14"
      class="text-slate-300 flex-shrink-0"
    />
  </component>
</template>
