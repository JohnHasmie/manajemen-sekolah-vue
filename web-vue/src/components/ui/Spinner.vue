<!--
  Spinner.vue — inline loading indicator. Web equivalent of Flutter's
  CircularProgressIndicator. Uses currentColor so it inherits the
  parent's text color (useful inside buttons + cards).
-->
<script setup lang="ts">
defineProps<{
  size?: 'sm' | 'md' | 'lg';
}>();
</script>

<template>
  <svg
    class="animate-spin"
    :class="{
      'w-4 h-4': size === 'sm' || !size,
      'w-6 h-6': size === 'md',
      'w-10 h-10': size === 'lg',
    }"
    viewBox="0 0 24 24"
    fill="none"
    aria-hidden="true"
  >
    <circle
      cx="12"
      cy="12"
      r="10"
      stroke="currentColor"
      stroke-width="3"
      stroke-opacity="0.25"
    />
    <path
      d="M22 12a10 10 0 0 1-10 10"
      stroke="currentColor"
      stroke-width="3"
      stroke-linecap="round"
    />
  </svg>
</template>
