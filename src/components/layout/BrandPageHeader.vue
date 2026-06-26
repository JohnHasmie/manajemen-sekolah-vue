<!--
  BrandPageHeader.vue — gradient page header strip with role-tinted
  background, kicker, h1 title, meta line, optional action cluster,
  and optional RoleToggleChipRow.

  Mirrors Flutter's `BrandPageHeader` (lib/core/widgets/
  brand_page_header.dart). The host pages drop one of these at the
  top of their template instead of writing a bespoke header.

  Props:
    - role       — 'admin' | 'teacher' | 'wali_kelas' | 'parent' | 'staff'
                   Drives the gradient tint. Defaults to the active
                   role from the auth store.
    - kicker     — small uppercase eyebrow text above the title.
    - title      — h1.
    - meta       — paragraph below the title, role-soft text.
    - liveDot    — when true, prepends a green pulse dot to the kicker.

  Slots:
    - default      — right-side action cluster (filter buttons,
                     view-toggle, etc.). Stays inline with the title.
    - role-toggle  — `<RoleToggleChipRow>` placed under the title row.
                     Optional; only rendered when supplied.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { getRoleColor } from '@/composables/useRoleColor';
import type { Role } from '@/types/auth';

const props = withDefaults(
  defineProps<{
    role?: Role;
    kicker?: string;
    title: string;
    meta?: string;
    liveDot?: boolean;
  }>(),
  {
    liveDot: false,
  },
);

const auth = useAuthStore();

const activeRole = computed<Role | null>(
  () => props.role ?? (auth.activeRole as Role | null),
);

const palette = computed(() => {
  const base = getRoleColor(activeRole.value);
  // Dark-blue companion derived per role — used as the gradient
  // start. Mirrors Flutter's brand-dark-blue × role-color mix.
  let darkStop: string;
  switch (activeRole.value) {
    case 'admin':
      darkStop = '#0A1F4D';
      break;
    case 'wali':
      darkStop = '#0B5677';
      break;
    case 'staff':
      darkStop = '#5E2D04';
      break;
    case 'guru':
    case 'wali_kelas':
    default:
      darkStop = '#0F2A45';
  }
  return { hex: base.hex, dark: darkStop };
});

const gradientStyle = computed(() => ({
  background: `linear-gradient(120deg, ${palette.value.dark} 0%, ${palette.value.hex} 60%, ${palette.value.hex} 100%)`,
  boxShadow: `0 10px 28px ${palette.value.hex}26`,
}));
</script>

<template>
  <header
    class="rounded-2xl text-white p-4 sm:p-5"
    :style="gradientStyle"
  >
    <div class="flex items-start justify-between gap-4 flex-wrap">
      <div class="min-w-0">
        <p
          v-if="kicker"
          class="text-[10.5px] font-bold text-white/85 uppercase tracking-widest m-0 flex items-center"
        >
          <span
            v-if="liveDot"
            class="inline-block w-1.5 h-1.5 rounded-full bg-emerald-400 mr-1.5"
          ></span>
          {{ kicker }}
        </p>
        <h1
          class="text-xl sm:text-2xl font-black text-white tracking-tight mt-1 leading-tight"
        >
          {{ title }}
        </h1>
        <p v-if="meta" class="text-[12px] text-white/85 mt-1">
          {{ meta }}
        </p>
      </div>
      <div class="flex items-center gap-2 flex-shrink-0">
        <slot />
      </div>
    </div>

    <!-- Optional role-toggle row sitting inside the gradient -->
    <div
      v-if="$slots['role-toggle']"
      class="mt-3"
    >
      <slot name="role-toggle" />
    </div>
  </header>
</template>
