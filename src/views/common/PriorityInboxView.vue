<!--
  PriorityInboxView.vue — full-screen "Perlu Perhatian" list.

  Mirrors Flutter's `{admin,teacher,parent}_inbox_screen.dart` triplet.
  One component drives all three roles — the route mounts it with a
  `role` prop, which decides:
    1. Which service method to call (admin/teacher/parent + child id)
    2. Which header chrome to use (BrandPageHeader navy/teal vs
       ParentPageHeader azure)
    3. Which back route to land on

  Filter buckets (Semua / Kritis / Peringatan / Info) are local — the
  full list is fetched once and partitioned client-side.

  Routes:
    /admin/inbox          → role="admin"
    /teacher/inbox        → role="teacher"
    /parent/inbox         → role="parent"
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { DashboardService } from '@/services/dashboard.service';
import { usePriorityInbox } from '@/composables/usePriorityInbox';
import type { PriorityItem } from '@/components/feature/PriorityInbox.vue';
import { useChildPicker } from '@/composables/useChildPicker';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useLocaleWatcher } from '@/composables/useLocaleWatcher';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import ParentPageHeader from '@/components/layout/ParentPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type InboxRole = 'admin' | 'teacher' | 'parent';

const props = withDefaults(
  defineProps<{
    role: InboxRole;
  }>(),
  { role: 'admin' },
);

const router = useRouter();
const { t } = useI18n();
const { mapToPriorityItems, handlePriorityTap } = usePriorityInbox(props.role);
const { activeChildId } = useChildPicker();

// ── Data ──────────────────────────────────────────────────────────
const items = ref<PriorityItem[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);

