<!--
  TutoringTabBar — segmented toggle for the bimbel surface.

  Previously `feature/tutoring/ParentTabBar.vue`. Renamed + relocated to
  `feature/` in WEB-1 because the greenfield rebuild lands screens for
  admin, tutor, parent AND student on top of it — the "Parent" name
  encoded a stale scope (parent-only). Visual treatment is unchanged:
  the active tab still uses the azure fill (`#21afe6`) that the tutoring
  parent tier is built around, and it reads through the `bg-tutoring-*`
  tokens so the surface still theme-flips.

  Callers hit this via `@/components/feature/TutoringTabBar.vue`; the
  old path re-exports for backwards compatibility during the rebuild
  and will be removed in CLEAN-2.
-->
<script setup lang="ts">
defineProps<{
  modelValue: string;
  tabs: Array<{ id: string; label: string }>;
  /** Width modifier — full or fit-content. */
  fit?: boolean;
}>();

defineEmits<{ (e: 'update:modelValue', v: string): void }>();
</script>

<template>
  <div
    class="flex gap-1 rounded-xl border border-tutoring-border-soft bg-tutoring-panel p-1"
    :class="fit ? 'inline-flex' : 'w-full'"
  >
    <button
      v-for="t in tabs"
      :key="t.id"
      type="button"
      class="flex-1 rounded-lg px-3 py-1.5 text-[13px] font-bold tracking-tight transition"
      :class="
        modelValue === t.id
          ? 'bg-[#21afe6] text-white shadow'
          : 'text-tutoring-text-mid hover:text-tutoring-text-hi'
      "
      @click="$emit('update:modelValue', t.id)"
    >
      {{ t.label }}
    </button>
  </div>
</template>
