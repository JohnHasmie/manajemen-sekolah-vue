<!--
  BrandListRow.vue — canonical admin list-row layout (SS2).
  Port of `lib/core/widgets/brand_list_row.dart`.

  Layout (matches Flutter's StudentCard / TeacherCard / ClassCard exactly):
    ┌────────────────────────────────────────────────┐
    │ ▢   topMeta (class · NIS 8237)     Detail →    │
    │ ▢                                              │
    │ ▢   Title (bold)                               │
    │ ▢                                              │
    │     ● Status (inline dot + label)              │
    └────────────────────────────────────────────────┘

  Selection mode: when `selected=true`, the trailing CTA is hidden, the
  row gains an accent ring, and a check overlay appears on the avatar.
-->
<script setup lang="ts">
export interface RowStatus {
  tone: 'success' | 'warning' | 'danger' | 'info' | 'neutral';
  label: string;
}

withDefaults(
  defineProps<{
    topMeta?: string;
    title: string;
    status?: RowStatus | null;
    trailingActionLabel?: string;
    trailingActionColor?: string;
    selected?: boolean;
    /** When true, makes the row a long-press target for bulk select. */
    bulkSelectable?: boolean;
  }>(),
  {
    topMeta: '',
    status: null,
    trailingActionLabel: '',
    trailingActionColor: '#4F46E5',
    selected: false,
    bulkSelectable: false,
  },
);

defineEmits<{
  click: [MouseEvent];
  longPress: [];
}>();

let longPressTimer: ReturnType<typeof setTimeout> | null = null;

function onPointerDown(emit: (() => void) | undefined) {
  if (longPressTimer) clearTimeout(longPressTimer);
  longPressTimer = setTimeout(() => {
    longPressTimer = null;
    emit?.();
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
    class="form-card p-md cursor-pointer transition-all hover:shadow-md"
    :class="{
      'ring-2': selected,
    }"
    :style="selected ? { '--tw-ring-color': trailingActionColor } : {}"
    @click="$emit('click', $event)"
    @pointerdown="onPointerDown(bulkSelectable ? () => $emit('longPress') : undefined)"
    @pointerup="onPointerUp"
    @pointerleave="onPointerUp"
  >
    <div class="flex items-start gap-3">
      <div class="relative flex-shrink-0">
        <slot name="leading" />
        <span
          v-if="selected"
          class="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-white grid place-items-center"
          :style="{ color: trailingActionColor }"
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

      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between gap-2">
          <p
            v-if="topMeta"
            class="text-xs text-slate-500 truncate"
          >
            {{ topMeta }}
          </p>
          <button
            v-if="!selected && trailingActionLabel"
            type="button"
            class="text-xs font-semibold whitespace-nowrap hover:underline"
            :style="{ color: trailingActionColor }"
            @click.stop="$emit('click', $event)"
          >
            {{ trailingActionLabel }} →
          </button>
        </div>

        <p class="text-sm font-bold text-slate-900 mt-0.5 truncate">
          {{ title }}
        </p>

        <p v-if="status" class="text-xs mt-1 flex items-center gap-1.5">
          <span
            class="w-1.5 h-1.5 rounded-full"
            :class="{
              'bg-status-success': status.tone === 'success',
              'bg-status-warning': status.tone === 'warning',
              'bg-status-danger': status.tone === 'danger',
              'bg-status-info': status.tone === 'info',
              'bg-slate-400': status.tone === 'neutral',
            }"
          />
          <span
            :class="{
              'text-status-success': status.tone === 'success',
              'text-amber-700': status.tone === 'warning',
              'text-status-danger': status.tone === 'danger',
              'text-status-info': status.tone === 'info',
              'text-slate-600': status.tone === 'neutral',
            }"
          >
            {{ status.label }}
          </span>
        </p>

        <slot />
      </div>
    </div>
  </div>
</template>
