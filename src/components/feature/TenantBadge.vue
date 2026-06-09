<!--
  TenantBadge — a small pill labelling a tenant as a formal school or a
  tutoring center (bimbel). Rendered in the school/tenant picker and on
  tenant headers so a parent juggling a child's school AND bimbel can
  tell the two apart at a glance.

  Mirrors the Flutter `TenantBadge` widget. Parses the backend
  `tenant_type` ('SCHOOL' | 'TUTORING_CENTER'), defaulting to school.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { tenantKindFromRaw } from '@/composables/useTenant';

const props = defineProps<{
  /** Raw `tenant_type` value from a school/user payload. */
  type?: string | null;
}>();

const { t } = useI18n();
const kind = computed(() => tenantKindFromRaw(props.type));
const isBimbel = computed(() => kind.value === 'TUTORING_CENTER');
const label = computed(() =>
  t(isBimbel.value ? 'tutoring.tenant.center' : 'tutoring.tenant.school'),
);
</script>

<template>
  <span
    class="inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold"
    :class="
      isBimbel
        ? 'bg-amber-100 text-amber-800'
        : 'bg-indigo-100 text-indigo-800'
    "
  >
    <svg
      class="h-3 w-3"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
    >
      <path
        v-if="isBimbel"
        d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20M4 19.5A2.5 2.5 0 0 0 6.5 22H20V2H6.5A2.5 2.5 0 0 0 4 4.5v15z"
      />
      <path v-else d="M22 10v6M2 10l10-5 10 5-10 5z M6 12v5c3 3 9 3 12 0v-5" />
    </svg>
    {{ label }}
  </span>
</template>
