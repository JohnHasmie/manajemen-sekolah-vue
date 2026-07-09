<!--
  DashboardHero.vue — premium gradient header for the main dashboard landing.
  Mirrors Flutter's `DashboardGreeting` / `BrandHero`.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { canonicalRole, ROLE_ADMIN, ROLE_TEACHER } from '@/utils/role';
import InitialsAvatar from './InitialsAvatar.vue';
import NavIcon from './NavIcon.vue';

const props = defineProps<{
  role: 'admin' | 'guru' | 'wali';
  schoolName: string;
  subtitle?: string;
  lastSync?: Date;
  isFresh?: boolean;
}>();

const auth = useAuthStore();

const greetingText = computed(() => {
  const hour = new Date().getHours();
  if (hour < 11) return 'Selamat Pagi';
  if (hour < 15) return 'Selamat Siang';
  if (hour < 18) return 'Selamat Sore';
  return 'Selamat Malam';
});

const theme = computed(() => {
  const cr = canonicalRole(props.role);
  // Teacher: Dark Blue -> Azure (Phase 3 Teal Gradient)
  if (cr === ROLE_TEACHER) return 'from-brand-dark-blue to-brand-azure';
  // Admin: Dark Blue -> Cobalt
  if (cr === ROLE_ADMIN) return 'from-brand-dark-blue to-brand-cobalt';
  // Parent: Azure -> Light Azure
  return 'from-brand-azure to-brand-azure/80';
});

const formatTime = (date: Date) => {
  return date.toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
};
</script>

<template>
  <div
    class="relative overflow-hidden rounded-[2rem] p-6 sm:p-8 text-white shadow-2xl shadow-brand-cobalt/15 mb-16 bg-gradient-to-br"
    :class="theme"
    style="
      background-image: linear-gradient(
        135deg,
        var(--tw-gradient-from) 0%,
        var(--tw-gradient-to) 100%
      );
    "
  >
    <!-- Decorative circles -->
    <div
      class="absolute -top-12 -right-12 w-64 h-64 rounded-full bg-white/10 blur-3xl"
    ></div>
    <div
      class="absolute -bottom-16 -left-16 w-48 h-48 rounded-full bg-black/10 blur-3xl"
    ></div>

    <div class="relative space-y-6">
      <!-- Top Row: Greeting & Actions -->
      <div class="flex items-start justify-between gap-4">
        <div class="space-y-1">
          <p class="text-[13px] font-medium text-white/70 tracking-wide">
            {{ greetingText }}
          </p>
          <h1
            class="text-2xl sm:text-3xl font-black tracking-tight leading-tight"
          >
            {{ auth.user?.name }}
          </h1>
        </div>

        <div class="hidden sm:flex items-center gap-3">
          <button
            class="w-10 h-10 rounded-full bg-white/15 hover:bg-white/20 border border-white/10 grid place-items-center transition-colors"
          >
            <NavIcon name="bell" :size="20" />
          </button>
          <button
            class="w-10 h-10 rounded-full bg-white/15 hover:bg-white/20 border border-white/10 grid place-items-center transition-colors"
          >
            <NavIcon name="settings" :size="20" />
          </button>
        </div>
      </div>

      <!-- Realtime Indicator -->
      <div class="flex items-center gap-2">
        <div
          class="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-black/20 backdrop-blur-sm border border-white/10"
        >
          <div
            class="w-1.5 h-1.5 rounded-full"
            :class="isFresh ? 'bg-emerald-400 animate-pulse' : 'bg-amber-400'"
          ></div>
          <span
            class="text-3xs font-bold uppercase tracking-wider text-white/90"
          >
            {{ isFresh ? 'Realtime' : 'Offline' }}
          </span>
        </div>
        <span v-if="lastSync" class="text-3xs font-medium text-white/60">
          Sinkronisasi terakhir: {{ formatTime(lastSync) }}
        </span>
      </div>

      <!-- School Pill -->
      <div
        class="group flex items-center justify-between gap-4 p-4 rounded-2xl bg-white/10 backdrop-blur-md border border-white/20 hover:bg-white/15 cursor-pointer transition-all"
        @click="$emit('switchSchool')"
      >
        <div class="flex items-center gap-3">
          <div
            class="w-10 h-10 rounded-xl bg-white text-brand-cobalt grid place-items-center shadow-inner"
          >
            <NavIcon name="home" :size="20" />
          </div>
          <div>
            <p
              class="text-2xs font-black text-white/60 uppercase tracking-widest"
            >
              Sekolah Aktif
            </p>
            <p class="text-[15px] font-bold text-white leading-none mt-0.5">
              {{ schoolName }}
            </p>
            <p v-if="subtitle" class="text-2xs font-medium text-white/50 mt-1">
              {{ subtitle }}
            </p>
          </div>
        </div>
        <div
          class="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/15 text-2xs font-black uppercase tracking-wider group-hover:bg-white/25 transition-colors"
        >
          Ganti
          <NavIcon name="layers" :size="12" />
        </div>
      </div>
    </div>
  </div>
</template>
