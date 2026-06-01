<!--
  LessonPlanStatusActionBar.vue — context-aware sticky CTA bar.

  Mirrors Flutter's `lesson_plan_status_action_bar.dart`. Emits an
  intent string so the parent screen decides what to actually do —
  the bar itself doesn't call services.

  Buttons per status:
    - Draft    → "Kirim untuk Review"     (primary)   intent='submit'
    - Pending  → "Sudah dikirim · menunggu admin"  (disabled)
    - Approved → "Lihat Riwayat"          (secondary) intent='history'
    - Rejected → "Lihat Catatan" (sec)    + "Edit Revisi" (primary)
                                                       intent='history' / 'edit'
    - SentBack → "Lihat Revisi" (sec)     + "Edit Revisi" (primary)
                                                       intent='history' / 'edit'
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { LessonPlanStatus } from '@/types/lesson-plans';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  status: LessonPlanStatus;
  /** Disable both buttons while the parent is mid-mutation. */
  busy?: boolean;
}>();

const emit = defineEmits<{
  submit: [];
  edit: [];
  history: [];
}>();

const layout = computed<
  | {
      kind: 'single' | 'duo';
      primary: { label: string; intent: 'submit' | 'edit' | 'history'; icon: string };
      secondary?: {
        label: string;
        intent: 'history' | 'edit';
        icon: string;
      };
      message?: string;
    }
  | { kind: 'message'; message: string }
>(() => {
  switch (props.status) {
    case 'Draft':
      return {
        kind: 'single',
        primary: { label: 'Kirim untuk Review', intent: 'submit', icon: 'send' },
      };
    case 'Pending':
      return {
        kind: 'message',
        message: 'Sudah dikirim · menunggu review admin',
      };
    case 'Approved':
      return {
        kind: 'single',
        primary: { label: 'Lihat Riwayat Review', intent: 'history', icon: 'list' },
      };
    case 'Rejected':
      return {
        kind: 'duo',
        secondary: { label: 'Lihat Catatan', intent: 'history', icon: 'list' },
        primary: { label: 'Edit & Kirim Ulang', intent: 'edit', icon: 'edit' },
      };
    case 'SentBack':
      return {
        kind: 'duo',
        secondary: { label: 'Lihat Revisi', intent: 'history', icon: 'list' },
        primary: { label: 'Edit Revisi', intent: 'edit', icon: 'edit' },
      };
    default:
      return { kind: 'message', message: '—' };
  }
});

function dispatch(intent: 'submit' | 'edit' | 'history') {
  if (intent === 'submit') emit('submit');
  else if (intent === 'edit') emit('edit');
  else emit('history');
}
</script>

<template>
  <div class="sticky bottom-0 z-30 bg-white/95 backdrop-blur border-t border-slate-200 px-4 py-3">
    <div v-if="layout.kind === 'message'" class="text-center text-[12px] text-slate-500 font-medium">
      {{ layout.message }}
    </div>
    <div v-else-if="layout.kind === 'single'" class="max-w-md mx-auto">
      <Button
        variant="primary"
        block
        :disabled="busy"
        @click="dispatch(layout.primary.intent)"
      >
        <NavIcon :name="layout.primary.icon" :size="14" />
        {{ layout.primary.label }}
      </Button>
    </div>
    <div v-else class="grid grid-cols-2 gap-2 max-w-md mx-auto">
      <Button
        variant="secondary"
        block
        :disabled="busy"
        @click="layout.secondary && dispatch(layout.secondary.intent)"
      >
        <NavIcon v-if="layout.secondary" :name="layout.secondary.icon" :size="14" />
        {{ layout.secondary?.label }}
      </Button>
      <Button
        variant="primary"
        block
        :disabled="busy"
        @click="dispatch(layout.primary.intent)"
      >
        <NavIcon :name="layout.primary.icon" :size="14" />
        {{ layout.primary.label }}
      </Button>
    </div>
  </div>
</template>
