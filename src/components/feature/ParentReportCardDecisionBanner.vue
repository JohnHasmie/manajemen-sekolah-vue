<!--
  ParentReportCardDecisionBanner.vue — hero banner for the single most
  emotionally loaded moment in the parent app: the promotion decision.

  Ports mobile's parent_report_card_decision_banner.dart shape so both
  platforms feel the same: a circular icon in a white ring, an
  uppercase "KEPUTUSAN KENAIKAN" kicker, and a big, unambiguous label.
  Colour-coded: green (Naik / Lulus), red (Tinggal / Tidak Lulus),
  amber (belum diumumkan).

  Meant to sit AT THE TOP of ParentReportCardDetailView — the parent
  scrolled here to answer one question, so answer it before the KPIs.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import type { PromotionDecision } from '@/types/report-card';

const props = defineProps<{
  /** Canonical decision from ReportCardService. `null`/undef → pending. */
  decision?: PromotionDecision | string | null;
  /**
   * `true` when the parent is looking at Semester Ganjil (Semester 1)
   * — promotion decisions are only issued at end-of-year, so we render
   * a warm "akan diumumkan setelah semester genap" pending state.
   */
  isOddSemester?: boolean;
}>();

const { t } = useI18n();

type Tone = 'success' | 'danger' | 'pending';

interface Variant {
  tone: Tone;
  label: string;
  icon: string;
}

const variant = computed<Variant>(() => {
  // Odd semester overrides: decisions don't exist yet, don't imply pass/fail.
  if (props.isOddSemester) {
    return { tone: 'pending', label: t('parent.reportCard.decisionOddSemester'), icon: 'clock' };
  }
  const d = String(props.decision ?? '').toLowerCase().trim();
  if (!d) return { tone: 'pending', label: t('parent.reportCard.decisionPending'), icon: 'clock' };
  if (d === 'promoted' || d.includes('naik kelas')) {
    return { tone: 'success', label: t('parent.reportCard.decisionPromoted'), icon: 'check' };
  }
  if (d === 'not_promoted' || d.includes('tinggal') || d.includes('tidak naik')) {
    return { tone: 'danger', label: t('parent.reportCard.decisionNotPromoted'), icon: 'x' };
  }
  if (d === 'graduated' || d === 'lulus') {
    return { tone: 'success', label: t('parent.reportCard.decisionGraduated'), icon: 'check' };
  }
  if (d === 'not_graduated' || d.includes('tidak lulus')) {
    return { tone: 'danger', label: t('parent.reportCard.decisionNotGraduated'), icon: 'x' };
  }
  // Anything else — show the raw string but keep pending styling so we
  // don't paint an unknown decision green or red.
  return { tone: 'pending', label: String(props.decision), icon: 'clock' };
});

// Ring + text tones. Kept as static maps so purge-safe class names land in
// the emitted CSS; Tailwind's JIT wouldn't scan a dynamic template literal.
const CHROME: Record<Tone, {
  bg: string; border: string; ring: string; icon: string; kicker: string; label: string;
}> = {
  success: {
    bg: 'bg-emerald-50', border: 'border-emerald-200', ring: 'border-emerald-600',
    icon: 'text-emerald-700', kicker: 'text-emerald-700', label: 'text-emerald-900',
  },
  danger: {
    bg: 'bg-red-50', border: 'border-red-200', ring: 'border-red-600',
    icon: 'text-red-700', kicker: 'text-red-700', label: 'text-red-900',
  },
  pending: {
    bg: 'bg-amber-50', border: 'border-amber-200', ring: 'border-amber-500',
    icon: 'text-amber-700', kicker: 'text-amber-700', label: 'text-amber-900',
  },
};
const chrome = computed(() => CHROME[variant.value.tone]);
</script>

<template>
  <section
    class="rounded-2xl border p-4 flex items-center gap-3"
    :class="[chrome.bg, chrome.border]"
    role="status"
  >
    <span
      class="w-9 h-9 rounded-full bg-white flex items-center justify-center border-2 flex-shrink-0"
      :class="chrome.ring"
      aria-hidden="true"
    >
      <!-- check -->
      <svg
        v-if="variant.icon === 'check'"
        xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"
        class="w-5 h-5" :class="chrome.icon"
      >
        <path d="M20 6 9 17l-5-5" />
      </svg>
      <!-- x -->
      <svg
        v-else-if="variant.icon === 'x'"
        xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"
        class="w-5 h-5" :class="chrome.icon"
      >
        <path d="M18 6 6 18M6 6l12 12" />
      </svg>
      <!-- clock (pending) -->
      <svg
        v-else
        xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
        stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
        class="w-5 h-5" :class="chrome.icon"
      >
        <circle cx="12" cy="12" r="9" />
        <path d="M12 7v5l3 2" />
      </svg>
    </span>
    <div class="flex-1 min-w-0">
      <p class="text-3xs font-bold uppercase tracking-widest" :class="chrome.kicker">
        {{ t('parent.reportCard.decisionKicker') }}
      </p>
      <p class="mt-1 text-[15px] font-black leading-tight" :class="chrome.label">
        {{ variant.label }}
      </p>
    </div>
  </section>
</template>
