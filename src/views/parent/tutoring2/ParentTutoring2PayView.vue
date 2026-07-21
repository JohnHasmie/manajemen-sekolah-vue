<!--
  ParentTutoring2PayView.vue — Wali bimbel payment inbox (WEB-5).

  Multi-child bills view. Composition mirrors the exemplar: BrandPageHeader,
  KpiStripCards (4 slots), AsyncView-wrapped rounded surface with a row
  per bill. Each row surfaces child + description + amount + status pill
  and a "Bayar sekarang" CTA that stubs a toast until BE ships.

  MVP note: no /parent/bills endpoint yet — we derive bill rows from the
  parent's visible enrollments so the layout can be exercised end-to-end.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Button from '@/components/ui/Button.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const toast = useToast();

// TODO WEB-5+ swap to /tutoring2/parent/bills when the BE exposes it.
// Until then we synthesise nominal bill rows from the parent's visible
// enrollments so the layout has real data volume behind it.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({ per_page: 100 });
  return items;
});

const enrollments = computed<BimbelEnrollment[]>(() =>
  state.value.status === 'content' ? (state.value.data as BimbelEnrollment[]) : [],
);

const uniqueStudents = computed(() => {
  const ids = new Set<string>();
  for (const e of enrollments.value) ids.add(e.student_id);
  return [...ids];
});

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'cash',
    label: t('tutoring2.parent.pay.kpiOutstanding'),
    value: enrollments.value.length,
    tone: 'brand',
  },
  {
    icon: 'alert-triangle',
    label: t('tutoring2.parent.pay.kpiOverdue'),
    value: 0,
    tone: 'red',
  },
  {
    icon: 'check-circle',
    label: t('tutoring2.parent.pay.kpiPaidThisMonth'),
    value: 0,
    tone: 'green',
  },
  {
    icon: 'users',
    label: t('tutoring2.parent.pay.kpiTotalChildren'),
    value: uniqueStudents.value.length,
    tone: 'violet',
  },
]);

function shortId(id: string): string {
  return id.slice(0, 8);
}

// Nominal amount + status per row — real values come from BE later.
function billAmount(_e: BimbelEnrollment): number {
  return 750_000;
}
function billStatusLabel(): string {
  return t('tutoring2.status.unpaid');
}
function billStatusTone(): StatusBadgeTone {
  return 'warning';
}
function rupiah(v: number): string {
  return `Rp ${v.toLocaleString('id-ID')}`;
}

function pay(_e: BimbelEnrollment) {
  toast.info(t('tutoring2.common.notAvailable'));
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.pay.title')"
      :meta="t('tutoring2.parent.pay.meta', {
        children: uniqueStudents.length,
        count: enrollments.length,
      })"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.pay.emptyTitle')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="e in enrollments"
              :key="e.id"
              class="flex items-center gap-3 px-4 py-3"
            >
              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-azure/10 text-xs font-bold uppercase text-brand-azure">
                {{ e.student_id.slice(0, 2).toUpperCase() }}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ t('tutoring2.common.studentId') }} {{ shortId(e.student_id) }}
                </p>
                <p class="truncate text-2xs text-slate-500">
                  <!-- TODO i18n key: real description from BE-6 tagihan payload -->
                  SPP Jan · {{ rupiah(billAmount(e)) }}
                </p>
              </div>
              <StatusBadge :label="billStatusLabel()" :tone="billStatusTone()" uppercase />
              <Button variant="primary" size="sm" @click="pay(e)">
                {{ t('tutoring2.parent.pay.payCta') }}
              </Button>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
