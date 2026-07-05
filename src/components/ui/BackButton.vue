<!--
  BackButton — the chevron + label back-navigation control repeated
  verbatim across detail views (report-card detail, finance types,
  lesson-plan detail, …). Pass `to` to navigate a route, or omit it and
  listen for `@click` to run custom logic (e.g. close a sub-view).
-->
<script setup lang="ts">
import { useRouter, type RouteLocationRaw } from 'vue-router';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** Route to navigate to. When omitted, the component emits `click`. */
  to?: RouteLocationRaw;
  /** Label text; defaults to "Kembali". */
  label?: string;
}>();

const emit = defineEmits<{ (e: 'click'): void }>();
const router = useRouter();

function onClick(): void {
  if (props.to !== undefined) router.push(props.to);
  else emit('click');
}
</script>

<template>
  <button
    type="button"
    class="inline-flex items-center gap-1.5 text-xs font-bold text-slate-600 hover:text-slate-900 transition-colors"
    @click="onClick"
  >
    <NavIcon name="chevron-left" :size="14" />
    {{ label ?? 'Kembali' }}
  </button>
</template>
