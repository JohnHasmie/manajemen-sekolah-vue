<!--
  SubscriptionUsageBanner — cross-page usage indicator.

  Renders zero UI when the tenant is comfortably under its paid quota
  (zone === 'normal'). In grace / overage / hard zones it surfaces a
  contextual banner + a top-up CTA that navigates to /subscribe/addon.

  Consumed by AdminStudentManagementView, AdminTeacherManagementView,
  and AdminStaffManagementView. Reads from GET /billing/seat-usage;
  refetches on mount + when the parent explicitly re-triggers via
  `refreshKey` prop.

  Two dimensions displayed (student + staff) share the same banner
  frame — whichever zone is more severe wins the tone. Copy is
  translated using the current i18n locale.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { SubscriptionBillingService } from '@/services/billing.service';
import type { SeatUsage, SeatZone } from '@/types/subscription-billing';

const props = defineProps<{
  /** Bump this from the parent to force a fresh usage fetch. */
  refreshKey?: number;
  /**
   * Scope the banner to a single seat dimension so it only surfaces on the
   * page that owns it: `student` on Data Siswa, `staff` on Data Guru + Data
   * Staf. When omitted, falls back to the legacy combined behavior (most
   * severe of the two zones, both numbers in the copy).
   */
  dimension?: 'student' | 'staff';
}>();

const { t } = useI18n();
const router = useRouter();
const usage = ref<SeatUsage | null>(null);
const loading = ref(false);

async function fetchUsage() {
  loading.value = true;
  try {
    usage.value = await SubscriptionBillingService.getSeatUsage();
  } finally {
    loading.value = false;
  }
}

onMounted(fetchUsage);
watch(
  () => props.refreshKey,
  () => fetchUsage(),
);

// Pick the more severe of the two zones so the banner tone matches
// the strongest signal — e.g. student in grace + staff in overage
// renders as overage.
const ZONE_WEIGHT: Record<SeatZone, number> = {
  normal: 0,
  grace: 1,
  overage: 2,
  hard: 3,
};

const effectiveZone = computed<SeatZone>(() => {
  const u = usage.value;
  if (!u) return 'normal';
  // Scoped to one dimension → use only that dimension's zone.
  if (props.dimension === 'student') return u.zone_student;
  if (props.dimension === 'staff') return u.zone_staff;
  // Legacy combined → most severe of the two.
  return ZONE_WEIGHT[u.zone_student] >= ZONE_WEIGHT[u.zone_staff]
    ? u.zone_student
    : u.zone_staff;
});

const dimNoun = computed(() =>
  props.dimension === 'student'
    ? t('subscribe.usageBanner.nounStudent')
    : t('subscribe.usageBanner.nounStaff'),
);

const shouldRender = computed(() => {
  const u = usage.value;
  if (!u) return false;
  return effectiveZone.value !== 'normal';
});

const overSummary = computed(() => {
  const u = usage.value;
  if (!u) return '';
  if (props.dimension === 'student') {
    return u.over_student > 0 ? `${u.over_student} ${dimNoun.value}` : '';
  }
  if (props.dimension === 'staff') {
    return u.over_staff > 0 ? `${u.over_staff} ${dimNoun.value}` : '';
  }
  const parts: string[] = [];
  if (u.over_student > 0) parts.push(`${u.over_student} siswa`);
  if (u.over_staff > 0) parts.push(`${u.over_staff} guru/staf`);
  return parts.join(' + ');
});

