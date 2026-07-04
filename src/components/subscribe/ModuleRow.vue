<!--
  ModuleRow.vue — thin toggle-mode wrapper over `ModuleTile.vue` for
  the /subscribe conversion flow.

  Kept as a named component so existing call sites (SubscribeView,
  SubscribeNewWizardView, ModuleCatalogGrid) don't have to rewrite
  their template. All row visuals + CSS now live in `ModuleTile.vue`;
  this file only exists to preserve the shorter, use-site-friendly
  API (`<ModuleRow :item :selected @toggle>`).
-->
<script setup lang="ts">
import type { ModuleCatalogItem } from '@/types/subscription-billing';
import ModuleTile from './ModuleTile.vue';

defineProps<{
  item: ModuleCatalogItem;
  selected: boolean;
  tenantType?: 'sekolah' | 'bimbel' | null;
}>();

defineEmits<{ toggle: [] }>();
</script>

<template>
  <ModuleTile
    :item="item"
    :tenant-type="tenantType"
    mode="toggle"
    :selected="selected"
    @toggle="$emit('toggle')"
  />
</template>
