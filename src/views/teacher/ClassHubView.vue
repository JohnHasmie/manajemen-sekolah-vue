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
import { useRoute, type RouteLocationRaw } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Modal from '@/components/ui/Modal.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useRoleColor } from '@/composables/useRoleColor';
import { canonicalRole, ROLE_ADMIN, ROLE_PARENT, ROLE_TEACHER } from '@/utils/role';
import type { Role } from '@/types/auth';
import type { StatusBadgeTone } from '@/types/status-badge';
import { ClassHubService } from '@/services/class-hub.service';
import {
  type ClassCard,
  type ClassFeedItem,
  type ClassFeedType,
  type ClassMembers,
} from '@/types/class-hub';
import { classHubAccent, classHubGradientCss } from '@/utils/classHubTheme';

const props = withDefaults(
  defineProps<{ id: string; roleName?: string; studentId?: string }>(),
  { roleName: ROLE_TEACHER, studentId: undefined },
);
const { t } = useI18n();
// Canonicalise `roleName` (a plain string prop; accepts the canonical English
// keys plus any straggling legacy Indonesian spelling from stale routes)
// once, then thread it through the shared role-aware components
// (useRoleColor / BrandPageHeader) and the back-target routing.
const canonRole = computed(() => canonicalRole(props.roleName));
const headerRole = computed<Role>(() => canonRole.value as Role);
const role = useRoleColor(() => canonRole.value as Role);

// The opened card's scope comes from the ?subject_id= query: present → the
// subject-scoped hub, absent → the general (all-subjects) hub.
const route = useRoute();
const subjectId = computed<string | null>(
  () => (route.query.subject_id as string | undefined) ?? null,
);
const isGeneral = computed(() => subjectId.value == null);

// General-hub client-side filter (subject / teacher), derived from the feed.
const filterSubjectId = ref<string | null>(null);
const filterTeacherId = ref<string | null>(null);

// Back target mirrors the role's list surface (mirrors the header link).
const backTarget = computed<RouteLocationRaw>(() => {
  if (canonRole.value === ROLE_ADMIN) return { name: 'admin.class-oversight' };
  if (canonRole.value === ROLE_PARENT) return { name: 'parent.classes' };
  return { name: 'teacher.classes' };
});

// Deep-link a feed card to the underlying module, scoped to this class.
// Teacher-only — parent/admin hubs are read-only observers (mirrors the mobile
// ClassHubDetailScreen._feedTapFor). Returns null when the card isn't
// actionable (nilai/unknown, or a non-teacher viewer).
function feedTarget(item: ClassFeedItem): RouteLocationRaw | null {
  if (canonRole.value !== ROLE_TEACHER) return null;
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

// Inline grading: teacher with a backlog can jump straight to the class-scoped
// class-activity list (where submissions are graded) — from the "Perlu
// dinilai" KPI and the Tugas-tab banner. Parent/admin stay read-only.
const gradingTarget: RouteLocationRaw = {
  name: 'teacher.class-activity',
  query: { class_id: props.id },
};
const showGrading = computed(
  () => canonRole.value === ROLE_TEACHER && (card.value?.needsGrading ?? 0) > 0,
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
      // Subject cards narrow the feed server-side; the general hub loads
      // everything and filters by subject/teacher client-side.
      ClassHubService.feed(
        props.id,
        subjectId.value ? { subjectId: subjectId.value } : {},
      ),
      // Admin reads the header card from the school-wide oversight list;
      // teacher/parent from their own /classes/mine.
      canonRole.value === ROLE_ADMIN
        ? ClassHubService.oversight()
        : ClassHubService.myClasses(props.studentId),
    ]);
    items.value = feed;
    // A class now yields several cards — pick the one matching this scope.
    card.value =
      cards.find(
        (c) =>
          c.id === props.id &&
          (subjectId.value
            ? c.subjectId === subjectId.value
            : c.scope === 'general'),
      ) ??
      cards.find((c) => c.id === props.id) ??
      null;
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

const metaStr = (i: ClassFeedItem, k: string): string | null =>
  typeof i.meta[k] === 'string' ? (i.meta[k] as string) : null;

// Distinct subjects / teachers present in the feed → general-hub filter menus.
function distinct(
  idKey: string,
  labelOf: (i: ClassFeedItem) => string | null,
): { key: string; label: string }[] {
  const seen = new Map<string, string>();
  for (const i of items.value) {
    const id = metaStr(i, idKey);
    if (!id || seen.has(id)) continue;
    const l = labelOf(i);
    seen.set(id, l && l.length ? l : id);
  }
  return [...seen.entries()].map(([key, label]) => ({ key, label }));
}
const subjectOptions = computed(() =>
  distinct('subject_id', (i) => i.subtitle),
);
const teacherOptions = computed(() =>
  distinct('teacher_id', (i) => metaStr(i, 'teacher_name')),
);

// General-hub Mapel / Guru filter — shared AppFilterChip + a picker Modal,
// mirroring the Kelas / Mapel chips on Kegiatan Kelas & Nilai.
const activePicker = ref<null | 'subject' | 'teacher'>(null);

function labelFor(
  opts: { key: string; label: string }[],
  id: string | null,
): string {
  if (!id) return t('classHub.filterAll');
  return opts.find((o) => o.key === id)?.label ?? id;
}
const filterSubjectLabel = computed(() =>
  labelFor(subjectOptions.value, filterSubjectId.value),
);
const filterTeacherLabel = computed(() =>
  labelFor(teacherOptions.value, filterTeacherId.value),
);