async function reload() {
  isLoading.value = true;
  error.value = null;
  try {
    let raw: unknown;
    if (props.role === 'admin') {
      raw = await DashboardService.adminPriorityInboxAll();
    } else if (props.role === 'teacher') {
      // Teacher uses the same dashboard endpoint with a high limit so
      // every aggregator can return its full set.
      const res = await DashboardService.teacherPriorityInbox(200);
      raw = (res as any).items ?? (res as any).data ?? res;
    } else {
      raw = await DashboardService.parentPriorityInboxAll(
        activeChildId.value ?? undefined,
      );
    }
    items.value = mapToPriorityItems(raw);
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(reload);
useAcademicYearWatcher(reload);
// Re-fetch the server-localised inbox when the app language changes so
// the labels/subtitles follow the new locale without a page reload.
useLocaleWatcher(reload);

// ── Filter buckets ────────────────────────────────────────────────
type FilterKey = 'all' | 'critical' | 'warning' | 'info';
const activeFilter = ref<FilterKey>('all');

const FILTERS: { key: FilterKey; label: string }[] = [
  { key: 'all', label: t('common.all') },
  { key: 'critical', label: t('common.critical') },
  { key: 'warning', label: t('common.warning') },
  { key: 'info', label: t('common.info') },
];

const bucketCounts = computed(() => ({
  all: items.value.length,
  critical: items.value.filter((i) => i.severity === 'critical').length,
  warning: items.value.filter((i) => i.severity === 'warning').length,
  info: items.value.filter((i) => i.severity === 'info').length,
}));

const filteredItems = computed(() =>
  activeFilter.value === 'all'
    ? items.value
    : items.value.filter((i) => i.severity === activeFilter.value),
);

// ── State for AsyncView ───────────────────────────────────────────
const listState = computed<AsyncState<PriorityItem[]>>(() => {
  if (isLoading.value && items.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (filteredItems.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: filteredItems.value };
});

// ── Display helpers ───────────────────────────────────────────────
function severityDotCls(s: PriorityItem['severity']): string {
  if (s === 'critical') return 'bg-red-500';
  if (s === 'warning') return 'bg-amber-500';
  return 'bg-brand-cobalt';
}
function severityBgCls(s: PriorityItem['severity']): string {
  if (s === 'critical') return 'bg-red-50 border-red-200';
  if (s === 'warning') return 'bg-amber-50 border-amber-200';
  return 'bg-slate-50 border-slate-200';
}
function severityLabel(s: PriorityItem['severity']): string {
  if (s === 'critical') return t('common.severityCritical');
  if (s === 'warning') return t('common.severityWarning');
  return t('common.severityInfo');
}
function severityChipCls(s: PriorityItem['severity']): string {
  if (s === 'critical') return 'bg-red-100 text-red-700';
  if (s === 'warning') return 'bg-amber-100 text-amber-700';
  return 'bg-slate-100 text-slate-600';
}
function getIconForType(type: string): string {
  if (type.includes('attendance')) return 'check-square';
  if (type.includes('lesson_plan')) return 'file-text';
  if (type.includes('grade')) return 'edit';
  if (type.includes('rapor') || type.includes('report')) return 'file-text';
  if (type.includes('announcement')) return 'megaphone';
  if (type.includes('billing') || type.includes('tagihan')) return 'wallet';
  return 'bell';
}

function formatRelative(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const diff = Date.now() - d.getTime();
  const m = Math.floor(diff / 60_000);
  if (m < 1) return t('common.timeJustNow');
  if (m < 60) return `${m} ${t('common.timeMinutesAgo')}`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} ${t('common.timeHoursAgo')}`;
  const days = Math.floor(h / 24);
  if (days < 7) return `${days} ${t('common.timeDaysAgo')}`;
  return d.toLocaleDateString('id-ID', { day: '2-digit', month: 'short' });
}

function onItemTap(item: PriorityItem) {
  handlePriorityTap(item);
}

function goBack() {
  if (props.role === 'admin') router.push({ name: 'admin.home' });
  else if (props.role === 'teacher') router.push({ name: 'teacher.home' });
  else router.push({ name: 'parent.home' });
}

const kicker = computed(() => {
  if (props.role === 'admin') return t('common.homeAdmin');
  if (props.role === 'teacher') return t('common.homeTeacher');
  return t('common.home');
});
const headerMeta = computed(
  () =>
    `${bucketCounts.value.all} total · ${bucketCounts.value.critical} ${t('common.critical')} · ${bucketCounts.value.warning} ${t('common.warning')}`,
);
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-slate-900"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('common.home') }}
    </button>

    <!-- Header — gradient for admin/teacher, solid azure for parent -->
    <ParentPageHeader
      v-if="role === 'parent'"
      :kicker="kicker"
      :title="t('common.needsAttention')"
      :meta="headerMeta"
    />
    <BrandPageHeader
      v-else
      :role="role"
      :kicker="kicker"
      :title="t('common.needsAttention')"
      :meta="headerMeta"
      :live-dot="false"
    />

    <!-- Filter bucket chips -->
    <div class="flex items-center gap-1.5 flex-wrap">
      <button
        v-for="f in FILTERS"
        :key="f.key"
        type="button"
        class="px-3 py-1.5 rounded-full text-2xs font-bold transition border inline-flex items-center gap-1.5"
        :class="
          activeFilter === f.key
            ? 'bg-slate-900 text-white border-slate-900 shadow-sm'
            : 'bg-white text-slate-600 border-slate-200 hover:border-slate-400'
        "
        @click="activeFilter = f.key"
      >
        {{ f.label }}
        <span
          class="text-[9.5px] font-black px-1.5 py-0.5 rounded-md tabular-nums"
          :class="
            activeFilter === f.key
              ? 'bg-white/20 text-white'
              : 'bg-slate-100 text-slate-500'
          "
        >
          {{ bucketCounts[f.key] }}
        </span>
      </button>
    </div>

    <AsyncView
      :state="listState"
      :empty-title="
        activeFilter === 'all'
          ? t('common.noPendingAttention')
          : t('common.noItemsInCategory')
      "
      :empty-description="t('common.allPriorityHandled')"
      empty-icon="check-circle"
      @retry="reload"
    >
      <template #default>
        <ul class="space-y-2">
          <li v-for="item in filteredItems" :key="item.id">
            <button
              type="button"
              class="w-full text-left rounded-2xl border p-3.5 flex items-center gap-3 hover:shadow-md transition-shadow"
              :class="severityBgCls(item.severity)"
              @click="onItemTap(item)"
            >
              <div
                class="w-10 h-10 rounded-xl bg-white grid place-items-center flex-shrink-0 shadow-sm"
              >
                <NavIcon
                  :name="getIconForType(item.type)"
                  :size="18"
                  class="text-slate-700"
                />
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <span
                    class="px-2 py-0.5 rounded-md text-4xs font-black tracking-widest"
                    :class="severityChipCls(item.severity)"
                  >
                    <span
                      class="inline-block w-1.5 h-1.5 rounded-full mr-1 align-middle"
                      :class="severityDotCls(item.severity)"
                    />
                    {{ severityLabel(item.severity) }}
                  </span>
                  <span
                    v-if="item.count > 1"
                    class="text-[9.5px] font-bold text-slate-500"
                  >
                    {{ item.count }}×
                  </span>
                </div>
                <p class="text-[13.5px] font-bold text-slate-900 mt-1 leading-snug">
                  {{ item.label }}
                </p>
                <p
                  v-if="item.subtitle"
                  class="text-2xs text-slate-600 mt-0.5 leading-snug line-clamp-2"
                >
                  {{ item.subtitle }}
                </p>
                <p class="text-3xs text-slate-400 mt-1 tabular-nums">
                  {{ formatRelative(item.occurred_at) }}
                </p>
              </div>
              <NavIcon
                name="chevron-right"
                :size="14"
                class="text-slate-300 flex-shrink-0"
              />
            </button>
          </li>
        </ul>
      </template>
    </AsyncView>
  </div>
</template>