const bannerCopy = computed(() => {
  const u = usage.value;
  if (!u) return { title: '', body: '' };
  const zone = effectiveZone.value;

  // Single-dimension copy — only this page's seat type, no "dan N guru/staf".
  if (props.dimension) {
    const live = props.dimension === 'student' ? u.live_student : u.live_staff;
    const paid = props.dimension === 'student' ? u.paid_student : u.paid_staff;
    const hard = props.dimension === 'student' ? u.hard_student : u.hard_staff;
    const over = props.dimension === 'student' ? u.over_student : u.over_staff;
    if (zone === 'grace') {
      return {
        title: t('subscribe.usageBanner.graceTitle'),
        body: t('subscribe.usageBanner.graceBodyOne', { live, paid, noun: dimNoun.value }),
      };
    }
    if (zone === 'overage') {
      return {
        title: t('subscribe.usageBanner.overageTitle'),
        body: t('subscribe.usageBanner.overageBodyOne', { over, noun: dimNoun.value }),
      };
    }
    return {
      title: t('subscribe.usageBanner.hardTitle'),
      body: t('subscribe.usageBanner.hardBodyOne', { hard, noun: dimNoun.value }),
    };
  }

  if (zone === 'grace') {
    return {
      title: t('subscribe.usageBanner.graceTitle'),
      body: t('subscribe.usageBanner.graceBody', {
        live_student: u.live_student,
        paid_student: u.paid_student,
        live_staff: u.live_staff,
        paid_staff: u.paid_staff,
      }),
    };
  }
  if (zone === 'overage') {
    return {
      title: t('subscribe.usageBanner.overageTitle'),
      body: t('subscribe.usageBanner.overageBody', {
        over_summary: overSummary.value,
      }),
    };
  }
  // hard
  return {
    title: t('subscribe.usageBanner.hardTitle'),
    body: t('subscribe.usageBanner.hardBody', {
      hard_student: u.hard_student,
      hard_staff: u.hard_staff,
    }),
  };
});

const canTopUp = computed(() => {
  const u = usage.value;
  return !!u && !u.is_demo && !!u.subscription_id;
});

function openTopUp() {
  const u = usage.value;
  if (!u?.subscription_id) return;
  router.push({
    path: '/subscribe/addon',
    query: { subscription_id: u.subscription_id },
  });
}
</script>

<template>
  <div v-if="shouldRender && usage" class="mb-4">
    <div
      class="rounded-lg border px-4 py-3 flex items-start gap-3"
      :class="{
        'bg-amber-50 border-amber-200': effectiveZone === 'grace',
        'bg-amber-100/70 border-amber-300': effectiveZone === 'overage',
        'bg-rose-50 border-rose-300': effectiveZone === 'hard',
      }"
    >
      <div
        class="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0"
        :class="{
          'bg-amber-100 text-amber-700': effectiveZone !== 'hard',
          'bg-rose-100 text-rose-700': effectiveZone === 'hard',
        }"
      >
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
          <path v-if="effectiveZone === 'hard'" d="M12 2v10M12 18h.01M4.93 4.93l14.14 14.14M2 12a10 10 0 1020 0 10 10 0 00-20 0z" />
          <path v-else d="M12 9v4M12 17h.01M4.5 20h15a1.5 1.5 0 001.3-2.24l-7.5-13a1.5 1.5 0 00-2.6 0l-7.5 13A1.5 1.5 0 004.5 20z" />
        </svg>
      </div>
      <div class="flex-1 min-w-0">
        <p
          class="text-[13px] font-semibold"
          :class="{
            'text-amber-900': effectiveZone !== 'hard',
            'text-rose-900': effectiveZone === 'hard',
          }"
        >
          {{ bannerCopy.title }}
        </p>
        <p
          class="mt-0.5 text-[12px] leading-relaxed"
          :class="{
            'text-amber-800': effectiveZone !== 'hard',
            'text-rose-800': effectiveZone === 'hard',
          }"
        >
          {{ bannerCopy.body }}
        </p>
        <div v-if="canTopUp" class="mt-2 flex gap-2">
          <button
            type="button"
            class="inline-flex items-center justify-center rounded-md px-3 py-1.5 text-[12px] font-semibold text-white transition-colors"
            :class="{
              'bg-amber-600 hover:bg-amber-700': effectiveZone !== 'hard',
              'bg-rose-600 hover:bg-rose-700': effectiveZone === 'hard',
            }"
            @click="openTopUp"
          >
            {{ t('subscribe.usageBanner.topUpCta') }}
          </button>
        </div>
        <p v-else-if="usage.is_demo" class="mt-2 text-2xs text-amber-800">
          {{ t('subscribe.usageBanner.demoNotice') }}
        </p>
      </div>
    </div>
  </div>
</template>