const pickerTitle = computed(() =>
  activePicker.value === 'teacher'
    ? t('classHub.filterTeacher')
    : t('classHub.filterSubject'),
);
const pickerOptions = computed(() =>
  activePicker.value === 'teacher' ? teacherOptions.value : subjectOptions.value,
);
const pickerCurrent = computed(() =>
  activePicker.value === 'teacher' ? filterTeacherId.value : filterSubjectId.value,
);
function choosePicker(id: string | null) {
  if (activePicker.value === 'teacher') filterTeacherId.value = id;
  else filterSubjectId.value = id;
  activePicker.value = null;
}

const visibleItems = computed(() => {
  let list = items.value;
  if (isGeneral.value) {
    list = list.filter((i) => {
      if (filterSubjectId.value && metaStr(i, 'subject_id') !== filterSubjectId.value) {
        return false;
      }
      if (filterTeacherId.value && metaStr(i, 'teacher_id') !== filterTeacherId.value) {
        return false;
      }
      return true;
    });
  }
  if (tab.value === 'tugas') {
    return list.filter((i) => ['tugas', 'ujian', 'materi'].includes(i.type));
  }
  if (tab.value === 'nilai') {
    return list.filter((i) => i.type === 'nilai');
  }
  return list;
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

// Kicker — subject-scoped shows the subject; general shows "all subjects".
const kicker = computed(() => {
  if (!isGeneral.value) {
    const subj = card.value?.subjectName ?? '';
    return canonRole.value === ROLE_PARENT
      ? subj
      : `${t('classHub.roleSubject')} · ${subj}`;
  }
  return canonRole.value === ROLE_TEACHER
    ? `${t('classHub.roleHomeroom')} · ${t('classHub.allSubjects')}`
    : t('classHub.allSubjects');
});

// Subject-scoped hubs are themed by the subject colour — the same hue as the
// list card you opened, so the hub reads as "the same place". General / parent
// / admin hubs keep the role accent over the navy overview gradient.
const subjectKey = computed(
  () => card.value?.subjectName ?? card.value?.subjectId ?? card.value?.id ?? '',
);
const accentHex = computed(() =>
  isGeneral.value ? role.value.hex : classHubAccent(subjectKey.value),
);
// Header (+ list-card) gradient: subject gradient for a subject hub, navy
// overview gradient for a general hub — matching the card you tapped.
const headerGradient = computed(() =>
  classHubGradientCss(isGeneral.value ? null : subjectKey.value),
);
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
      :gradient="headerGradient"
      :kicker="kicker || undefined"
      :title="card?.name ?? ''"
    />

    <KpiStripCards v-if="card" :cards="kpiCards" :lg-cols="3" class="mt-4" />

    <!-- General (all-subjects) hub: filter the merged feed by subject / teacher.
         Read-only across subjects. -->
    <PageFilterToolbar v-if="isGeneral" hide-default-search class="mt-4">
      <template #chips>
        <AppFilterChip
          :label="t('classHub.filterSubject')"
          :value="filterSubjectLabel"
          icon-name="book"
          tone="brand"
          @click="activePicker = 'subject'"
        />
        <AppFilterChip
          :label="t('classHub.filterTeacher')"
          :value="filterTeacherLabel"
          icon-name="user"
          tone="violet"
          @click="activePicker = 'teacher'"
        />
        <span class="self-center text-xs text-slate-400">
          · {{ t('classHub.generalViewHint') }}
        </span>
      </template>
    </PageFilterToolbar>

    <div class="mt-4 mb-4">
      <SegmentedControl
        :model-value="tab"
        :options="tabOptions"
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
          :style="{ backgroundColor: accentHex + '26', color: accentHex }"
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
          :style="{ color: accentHex }"
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
            :style="{ backgroundColor: accentHex + '1F', color: accentHex }"
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
          :style="{ backgroundColor: accentHex + '14' }"
        >
          <span :style="{ color: accentHex }">✎</span>
          <span class="text-sm font-medium flex-1" :style="{ color: accentHex }">
            {{ card?.needsGrading ?? 0 }}
            {{ t('classHub.needsGradingBanner') }}
          </span>
          <span class="text-sm font-semibold" :style="{ color: accentHex }">
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
              <div
                v-if="isGeneral && it.subtitle"
                class="flex items-center gap-1.5 mt-1.5 min-w-0"
              >
                <span
                  class="text-[10px] font-bold text-slate-600 bg-slate-100 border border-slate-200 rounded px-1.5 py-0.5 shrink-0"
                >{{ it.subtitle }}</span>
                <span
                  v-if="metaStr(it, 'teacher_name')"
                  class="text-xs text-slate-500 truncate"
                >{{ metaStr(it, 'teacher_name') }}</span>
              </div>
              <p
                v-else-if="feedSubtitle(it)"
                class="text-xs text-slate-500 mt-1"
              >
                {{ feedSubtitle(it) }}
              </p>
            </component>
          </div>
        </section>
      </div>
    </AsyncView>

    <!-- Mapel / Guru picker (general hub) -->
    <Modal
      v-if="activePicker"
      :title="pickerTitle"
      size="sm"
      @close="activePicker = null"
    >
      <ul class="space-y-1 max-h-[60vh] overflow-y-auto">
        <li>
          <button
            type="button"
            class="w-full text-left rounded-lg px-3 py-2 text-sm font-medium hover:bg-slate-50"
            :class="pickerCurrent == null ? 'text-brand-cobalt font-bold' : 'text-slate-700'"
            @click="choosePicker(null)"
          >
            {{ t('classHub.filterAll') }}
          </button>
        </li>
        <li v-for="o in pickerOptions" :key="o.key">
          <button
            type="button"
            class="w-full text-left rounded-lg px-3 py-2 text-sm font-medium hover:bg-slate-50"
            :class="pickerCurrent === o.key ? 'text-brand-cobalt font-bold' : 'text-slate-700'"
            @click="choosePicker(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
