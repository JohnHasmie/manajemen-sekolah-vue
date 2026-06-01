/**
 * Convenience composable to get just the role hex color string for
 * components that need raw colors (gradients, FAB tint, SVG fills).
 */
import { computed, type ComputedRef } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { getRoleColor } from '@/composables/useRoleColor';

export function useRoleHex(): ComputedRef<string> {
  const auth = useAuthStore();
  return computed(() => getRoleColor(auth.activeRole).hex);
}
