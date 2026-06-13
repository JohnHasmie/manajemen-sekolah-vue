<!--
  ParentTabBar — 3-tab segmented toggle styled in the parent (azure)
  palette. Used on Kelas detail page (Aliran / Sesi / Nilai), Sesi
  page (List / Kalender), Tagihan page (Aktif / Riwayat).
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
    class="flex gap-1 rounded-xl border border-bimbel-border-soft bg-bimbel-panel p-1"
    :class="fit ? 'inline-flex' : 'w-full'"
  >
    <button
      v-for="t in tabs"
      :key="t.id"
      type="button"
      class="flex-1 rounded-lg px-3 py-1.5 text-[12px] font-bold tracking-tight transition"
      :class="
        modelValue === t.id
          ? 'bg-[#21afe6] text-white shadow'
          : 'text-bimbel-text-mid hover:text-bimbel-text-hi'
      "
      @click="$emit('update:modelValue', t.id)"
    >
      {{ t.label }}
    </button>
  </div>
</template>
