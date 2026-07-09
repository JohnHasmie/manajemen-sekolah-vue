<!--
  Per-class hub (web) — role-tinted header + KPI + 4-tab layout
  (Riwayat Sesi / Tugas / Anggota / Nilai). Riwayat Sesi is the server-merged
  feed from GET /classes/{id}/feed, time-bucketed. Tugas & Nilai render the
  same feed filtered by type; Anggota shows the roster summary. Mirrors the
  mobile ClassHubDetailScreen.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView from '@/components/data/AsyncView.vue';
import { useRoleColor } from '@/composables/useRoleColor';
import { ClassHubService } from '@/services/class-hub.service';
import {
  isWaliKelas,
  type ClassCard,
  type ClassFeedItem,
  type ClassFeedType,
} from '@/types/class-hub';

const props = withDefaults(
  defineProps<{ id: string; roleName?: string; studentId?: string }>(),
  { roleName: 'guru', studentId: undefined },
);
const { t } = useI18n();
const role = useRoleColor(() => props.roleName);

type Tab = 'riwayat' | 'tugas' | 'anggota' | 'nilai';
const tab = ref<Tab>('riwayat');

const loading = ref(true);
const error = ref<string | null>(null);
const items = ref<ClassFeedItem[]>([]);
const card = ref<ClassCard | null>(null);

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

const tabs: { key: Tab; labelKey: string }[] = [
  { key: 'riwayat', labelKey: 'classHub.tabSessionLog' },
  { key: 'tugas', labelKey: 'classHub.tabAssignments' },
  { key: 'anggota', labelKey: 'classHub.tabMembers' },
  { key: 'nilai', labelKey: 'classHub.tabGrades' },
];

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

const TYPE_STYLE: Record<ClassFeedType, { bg: string; fg: string; key: string }> =
  {
    tugas: { bg: '#FAEEDA', fg: '#854F0B', key: 'classHub.typeAssignment' },
    ujian: { bg: '#FCEBEB', fg: '#791F1F', key: 'classHub.typeExam' },
    materi: { bg: '#EAF3DE', fg: '#27500A', key: 'classHub.typeMaterial' },
    pengumuman: { bg: '#E6F1FB', fg: '#0C447C', key: 'classHub.typeAnnouncement' },
    nilai: { bg: '#E1F5EE', fg: '#085041', key: 'classHub.typeGrade' },
    unknown: { bg: '#F1EFE8', fg: '#5F5E5A', key: 'classHub.typeMaterial' },
  };

function relTime(iso: string | null): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
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
    <header
      class="rounded-2xl px-5 py-4 mb-3"
      :style="{ backgroundColor: role.hex + '1A' }"
    >
      <div class="flex items-center gap-3">
        <RouterLink
          :to="{
            name:
              roleName === 'admin'
                ? 'admin.class-oversight'
                : roleName === 'wali'
                  ? 'parent.classes'
                  : 'teacher.classes',
          }"
          class="text-lg leading-none"
          :style="{ color: role.hex }"
          :aria-label="t('classHub.back')"
        >‹</RouterLink>
        <div>
          <h1 class="text-base font-medium" :style="{ color: role.hex }">
            {{ card?.name ?? '' }}
          </h1>
          <p class="text-xs" :style="{ color: role.hex }">{{ roleLabel }}</p>
        </div>
      </div>
      <div class="flex mt-3" v-if="card">
        <div class="flex-1">
          <div class="text-base font-medium" :style="{ color: role.hex }">
            {{ card.studentCount }}
          </div>
          <div class="text-[11px]" :style="{ color: role.hex }">
            {{ t('classHub.kpiStudents') }}
          </div>
        </div>
        <div class="flex-1 border-l pl-2" :style="{ borderColor: role.hex + '40' }">
          <div class="text-base font-medium" :style="{ color: role.hex }">
            {{ card.activeTugas }}
          </div>
          <div class="text-[11px]" :style="{ color: role.hex }">
            {{ t('classHub.kpiActiveAssignments') }}
          </div>
        </div>
        <div class="flex-1 border-l pl-2" :style="{ borderColor: role.hex + '40' }">
          <div class="text-base font-medium" :style="{ color: role.hex }">
            {{ card.needsGrading }}
          </div>
          <div class="text-[11px]" :style="{ color: role.hex }">
            {{ t('classHub.kpiNeedsGrading') }}
          </div>
        </div>
      </div>
    </header>

    <div class="flex gap-5 border-b border-slate-200 mb-4">
      <button
        v-for="tb in tabs"
        :key="tb.key"
        type="button"
        class="pb-2 text-sm -mb-px border-b-2 transition"
        :class="tab === tb.key ? 'font-medium' : 'text-slate-500 border-transparent'"
        :style="tab === tb.key ? { color: role.hex, borderColor: role.hex } : {}"
        @click="tab = tb.key"
      >
        {{ t(tb.labelKey) }}
      </button>
    </div>

    <div v-if="tab === 'anggota'">
      <div class="bg-white rounded-xl border border-slate-200 divide-y">
        <div v-if="card?.homeroomTeacherName" class="p-3 flex items-center gap-3">
          <span
            class="w-9 h-9 rounded-full flex items-center justify-center"
            :style="{ backgroundColor: role.hex + '26', color: role.hex }"
          >★</span>
          <span>
            <span class="block text-sm font-medium">
              {{ card.homeroomTeacherName }}
            </span>
            <span class="block text-xs text-slate-500">
              {{ t('classHub.roleHomeroom') }}
            </span>
          </span>
        </div>
        <div class="p-3 text-sm text-slate-600">
          {{ card?.studentCount ?? 0 }} {{ t('classHub.kpiStudents') }}
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
        <section v-for="b in buckets" :key="b.key">
          <h2 class="text-xs font-medium text-slate-500 mb-2">{{ b.key }}</h2>
          <div class="space-y-2.5">
            <div
              v-for="it in b.items"
              :key="it.type + it.id"
              class="bg-white rounded-xl border border-slate-200 p-3"
            >
              <div class="flex items-center justify-between">
                <span
                  class="text-[11px] font-medium px-2 py-0.5 rounded-full"
                  :style="{
                    background: TYPE_STYLE[it.type].bg,
                    color: TYPE_STYLE[it.type].fg,
                  }"
                >{{ t(TYPE_STYLE[it.type].key) }}</span>
                <span class="text-[11px] text-slate-400">
                  {{ relTime(it.occurredAt) }}
                </span>
              </div>
              <p class="text-sm font-medium mt-2">{{ it.title }}</p>
              <p v-if="it.subtitle" class="text-xs text-slate-500 mt-1">
                {{ it.subtitle }}
              </p>
            </div>
          </div>
        </section>
      </div>
    </AsyncView>
  </div>
</template>
