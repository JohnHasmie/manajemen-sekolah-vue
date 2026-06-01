<!--
  DEPRECATED — replaced by TeacherReportCardHubView.vue.

  Kept as a thin shim so any stale imports / bookmarks don't 404 during
  the transition. The active route `/teacher/report-cards` resolves to
  the Hub view, not this file. Remove this file in a future cleanup
  commit once nothing references it.
-->
<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';

const router = useRouter();
onMounted(() => {
  router.replace({ name: 'teacher.report-cards' });
});
</script>

<template>
  <div class="p-8 text-center text-slate-500 text-sm">
    Memuat ulang ke halaman Rapor…
  </div>
</template>
