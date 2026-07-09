<!--
  Parent per-class hub (web) — a thin, read-only wrapper over the shared
  ClassHubView, scoped to the active child (from useChildPicker). Same 4-tab
  layout (Riwayat Sesi / Tugas / Anggota / Nilai) in the parent azure theme.
-->
<script setup lang="ts">
import { useChildPicker } from '@/composables/useChildPicker';
import ClassHubView from '@/views/teacher/ClassHubView.vue';

defineProps<{ id: string }>();
const { activeChildId } = useChildPicker();
</script>

<template>
  <ClassHubView
    v-if="activeChildId"
    :id="id"
    role-name="wali"
    :student-id="activeChildId"
  />
</template>
