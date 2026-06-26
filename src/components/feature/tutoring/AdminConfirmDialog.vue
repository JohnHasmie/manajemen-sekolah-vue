<!--
  AdminConfirmDialog — minimal centered confirmation modal for
  destructive actions. Uses bimbel-* tokens so it follows light/dark.
-->
<script setup lang="ts">
defineProps<{
  open: boolean;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  danger?: boolean;
  busy?: boolean;
}>();
const emit = defineEmits<{ (e: 'cancel'): void; (e: 'confirm'): void }>();
</script>

<template>
  <div
    v-if="open"
    class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6"
    @click.self="emit('cancel')"
  >
    <div class="w-full max-w-md rounded-2xl bg-tutoring-panel p-5 shadow-xl">
      <h3 class="text-[16px] font-bold text-tutoring-text-hi">{{ title }}</h3>
      <p class="mt-1 text-[13px] text-tutoring-text-mid whitespace-pre-wrap">{{ message }}</p>
      <div class="mt-4 flex gap-2">
        <button
          type="button"
          class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[13px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft"
          @click="emit('cancel')"
        >{{ cancelLabel ?? 'Batal' }}</button>
        <button
          type="button"
          :disabled="busy"
          class="flex-1 rounded-lg px-3 py-2 text-[13px] font-bold text-white disabled:opacity-50"
          :class="danger ? 'bg-rose-600 hover:bg-rose-700' : 'bg-tutoring-accent hover:opacity-90'"
          @click="emit('confirm')"
        >{{ busy ? 'Memproses…' : (confirmLabel ?? 'Konfirmasi') }}</button>
      </div>
    </div>
  </div>
</template>
