<!--
  Per-class hub (web) — role-tinted header + KPI + 4-tab layout
  (Riwayat Sesi / Tugas / Anggota / Nilai). Riwayat Sesi is the server-merged
  feed from GET /classes/{id}/feed, time-bucketed. Tugas & Nilai render the
  same feed filtered by type; Anggota shows the roster summary. Mirrors the
  mobile ClassHubDetailScreen.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import type { RouteLocationRaw } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useRoleColor } from '@/composables/useRoleColor';
import { canonicalRole, ROLE_ADMIN, ROLE_PARENT } from '@/utils/role';
import type { Role } from '@/types/auth';
import type { StatusBadgeTone } from '@/types/status-badge';
import { ClassHubService } from '@/services/class-hub.service';
import {
  isWaliKelas,
  type ClassCard,
  type ClassFeedItem,
  type ClassFeedType,
  type ClassMembers,
} from '@/types/class-hub';

const props = withDefaults(
  defineProps<{ id: string; roleName?: string; studentId?: string }>(),
  { roleName: 'guru', studentId: undefined },
);
const { t } = useI18n();
// Canonicalise `roleName` (a plain string prop that may still be the legacy
// 'guru'/'wali' spelling) once, then thread it through the shared role-aware
// components (useRoleColor / BrandPageHeader) and the back-target routing.
const canonRole = computed(() => canonicalRole(props.roleName));
const headerRole = computed<Role>(() => canonRole.value as Role);
const role = useRoleColor(() => canonRole.value as Role);

// Back target mirrors the role's list surface (mirrors the header link).
const backTarget = computed<RouteLocationRaw>(() => {
  if (canonRole.value === ROLE_ADMIN) return { name: 'admin.class-oversight' };
  if (canonRole.value === ROLE_PARENT) return { name: 'parent.classes' };
  return { name: 'teacher.classes' };
});

// Deep-link a feed card to the underlying module, scoped to this class.
// Guru-only — parent/admin hubs are read-only observers (mirrors the mobile
// ClassHubDetailScreen._feedTapFor). Returns null when the card isn't
// actionable (nilai/unknown, or a non-guru viewer).
function feedTarget(item: ClassFeedItem): RouteLocationRaw | null {
  if (props.roleName !== 'guru') return null;
  switch (item.type) {
    case 'tugas':
    case 'ujian':
    case 'materi':
      return { name: 'teacher.class-activity', query: { class_id: props.id } };
    case 'pengumuman':
      return { name: 'teacher.announcements' };
    default:
      return null;
  }
}

// Inline grading: guru with a backlog can jump straight to the class-scoped
// class-activity list (where submissions are graded) — from the "Perlu
// dinilai" KPI and the Tugas-tab banner. Parent/admin stay read-only.
const gradingTarget: RouteLocationRaw = {
  name: 'teacher.class-activity',
  query: { class_id: props.id },
};
const showGrading = computed(
  () => props.roleName === 'guru' && (card.value?.needsGrading ?? 0) > 0,
);

type Tab = 'riwayat' | 'tugas' | 'anggota' | 'nilai';
const tab = ref<Tab>('riwayat');

const loading = ref(true);
const error = ref<string | null>(null);
const items = ref<ClassFeedItem[]>([]);
const card = ref<ClassCard | null>(null);

// Anggota roster — lazily fetched the first time the tab is opened.
const members = ref<ClassMembers | null>(null);
const membersLoading = ref(false);
const membersError = ref<string | null>(null);

async function load() {
  loading.value = true;
  error.value = null;
  try {
    const [feed, cards] = await Promise.all([
      ClassHubService.feed(props.id),
      // Admin reads the header card from the school-wide oversight list;
      // guru/parent from their own /classes/mine.
      props.roleName === 'admin'
        ? ClassHubService.oversight()
        : ClassHubService.myClasses(props.studentId),
    ]);
    items.value = feed;
    card.value = cards.find((c) => c.id === props.id) ?? null;
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e);
  } finally {
    loading.value = false;
  }
}
onMounted(load);

async function loadMembers() {
  membersLoading.value = true;
  membersError.value = null;
  try {
    members.value = await ClassHubService.members(props.id);
  } catch (e) {
    membersError.value = e instanceof Error ? e.message : String(e);
  } finally {
    membersLoading.value = false;
  }
}
watch(tab, (t) => {
  if (t === 'anggota' && members.value === null && !membersLoading.value) {
    loadMembers();
  }
});

const homeroomName = computed(
  () =>
    members.value?.homeroomTeacherName ??
    card.value?.homeroomTeacherName ??
    null,
);
const roster = computed(() => members.value?.students ?? []);

function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].charAt(0).toUpperCase();
  return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
}

