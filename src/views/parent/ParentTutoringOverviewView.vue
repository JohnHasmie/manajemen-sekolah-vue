<!--
  ParentTutoringOverviewView — parent's monitoring page for one child's
  bimbel. Uses the BrandPageHeader (wali role → azure gradient) +
  KpiStripCards chrome, with detail sections below.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type {
  TutoringBill,
  TutoringChildOverview,
  TutoringFeedEvent,
  TutoringPaymentAccount,
} from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const studentId = String(route.params.studentId ?? '');
const studentName = String(route.query.name ?? 'Anak');

const loading = ref(true);
const error = ref<string | null>(null);
const data = ref<TutoringChildOverview | null>(null);
const feed = ref<TutoringFeedEvent[]>([]);
const feedLoading = ref(true);

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

async function loadFeed() {
  feedLoading.value = true;
  try {
    feed.value = await TutoringService.getStudentFeed(studentId, {
      limit: 12,
      sinceDays: 30,
    });
  } catch {/* non-fatal */} finally {
    feedLoading.value = false;
  }
}

const paymentAccount = ref<TutoringPaymentAccount | null>(null);
async function loadPaymentAccount() {
  try {
    paymentAccount.value = await TutoringService.getPaymentAccount();
  } catch {/* non-fatal */}
}

function copyText(text?: string | null) {
  if (!text) return;
  navigator.clipboard?.writeText(text);
}

onMounted(async () => {
  await load();
  await Promise.all([loadFeed(), loadPaymentAccount()]);
});

/** Tutor notes first (sticky), then everything else. */
const feedSorted = computed<TutoringFeedEvent[]>(() => {
  const notes = feed.value.filter((e) => e.type === 'note');
  const rest = feed.value.filter((e) => e.type !== 'note');
  return [...notes, ...rest].slice(0, 8);
});

const dateFmt = new Intl.DateTimeFormat('id-ID', {
  day: 'numeric',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
});
function feedTime(iso: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  return Number.isNaN(d.valueOf()) ? '—' : dateFmt.format(d);
}

interface FeedStyle { icon: string; tone: string }
function feedStyle(type: string): FeedStyle {
  switch (type) {
    case 'note':
      return { icon: 'edit', tone: 'text-role-parent bg-role-parent/12' };
    case 'score':
      return { icon: 'check-circle', tone: 'text-emerald-600 bg-emerald-50' };
    case 'announcement':
      return { icon: 'message-square', tone: 'text-role-admin bg-role-admin/12' };
    case 'bill':
      return { icon: 'wallet', tone: 'text-status-danger bg-rose-50' };
    case 'attendance':
      return { icon: 'calendar', tone: 'text-role-guru bg-role-guru/12' };
    default:
      return { icon: 'circle', tone: 'text-slate-500 bg-slate-100' };
  }
}

function unpaid(bills: TutoringBill[]): TutoringBill[] {
  return bills.filter((b) => b.status.toLowerCase() !== 'paid');
}
function billTotal(bills: TutoringBill[]): number {
  return unpaid(bills).reduce((sum, b) => sum + (b.amount ?? 0), 0);
}

const kpiCards = computed<KpiCard[]>(() => {
  if (!data.value) return [];
  const d = data.value;
  return [
    {
      icon: 'check-circle',
      label: t('tutoring.overview.attendance'),
      value:
        d.attendance.attendance_rate == null
          ? '–'
          : `${Math.round(d.attendance.attendance_rate)}%`,
      suffix:
        d.attendance.total_recorded > 0
          ? `${d.attendance.attended}/${d.attendance.total_recorded}`
          : undefined,
      tone: 'green',
      accented: true,
    },
    {
      icon: 'trending-up',
      label: t('tutoring.overview.latest'),
      value:
        d.progress.summary.overall.latest == null
          ? '–'
          : `${Math.round(d.progress.summary.overall.latest)}%`,
      suffix:
        d.progress.summary.overall.average != null
          ? `avg ${Math.round(d.progress.summary.overall.average)}%`
          : undefined,
      tone: 'violet',
    },
    {
      icon: 'calendar',
      label: t('tutoring.overview.schedule'),
      value: d.upcomingSessions.length,
      suffix: 'sesi',
      tone: 'brand',
    },
    {
      icon: 'wallet',
      label: t('tutoring.overview.bills'),
      value: unpaid(d.bills).length,
      suffix:
        unpaid(d.bills).length > 0
          ? formatRupiah(billTotal(d.bills))
          : undefined,
      tone: unpaid(d.bills).length > 0 ? 'amber' : 'green',
    },
  ];
});

