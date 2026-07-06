<!--
  InfoHint.vue — a small "?" affordance that reveals a plain-language
  explanation of a term (KKM, an RPP status, a permission key, …).

  School-friendly glossary primitive: teachers, parents and principals
  meet a lot of jargon, and this lets any label carry a one-tap
  explanation without cluttering the layout. Shows on hover (pointer),
  and on click/tap + keyboard focus (touch + a11y), so it works on
  phones and for keyboard users.
-->
<script setup lang="ts">
import { ref, onBeforeUnmount } from 'vue';

withDefaults(
  defineProps<{
    /** The explanation shown in the bubble. */
    text: string;
    /** Accessible label for the trigger. */
    ariaLabel?: string;
    /** Bubble placement relative to the trigger. */
    placement?: 'top' | 'bottom';
  }>(),
  { ariaLabel: 'Penjelasan', placement: 'top' },
);

const open = ref(false);
let hideTimer: ReturnType<typeof setTimeout> | null = null;

function show(): void {
  if (hideTimer) {
    clearTimeout(hideTimer);
    hideTimer = null;
  }
  open.value = true;
}
// Small delay so moving the pointer from the button onto the bubble
// (or vice-versa) doesn't flicker it shut.
function hideSoon(): void {
  hideTimer = setTimeout(() => {
    open.value = false;
  }, 90);
}
function toggle(): void {
  open.value = !open.value;
}

onBeforeUnmount(() => {
  if (hideTimer) clearTimeout(hideTimer);
});
</script>

<template>
  <span class="info-hint" @mouseenter="show" @mouseleave="hideSoon">
    <button
      type="button"
      class="info-hint__btn"
      :aria-label="ariaLabel"
      :aria-expanded="open"
      @click.stop.prevent="toggle"
      @focus="show"
      @blur="hideSoon"
    >
      ?
    </button>
    <transition name="info-hint-fade">
      <span
        v-if="open"
        class="info-hint__bubble"
        :class="`info-hint__bubble--${placement}`"
        role="tooltip"
      >
        {{ text }}
      </span>
    </transition>
  </span>
</template>

<style scoped>
.info-hint {
  position: relative;
  display: inline-flex;
  vertical-align: middle;
}
.info-hint__btn {
  width: 15px;
  height: 15px;
  border-radius: 9999px;
  border: none;
  background: #cbd5e1;
  color: #ffffff;
  font-size: 10px;
  font-weight: 700;
  line-height: 1;
  cursor: help;
  display: grid;
  place-items: center;
  padding: 0;
}
.info-hint__btn:hover,
.info-hint__btn:focus-visible {
  background: #1b6fb8;
  outline: none;
}
.info-hint__bubble {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  z-index: 50;
  width: max-content;
  max-width: 220px;
  background: #0f172a;
  color: #f8fafc;
  font-size: 11px;
  font-weight: 400;
  line-height: 1.45;
  text-align: left;
  padding: 7px 10px;
  border-radius: 8px;
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.22);
  white-space: normal;
  pointer-events: none;
}
.info-hint__bubble--top {
  bottom: calc(100% + 6px);
}
.info-hint__bubble--bottom {
  top: calc(100% + 6px);
}
.info-hint-fade-enter-active,
.info-hint-fade-leave-active {
  transition: opacity 120ms ease;
}
.info-hint-fade-enter-from,
.info-hint-fade-leave-to {
  opacity: 0;
}
</style>
