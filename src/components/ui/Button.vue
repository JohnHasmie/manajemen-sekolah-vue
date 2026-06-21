<!--
  Button.vue — consistent button across the app.
  Variants:
    - primary   → brand-color filled
    - secondary → slate border / hover
    - ghost     → transparent
    - danger    → red filled (for destructive actions)
  Sizes: sm | md | lg
  States: loading, disabled, full-width
-->
<script setup lang="ts">
import Spinner from './Spinner.vue';
import { useAuthStore } from '@/stores/auth';
import { useRoleColor } from '@/composables/useRoleColor';

const auth = useAuthStore();
const roleColor = useRoleColor(() => auth.activeRole);

withDefaults(
  defineProps<{
    variant?: 'primary' | 'secondary' | 'ghost' | 'danger' | 'success';
    size?: 'sm' | 'md' | 'lg';
    type?: 'button' | 'submit' | 'reset';
    disabled?: boolean;
    loading?: boolean;
    block?: boolean;
  }>(),
  {
    variant: 'primary',
    size: 'md',
    type: 'button',
    disabled: false,
    loading: false,
    block: false,
  },
);

defineEmits<{ click: [MouseEvent] }>();
</script>

<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    class="inline-flex items-center justify-center gap-2 rounded-xl font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-offset-1 disabled:cursor-not-allowed"
    :class="[
      // size
      {
        'px-sm py-1 text-xs': size === 'sm',
        'px-md py-sm text-sm': size === 'md',
        'px-lg py-md text-base': size === 'lg',
      },
      // variant
      variant === 'primary' ? [roleColor.bg, 'text-white', 'hover:opacity-90', 'disabled:opacity-60', 'focus:ring-2', roleColor.ring] : '',
      {
        'border border-slate-300 text-slate-700 hover:bg-slate-50 disabled:opacity-60 focus:ring-slate-400':
          variant === 'secondary',
        'text-slate-600 hover:bg-slate-100 disabled:opacity-60':
          variant === 'ghost',
        'bg-status-danger text-white hover:opacity-90 disabled:opacity-60 focus:ring-status-danger':
          variant === 'danger',
        'bg-emerald-600 text-white hover:bg-emerald-700 disabled:opacity-60 focus:ring-emerald-500':
          variant === 'success',
      },
      // block
      { 'w-full': block },
    ]"
    @click="$emit('click', $event)"
  >
    <Spinner v-if="loading" size="sm" />
    <slot />
  </button>
</template>