const tabs: { key: Tab; labelKey: string }[] = [
  { key: 'riwayat', labelKey: 'classHub.tabSessionLog' },
  { key: 'tugas', labelKey: 'classHub.tabAssignments' },
  { key: 'anggota', labelKey: 'classHub.tabMembers' },
  { key: 'nilai', labelKey: 'classHub.tabGrades' },
];
const tabOptions = computed(() =>
  tabs.map((tb) => ({ key: tb.key, label: t(tb.labelKey) })),
);

// Shared KPI strip — Siswa · Tugas aktif · Perlu dinilai. The grading
// tap-through lives in the Tugas-tab banner (KpiStripCards is display-only).
const kpiCards = computed<KpiCard[]>(() => {
  const c = card.value;
  if (!c) return [];
  return [
    {
      icon: 'users',
      label: t('classHub.kpiStudents'),
      value: c.studentCount,
      tone: 'brand',
    },
    {
      icon: 'check-square',
      label: t('classHub.kpiActiveAssignments'),
      value: c.activeTugas,
      tone: 'violet',
    },
    {
      icon: 'edit',
      label: t('classHub.kpiNeedsGrading'),
      value: c.needsGrading,
      tone: c.needsGrading > 0 ? 'amber' : 'green',
      accented: c.needsGrading > 0,
    },
  ];
});

const visibleItems = computed(() => {
  if (tab.value === 'tugas') {
    return items.value.filter((i) =>
      ['tugas', 'ujian', 'materi'].includes(i.type),
    );
  }
  if (tab.value === 'nilai') {
    return items.value.filter((i) => i.type === 'nilai');
  }
  return items.value;
});

const state = computed(() => {
  if (loading.value) return { status: 'loading' as const };
  if (error.value) return { status: 'error' as const, error: error.value };
  if (tab.value !== 'anggota' && visibleItems.value.length === 0) {
    return { status: 'empty' as const };
  }
  return { status: 'content' as const };
});

interface Bucket {
  key: string;
  items: ClassFeedItem[];
}
const buckets = computed<Bucket[]>(() => {
  const now = Date.now();
  const today: ClassFeedItem[] = [];
  const week: ClassFeedItem[] = [];
  const earlier: ClassFeedItem[] = [];
  for (const it of visibleItems.value) {
    const d = it.occurredAt ? new Date(it.occurredAt) : null;
    if (!d || Number.isNaN(d.getTime())) {
      earlier.push(it);
      continue;
    }
    const days = Math.floor((now - d.getTime()) / 86_400_000);
    if (days <= 0) today.push(it);
    else if (days < 7) week.push(it);
    else earlier.push(it);
  }
  const out: Bucket[] = [];
  if (today.length) out.push({ key: t('classHub.bucketToday'), items: today });
  if (week.length) out.push({ key: t('classHub.bucketWeek'), items: week });
  if (earlier.length) {
    out.push({ key: t('classHub.bucketEarlier'), items: earlier });
  }
  return out;
});

// Feed type → shared StatusBadge tone + i18n label key. The tone palette
// (success/warning/danger/info/neutral) replaces the old bespoke hex pairs.
const TYPE_STYLE: Record<
  ClassFeedType,
  { tone: StatusBadgeTone; key: string }
> = {
  tugas: { tone: 'warning', key: 'classHub.typeAssignment' },
  ujian: { tone: 'danger', key: 'classHub.typeExam' },
  materi: { tone: 'success', key: 'classHub.typeMaterial' },
  pengumuman: { tone: 'info', key: 'classHub.typeAnnouncement' },
  nilai: { tone: 'success', key: 'classHub.typeGrade' },
  presensi: { tone: 'info', key: 'classHub.typePresensi' },
  unknown: { tone: 'neutral', key: 'classHub.typeMaterial' },
};

function relTime(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
}

// Presensi events carry their tally in `meta`; compose a localised title +
// subtitle here rather than relying on server-rendered display text.
function feedTitle(it: ClassFeedItem): string {
  if (it.type === 'presensi' && !it.title) {
    return t('classHub.presensiTitleFallback');
  }
  return it.title;
}
function feedSubtitle(it: ClassFeedItem): string | null {
  if (it.type !== 'presensi') return it.subtitle;
  const num = (k: string): number => {
    const v = it.meta[k];
    return typeof v === 'number' ? v : 0;
  };
  const parts = [
    `${num('present')}/${num('total')} ${t('classHub.attnPresent')}`,
  ];
  if (num('absent') > 0)
    parts.push(`${num('absent')} ${t('classHub.attnAbsent')}`);
  return parts.join(' · ');
}

const roleLabel = computed(() => {
  // Parent is a read-only observer — no wali/guru-mapel label.
  if (props.roleName === 'wali') return '';
  return card.value && isWaliKelas(card.value)
    ? t('classHub.roleHomeroom')
    : t('classHub.roleSubject');
});
</script>

