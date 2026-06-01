<!--
  InitialsAvatar.vue — square-rounded avatar with initial(s).
  Port of `lib/core/widgets/initials_avatar.dart`.

  Sizes & border-radius match the Flutter widget defaults (44px / 12px
  radius from StudentCard usage).
-->
<script setup lang="ts">
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    name: string;
    size?: number;
    color?: string;
    borderRadius?: number;
    imageUrl?: string | null;
  }>(),
  { size: 44, color: '#1E3A8A', borderRadius: 12, imageUrl: null },
);

const initials = computed(() => {
  const trimmed = props.name.trim();
  if (!trimmed) return '?';
  const parts = trimmed.split(/\s+/);
  const first = parts[0]?.[0] ?? '';
  const second = parts[1]?.[0] ?? '';
  return (first + second).toUpperCase();
});

const fontSize = computed(() => Math.round(props.size * 0.36));
</script>

<template>
  <span
    class="inline-flex items-center justify-center font-bold text-white flex-shrink-0 overflow-hidden"
    :style="{
      width: `${size}px`,
      height: `${size}px`,
      borderRadius: `${borderRadius}px`,
      backgroundColor: color,
      fontSize: `${fontSize}px`,
    }"
  >
    <img
      v-if="imageUrl"
      :src="imageUrl"
      :alt="name"
      class="w-full h-full object-cover"
    />
    <span v-else>{{ initials }}</span>
  </span>
</template>