const sectionCls = 'bg-white border border-slate-100 rounded-2xl p-4 sm:p-5';
const sectionTitleRow = 'flex items-center gap-2.5 mb-3';
const sectionIconCls =
  'w-7 h-7 rounded-lg bg-role-parent-soft text-role-parent grid place-items-center flex-shrink-0';
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="wali"
      kicker="Bimbel · Monitoring"
      :title="studentName"
      :meta="data
        ? `${data.upcomingSessions.length} sesi mendatang · ${unpaid(data.bills).length} tagihan`
        : ''"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>

    <TutoringEmpty v-else-if="error" :text="error" icon="alert-circle" />

    <template v-else-if="data">
      <KpiStripCards :cards="kpiCards" />

      <!-- ── Yang Baru (activity feed) ───────────────────────────── -->
      <section :class="sectionCls">
        <div :class="sectionTitleRow">
          <span :class="sectionIconCls">
            <NavIcon name="bell" :size="16" />
          </span>
          <h3 class="text-sm font-bold text-slate-900 tracking-tight">
            Yang Baru
          </h3>
        </div>
        <p v-if="feedLoading" class="text-xs text-slate-400">Memuat…</p>
        <p v-else-if="feedSorted.length === 0" class="text-xs text-slate-500">
          Belum ada aktivitas 30 hari terakhir.
        </p>
        <ul v-else class="space-y-2">
          <li
            v-for="(ev, i) in feedSorted"
            :key="i"
            class="flex gap-2.5"
          >
            <span
              class="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-md"
              :class="feedStyle(ev.type).tone"
            >
              <NavIcon :name="feedStyle(ev.type).icon" :size="13" />
            </span>
            <div class="min-w-0 flex-1">
              <div class="line-clamp-2 text-[13px] font-bold text-slate-900">
                {{ ev.title }}
              </div>
              <div
                v-if="ev.subtitle"
                class="line-clamp-3 text-[11.5px] text-slate-500"
              >
                {{ ev.subtitle }}
              </div>
              <div class="mt-0.5 text-[9.5px] font-semibold text-slate-400">
                {{ feedTime(ev.occurred_at) }}
              </div>
            </div>
          </li>
        </ul>
      </section>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <!-- Progress detail -->
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
          <ul v-else class="divide-y divide-slate-100">
            <li
              v-for="e in data.progress.timeline.slice(0, 5)"
              :key="e.assessment_id"
              class="flex items-center justify-between py-1.5 text-sm"
            >
              <span class="text-slate-700">{{ e.title }}</span>
              <span class="font-bold text-slate-900">
                {{ e.percentage == null ? '–' : Math.round(e.percentage) + '%' }}
              </span>
            </li>
          </ul>
        </section>

        <!-- Bills detail + rekening pembayaran -->
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
          <ul v-else class="divide-y divide-slate-100">
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

          <!-- Rekening / QRIS / instruksi pembayaran -->
          <div
            v-if="paymentAccount && (paymentAccount.bank_account_number || paymentAccount.qris_image_url || paymentAccount.payment_instructions)"
            class="mt-3 border-t border-slate-100 pt-3 space-y-2"
          >
            <div class="text-[10px] font-extrabold uppercase tracking-widest text-slate-500">
              Cara Pembayaran
            </div>
            <div
              v-if="paymentAccount.bank_account_number"
              class="rounded-lg bg-slate-50 p-2.5 text-xs text-slate-700"
            >
              <div class="font-bold text-slate-900">{{ paymentAccount.bank_name ?? '—' }}</div>
              <button
                type="button"
                class="font-mono mt-0.5 text-slate-700 hover:text-role-parent"
                @click="copyText(paymentAccount.bank_account_number)"
              >
                {{ paymentAccount.bank_account_number }} ⧉
              </button>
              <div v-if="paymentAccount.bank_account_holder" class="text-slate-500 mt-0.5">
                a.n. {{ paymentAccount.bank_account_holder }}
              </div>
            </div>
            <div
              v-if="paymentAccount.qris_image_url"
              class="rounded-lg bg-slate-50 p-2.5 text-xs"
            >
              <div class="font-bold text-slate-900 mb-1.5">QRIS</div>
              <img
                :src="paymentAccount.qris_image_url"
                alt="QRIS"
                class="max-w-[180px] rounded border border-slate-200"
              />
            </div>
            <div
              v-if="paymentAccount.payment_instructions"
              class="rounded-lg bg-slate-50 p-2.5 text-[11px] text-slate-600 whitespace-pre-line"
            >
              {{ paymentAccount.payment_instructions }}
            </div>
          </div>
        </section>

        <!-- Schedule detail (full-width on mobile, half on >=sm) -->
        <section :class="sectionCls" class="sm:col-span-2">
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
