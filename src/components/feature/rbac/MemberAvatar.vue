<script setup lang="ts">
/**
 * Stable per-user avatar — gradient circle keyed by a seed (user_id),
 * with initials fallback. Same palette as Flutter's MemberAvatar so
 * the same person looks identical on web + mobile.
 */
import { computed } from 'vue';

const props = withDefaults(
  defineProps<{
    seed: string;
    initials: string;
    photoUrl?: string | null;
    size?: number;
  }>(),
  { size: 44 },
);

const palettes = [
  ['#21AFE6', '#0E7CB5'],
  ['#7C5CFF', '#3A1E9C'],
  ['#1B6FB8', '#0B3D70'],
  ['#E89C2A', '#A2660D'],
  ['#16A34A', '#15803D'],
];

function hashCode(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h << 5) - h + s.charCodeAt(i);
  return Math.abs(h);
}

const colors = computed(() => palettes[hashCode(props.seed) % palettes.length]);

const style = computed(() => ({
  width: `${props.size}px`,
  height: `${props.size}px`,
  background: `linear-gradient(135deg, ${colors.value[0]} 0%, ${colors.value[1]} 100%)`,
  fontSize: `${Math.round(props.size * 0.32)}px`,
}));
</script>

<template>
  <span class="m-avatar" :style="style">
    <img v-if="photoUrl" :src="photoUrl" :alt="initials" />
    <template v-else>{{ initials }}</template>
  </span>
</template>

<style scoped>
.m-avatar {
  display: inline-grid;
  place-items: center;
  border-radius: 50%;
  color: #ffffff;
  font-weight: 800;
  overflow: hidden;
  flex-shrink: 0;
}
.m-avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
</style>