<template>
  <div class="p-4 md:p-6">
    <RouterLink
      :to="backTarget"
      class="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700 mb-2"
      :aria-label="t('classHub.back')"
    >
      ‹ {{ t('classHub.back') }}
    </RouterLink>

    <BrandPageHeader
      :role="headerRole"
      :kicker="roleLabel || undefined"
      :title="card?.name ?? ''"
    />

    <KpiStripCards v-if="card" :cards="kpiCards" :lg-cols="3" class="mt-4" />

    <div class="mt-4 mb-4">
      <SegmentedControl
        :model-value="tab"
        :options="tabOptions"
        size="md"
        @update:model-value="tab = $event as Tab"
      />
    </div>

    <div v-if="tab === 'anggota'" class="space-y-4">
      <div
        v-if="homeroomName"
        class="bg-white rounded-xl border border-slate-200 p-3 flex items-center gap-3"
      >
        <span
          class="w-9 h-9 rounded-full flex items-center justify-center"
          :style="{ backgroundColor: role.hex + '26', color: role.hex }"
          >★</span
        >
        <span>
          <span class="block text-sm font-medium">{{ homeroomName }}</span>
          <span class="block text-xs text-slate-500">
            {{ t('classHub.roleHomeroom') }}
          </span>
        </span>
      </div>

      <p class="text-xs font-medium text-slate-500">
        {{ roster.length }} {{ t('classHub.kpiStudents') }}
      </p>

      <div
        v-if="membersLoading"
        class="py-8 text-center text-sm text-slate-500"
      >
        {{ t('common.loading') }}
      </div>
      <div v-else-if="membersError" class="py-8 text-center">
        <p class="text-sm text-slate-500 mb-2">{{ t('common.error') }}</p>
        <button
          type="button"
          class="text-sm font-medium"
          :style="{ color: role.hex }"
          @click="loadMembers"
        >
          {{ t('common.retry') }}
        </button>
      </div>
      <div
        v-else-if="roster.length === 0"
        class="bg-white rounded-xl border border-slate-200 p-8 text-center"
      >
        <p class="text-sm font-medium text-slate-700">
          {{ t('classHub.emptyRosterTitle') }}
        </p>
        <p class="text-xs text-slate-500 mt-1">
          {{ t('classHub.emptyRosterMsg') }}
        </p>
      </div>
      <div v-else class="bg-white rounded-xl border border-slate-200 divide-y">
        <div
          v-for="s in roster"
          :key="s.id"
          class="p-3 flex items-center gap-3"
        >
          <span
            class="w-9 h-9 rounded-full flex items-center justify-center text-xs font-semibold"
            :style="{ backgroundColor: role.hex + '1F', color: role.hex }"
            >{{ initials(s.name) }}</span
          >
          <span>
            <span class="block text-sm font-medium">{{ s.name }}</span>
            <span v-if="s.nis" class="block text-xs text-slate-500">
              NIS {{ s.nis }}
            </span>
          </span>
        </div>
      </div>
    </div>

    <AsyncView
      v-else
      :state="state"
      :empty-title="t('classHub.emptyFeedTitle')"
      :empty-description="t('classHub.emptyFeedMsg')"
    >
      <div class="space-y-4">
        <RouterLink
          v-if="tab === 'tugas' && showGrading"
          :to="gradingTarget"
          class="flex items-center gap-2 rounded-xl px-3.5 py-2.5"
          :style="{ backgroundColor: role.hex + '14' }"
        >
          <span :style="{ color: role.hex }">✎</span>
          <span class="text-sm font-medium flex-1" :style="{ color: role.hex }">
            {{ card?.needsGrading ?? 0 }}
            {{ t('classHub.needsGradingBanner') }}
          </span>
          <span class="text-sm font-semibold" :style="{ color: role.hex }">
            {{ t('classHub.gradeNow') }} ›
          </span>
        </RouterLink>
        <section v-for="b in buckets" :key="b.key">
          <h2 class="text-xs font-medium text-slate-500 mb-2">{{ b.key }}</h2>
          <div class="space-y-2.5">
            <component
              :is="feedTarget(it) ? 'RouterLink' : 'div'"
              v-for="it in b.items"
              :key="it.type + it.id"
              :to="feedTarget(it) ?? undefined"
              class="block bg-white rounded-xl border border-slate-200 p-3"
              :class="
                feedTarget(it)
                  ? 'hover:border-slate-300 hover:shadow-sm transition cursor-pointer'
                  : ''
              "
            >
              <div class="flex items-center justify-between">
                <StatusBadge
                  :label="t(TYPE_STYLE[it.type].key)"
                  :tone="TYPE_STYLE[it.type].tone"
                />
                <span class="text-[11px] text-slate-400">
                  {{ relTime(it.occurredAt) }}
                </span>
              </div>
              <p class="text-sm font-medium mt-2 text-slate-900">
                {{ feedTitle(it) }}
              </p>
              <p v-if="feedSubtitle(it)" class="text-xs text-slate-500 mt-1">
                {{ feedSubtitle(it) }}
              </p>
            </component>
          </div>
        </section>
      </div>
    </AsyncView>
  </div>
</template>
