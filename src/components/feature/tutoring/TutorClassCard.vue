<!--
  TutorClassCard — the bimbel "kelas" card. Now a thin wrapper over the shared
  ClassHeroCard so the gradient-hero markup + palette live in ONE place; this
  keeps the tutoring call sites (TutorClassesView, TutorTutoringHomeView,
  ParentClassCard) unchanged while the Kelas hub reuses the same card with a
  subject-colour gradient.
-->
<script setup lang="ts">
import ClassHeroCard from '@/components/feature/ClassHeroCard.vue';

defineProps<{
  /** Stable id (or any string) — used to pick gradient color. */
  identityKey: string;
  /** Display name (Kelas IPA Pagi, etc.) */
  name: string;
  /** Optional program/subject line. */
  program?: string | null;
  /** Optional small meta — capacity / enrollment count. */
  meta?: string | null;
}>();

const emit = defineEmits<{ (e: 'click'): void }>();
</script>

<template>
  <ClassHeroCard
    :identity-key="identityKey"
    :name="name"
    :eyebrow="program"
    :meta="meta"
    @click="emit('click')"
  />
</template>
