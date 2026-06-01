<script setup lang="ts">
import { onMounted } from 'vue';
import { useAuthStore } from '@/stores/auth';

const auth = useAuthStore();

// Rehydrate token / user from localStorage (persisted by Pinia plugin)
// and verify it's still valid on app boot. Mirrors Flutter's startup check
// in main.dart → TokenService.isLoggedIn().
onMounted(() => {
  auth.restore();
});
</script>

<template>
  <RouterView />
</template>
