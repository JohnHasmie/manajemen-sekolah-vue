<!--
  ConfirmationDialog.vue — port of Flutter's ConfirmationDialog.
  Used for destructive actions (Hapus, Arsipkan).
-->
<script setup lang="ts">
import Modal from './Modal.vue';
import BottomSheetFooter from './BottomSheetFooter.vue';

withDefaults(
  defineProps<{
    title: string;
    message: string;
    confirmLabel?: string;
    cancelLabel?: string;
    danger?: boolean;
    loading?: boolean;
    /**
     * Cascade consequences to warn the admin about. Each item is one
     * concrete thing that will happen when the action fires — kept
     * short (≤80 chars) so the list stays scannable. Rendered only
     * on destructive actions where the caller opted in.
     */
    impact?: string[];
  }>(),
  {
    confirmLabel: 'Konfirmasi',
    cancelLabel: 'Batal',
    danger: false,
    loading: false,
    impact: () => [],
  },
);

defineEmits<{ confirm: []; close: [] }>();
</script>

<template>
  <Modal :title="title" @close="$emit('close')">
    <p class="text-sm text-slate-600 leading-relaxed">{{ message }}</p>
    <!-- IMPACT CARD — bulleted preview of cascade side effects. Only
         rendered when the caller passes at least one line, so simple
         confirms stay clean. The tone is warm-warning (amber for
         non-danger, red for danger) so a busy admin sees the "what
         will actually happen" list before hitting Konfirmasi. -->
    <div
      v-if="impact.length > 0"
      class="mt-md rounded-xl border p-3"
      :class="danger
        ? 'bg-red-50 border-red-200'
        : 'bg-amber-50 border-amber-200'"
      role="alert"
    >
      <p
        class="text-3xs font-black uppercase tracking-widest mb-1.5"
        :class="danger ? 'text-red-700' : 'text-amber-700'"
      >
        Yang akan terjadi
      </p>
      <ul class="space-y-1">
        <li
          v-for="(line, idx) in impact"
          :key="idx"
          class="flex items-start gap-2 text-xs leading-relaxed"
          :class="danger ? 'text-red-900' : 'text-amber-900'"
        >
          <span
            class="mt-1.5 w-1 h-1 rounded-full flex-shrink-0"
            :class="danger ? 'bg-red-500' : 'bg-amber-500'"
            aria-hidden="true"
          />
          <span>{{ line }}</span>
        </li>
      </ul>
    </div>
    <BottomSheetFooter
      :primary-label="confirmLabel"
      :secondary-label="cancelLabel"
      :primary-loading="loading"
      :danger="danger"
      @primary="$emit('confirm')"
      @secondary="$emit('close')"
    />
  </Modal>
</template>
