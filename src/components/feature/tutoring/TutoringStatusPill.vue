<!--
  TutoringStatusPill — small uppercase pill for session/bill statuses,
  Realtime indicator, BIMBEL tenant tag. Mirrors Flutter
  `TutoringStatusPill`. Pass either a `tone` directly or one of the
  semantic shorthands (`session`/`bill`).
-->
<script setup lang="ts">
import { computed } from 'vue';

type Tone = 'ok' | 'warn' | 'danger' | 'info' | 'neutral' | 'tenant';

const props = withDefaults(
  defineProps<{
    label?: string;
    tone?: Tone;
    /** Session status enum value (SCHEDULED/DONE/CANCELLED). */
    session?: string;
    /** Bill status value (paid/pending/unpaid). */
    bill?: string;
    /** Show a tiny dot (used by the "Realtime" indicator). */
    dot?: boolean;
  }>(),
  { tone: 'neutral' },
);

const resolved = computed<{ label: string; tone: Tone }>(() => {
  if (props.session) {
    const s = props.session.toUpperCase();
    return {
      label:
        s === 'DONE'
          ? 'Selesai'
          : s === 'CANCELLED'
            ? 'Batal'
            : 'Terjadwal',
      tone: s === 'DONE' ? 'ok' : s === 'CANCELLED' ? 'danger' : 'info',
    };
  }
  if (props.bill) {
    const s = props.bill.toLowerCase();
    return {
      label:
        s === 'paid'
          ? 'Lunas'
          : s === 'pending'
            ? 'Menunggu'
            : 'Belum Bayar',
      tone: s === 'paid' ? 'ok' : s === 'pending' ? 'warn' : 'danger',
    };
  }
  return { label: props.label ?? '', tone: props.tone };
});
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 rounded-md px-2 py-0.5 text-[10.5px] font-bold uppercase tracking-wide"
    :class="{
      'bg-status-success-soft text-status-success': resolved.tone === 'ok',
      'bg-status-warning-soft text-status-warning': resolved.tone === 'warn',
      'bg-status-danger-soft text-status-danger': resolved.tone === 'danger',
      'bg-status-info-soft text-status-info': resolved.tone === 'info',
      'bg-slate-100 text-slate-700': resolved.tone === 'neutral',
      'bg-brand-50 text-brand-700': resolved.tone === 'tenant',
    }"
  >
    <span
      v-if="dot"
      class="w-1.5 h-1.5 rounded-full bg-current animate-pulse"
    />
    {{ resolved.label }}
  </span>
</template>
