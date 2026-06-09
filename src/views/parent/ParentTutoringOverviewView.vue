<!--
  ParentTutoringOverviewView — parent's monitoring page for one child's
  bimbel: attendance rate, score progress, outstanding bills, upcoming
  sessions. Rebuilt on the tutoring shared components with the wali
  (azure) accent.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type { TutoringBill, TutoringChildOverview } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringHero from '@/components/feature/tutoring/TutoringHero.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const studentId = String(route.params.studentId ?? '');
const studentName = String(route.query.name ?? 'Anak');

const loading = ref(true);
const error = ref<string | null>(null);
const data = ref<TutoringChildOverview | null>(null);

async function load() {
  loading.value = true;
  error.value = null;
  try {
    data.value = await TutoringService.getChildOverview(studentId);
  } catch (e) {
    error.value =
      e instanceof Error ? e.message : t('tutoring.overview.loadError');
  } finally {
    loading.value = false;
  }
}

onMounted(load);

function unpaid(bills: TutoringBill[]): TutoringBill[] {
  return bills.filter((b) => b.status.toLowerCase() !== 'paid');
}
function billTotal(bills: TutoringBill[]): number {
  return unpaid(bills).reduce((sum, b) => sum + (b.amount ?? 0), 0);
}

const sectionCls =
  'bg-white border border-slate-100 rounded-2xl p-4 sm:p-5';
const sectionTitleRow =
  'flex items-center gap-2.5 mb-3';
const sectionIconCls =
  'w-7 h-7 rounded-lg bg-role-parent-soft text-role-parent grid place-items-center flex-shrink-0';
</script>

<template>
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.overview.title')"
      :crumbs="'Bimbel · ' + studentName"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <TutoringEmpty
      v-else-if="error"
      :text="error"
      icon="alert-circle"
    />

    <template v-else-if="data">
      <TutoringHero
        icon="user"
        greet="MONITORING"
        :title="studentName"
        subtitle="Bimbel Demo"
        accent="wali"
      />

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-4">
        <!-- Attendance -->
        <section :class="sectionCls">
          <div :class="sectionTitleRow">
            <span :class="sectionIconCls">
              <NavIcon name="check-circle" :size="16" />
            </span>
            <h3 class="text-sm font-bold text-slate-900 tracking-tight">
              {{ t('tutoring.overview.attendance') }}
            </h3>
          </div>
          <p
            v-if="data.attendance.total_recorded === 0"
            class="text-xs text-slate-500"
          >
            {{ t('tutoring.overview.noSessions') }}
          </p>
          <div v-else class="flex items-center gap-3">
            <div class="rounded-xl bg-role-parent-soft px-3 py-2 text-center">
              <div class="text-xl font-extrabold text-role-parent">
                {{
                  data.attendance.attendance_rate == null
                    ? '–'
                    : Math.round(data.attendance.attendance_rate) + '%'
                }}
              </div>
              <div class="text-[9.5px] font-bold text-slate-500 uppercase tracking-wider">
                {{ t('tutoring.overview.present') }}
              </div>
            </div>
            <p class="text-xs text-slate-500">
              {{ data.attendance.attended }} {{ t('tutoring.overview.of') }}
              {{ data.attendance.total_recorded }}
              {{ t('tutoring.overview.sessionsAttended') }}
            </p>
          </div>
        </section>

        <!-- Progress -->
        <section :class="sectionCls">
          <div :class="sectionTitleRow">
            <span :class="sectionIconCls">
              <NavIcon name="trending-up" :size="16" />
            </span>
            <h3 class="text-sm font-bold text-slate-900 tracking-tight">
              {{ t('tutoring.overview.progress') }}
            </h3>
          </div>
          <p
            v-if="data.progress.timeline.length === 0"
            class="text-xs text-slate-500"
          >
            {{ t('tutoring.overview.noScores') }}
          </p>
          <div v-else>
            <div class="flex items-center gap-3 mb-2">
              <div class="rounded-xl bg-role-parent-soft px-3 py-2 text-center">
                <div class="text-xl font-extrabold text-role-parent">
                  {{
                    data.progress.summary.overall.latest == null
                      ? '–'
                      : Math.round(data.progress.summary.overall.latest) + '%'
                  }}
                </div>
                <div class="text-[9.5px] font-bold text-slate-500 uppercase tracking-wider">
                  {{ t('tutoring.overview.latest') }}
                </div>
              </div>
              <p class="text-xs text-slate-500">
                {{ t('tutoring.overview.best') }}
                {{ Math.round(data.progress.summary.overall.best ?? 0) }}% ·
                {{ t('tutoring.overview.average') }}
                {{ Math.round(data.progress.summary.overall.average ?? 0) }}%
              </p>
            </div>
            <ul class="divide-y divide-slate-100">
              <li
                v-for="e in data.progress.timeline.slice(0, 3)"
                :key="e.assessment_id"
                class="flex items-center justify-between py-1.5 text-sm"
              >
                <span class="text-slate-700">{{ e.title }}</span>
                <span class="font-bold text-slate-900">
                  {{ e.percentage == null ? '–' : Math.round(e.percentage) + '%' }}
                </span>
              </li>
            </ul>
          </div>
        </section>

        <!-- Bills -->
        <section :class="sectionCls">
          <div :class="sectionTitleRow">
            <span :class="sectionIconCls">
              <NavIcon name="wallet" :size="16" />
            </span>
            <h3 class="text-sm font-bold text-slate-900 tracking-tight">
              {{ t('tutoring.overview.bills') }}
            </h3>
          </div>
          <p
            v-if="unpaid(data.bills).length === 0"
            class="text-xs text-slate-500"
          >
            {{ t('tutoring.overview.noBills') }}
          </p>
          <div v-else>
            <p class="mb-2 text-sm font-bold text-status-danger">
              {{ t('tutoring.overview.totalDue') }}:
              {{ formatRupiah(billTotal(data.bills)) }}
            </p>
            <ul class="divide-y divide-slate-100">
              <li
                v-for="b in unpaid(data.bills)"
                :key="b.id"
                class="flex items-center justify-between py-1.5 text-xs"
              >
                <span class="text-slate-700">
                  {{ b.source_label ?? t('tutoring.overview.billDefault') }}
                  <template v-if="b.due_date">
                    · {{ t('tutoring.overview.due') }}
                    {{ formatDateShort(b.due_date) }}
                  </template>
                </span>
                <span class="font-bold text-slate-900">
                  {{ formatRupiah(b.amount ?? 0) }}
                </span>
              </li>
            </ul>
          </div>
        </section>

        <!-- Schedule -->
        <section :class="sectionCls">
          <div :class="sectionTitleRow">
            <span :class="sectionIconCls">
              <NavIcon name="calendar" :size="16" />
            </span>
            <h3 class="text-sm font-bold text-slate-900 tracking-tight">
              {{ t('tutoring.overview.schedule') }}
            </h3>
          </div>
          <p
            v-if="data.upcomingSessions.length === 0"
            class="text-xs text-slate-500"
          >
            {{ t('tutoring.overview.noSchedule') }}
          </p>
          <ul v-else class="space-y-2">
            <li
              v-for="s in data.upcomingSessions.slice(0, 5)"
              :key="s.id"
              class="flex gap-2"
            >
              <span class="mt-2 h-1.5 w-1.5 rounded-full bg-slate-400 flex-shrink-0" />
              <div class="min-w-0">
                <div class="text-sm font-semibold text-slate-900">
                  {{ s.scheduled_at ? formatDateShort(s.scheduled_at) : '—' }}
                </div>
                <div class="text-xs text-slate-500 truncate">
                  {{
                    [
                      s.group?.program?.name,
                      s.topic,
                      s.room ? t('tutoring.overview.room') + ' ' + s.room : null,
                    ]
                      .filter(Boolean)
                      .join(' · ')
                  }}
                </div>
              </div>
            </li>
          </ul>
        </section>
      </div>
    </template>
  </div>
</template>
