<!--
  The "Kelas" list (teacher web) — SUBJECT-LEVEL. One card per (class × subject)
  the guru teaches, plus a general all-subjects card for a wali kelas. Grouped
  Kelas wali / Kelas ajar with a Semua / Wali / Mengajar filter; a card opens
  the hub scoped to that card. Mirrors the mobile ClassHubListScreen.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useRoleColor } from '@/composables/useRoleColor';
import { ClassHubService } from '@/services/class-hub.service';
import {
  classCardKey,
  isGeneralCard,
  isSubjectScoped,
  type ClassCard,
} from '@/types/class-hub';

const { t } = useI18n();
const router = useRouter();
const role = useRoleColor(() => 'guru');

type Filter = 'all' | 'wali' | 'mengajar';

const loading = ref(true);
const error = ref<string | null>(null);
const classes = ref<ClassCard[]>([]);
const filter = ref<Filter>('all');

async function load() {
  loading.value = true;
  error.value = null;
  try {
    classes.value = await ClassHubService.myClasses();
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e);
  } finally {
    loading.value = false;
  }
}
onMounted(load);

const filtered = computed(() =>
  classes.value.filter((c) => {
    if (filter.value === 'wali') return c.isHomeroom;
    if (filter.value === 'mengajar') return c.scope === 'subject';
    return true;
  }),
);

// Kelas wali = every card of a homeroom class (general + subjects); Kelas ajar
// = subject cards of non-homeroom classes.
const sections = computed(() => {
  const out: { label: string; cards: ClassCard[] }[] = [];
  const wali = filtered.value.filter((c) => c.isHomeroom);
  const ajar = filtered.value.filter((c) => !c.isHomeroom);
  if (wali.length) out.push({ label: t('classHub.groupHomeroom'), cards: wali });
  if (ajar.length) out.push({ label: t('classHub.groupTeaching'), cards: ajar });
  return out;
});

const state = computed(() => {
  if (loading.value) return { status: 'loading' as const };
  if (error.value) return { status: 'error' as const, error: error.value };
  if (filtered.value.length === 0) return { status: 'empty' as const };
  return { status: 'content' as const };
});

const filters: { key: Filter; labelKey: string }[] = [
  { key: 'all', labelKey: 'classHub.filterAll' },
  { key: 'wali', labelKey: 'classHub.filterHomeroom' },
  { key: 'mengajar', labelKey: 'classHub.filterTeaching' },
];
const filterOptions = computed(() =>
  filters.map((f) => ({ key: f.key, label: t(f.labelKey) })),
);

function shortClass(name: string): string {
  return name.toLowerCase().startsWith('kelas ') ? name.slice(6).trim() : name;
}
function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
function cardTitle(c: ClassCard): string {
  return isSubjectScoped(c)
    ? `${c.subjectName ?? c.name} · ${shortClass(c.name)}`
    : c.name;
}
function cardSubtitle(c: ClassCard): string {
  if (isGeneralCard(c)) {
    return `${t('classHub.allSubjects')} · ${c.studentCount} ${t('classHub.kpiStudents')}`;
  }
  return `${c.studentCount} ${t('classHub.kpiStudents')} · ${t('classHub.youTeach')}`;
}

function openClass(c: ClassCard) {
  router.push({
    name: 'teacher.classes.detail',
    params: { id: c.id },
    query: c.subjectId ? { subject_id: c.subjectId } : {},
  });
}
</script>

<template>
  <div class="p-4 md:p-6">
    <BrandPageHeader
      role="guru"
      :title="t('classHub.title')"
      :meta="t('classHub.listSubtitle')"
      class="mb-4"
    />

    <div class="mb-4">
      <SegmentedControl
        :model-value="filter"
        :options="filterOptions"
        @update:model-value="filter = $event as Filter"
      />
    </div>

    <AsyncView
      :state="state"
      :empty-title="t('classHub.emptyListTitle')"
      :empty-description="t('classHub.emptyListMsg')"
    >
      <div class="space-y-6">
        <section v-for="s in sections" :key="s.label">
          <h2 class="text-xs font-medium text-slate-500 mb-2">{{ s.label }}</h2>
          <div class="space-y-2.5">
            <button
              v-for="c in s.cards"
              :key="classCardKey(c)"
              type="button"
              class="w-full text-left bg-white rounded-xl border border-slate-200 p-3 flex items-center gap-3 hover:border-slate-300"
              @click="openClass(c)"
            >
              <span
                class="w-11 h-11 rounded-xl flex items-center justify-center font-medium shrink-0"
                :style="{ backgroundColor: role.hex + '26', color: role.hex }"
              >{{ initials(shortClass(c.name)) }}</span>
              <span class="flex-1 min-w-0">
                <span class="block text-sm font-medium">{{ cardTitle(c) }}</span>
                <span class="block text-xs text-slate-500">
                  {{ cardSubtitle(c) }}
                </span>
                <span class="flex flex-wrap gap-1.5 mt-1.5">
                  <template v-if="isGeneralCard(c)">
                    <StatusBadge :label="t('classHub.roleHomeroom')" tone="info" />
                    <StatusBadge :label="t('classHub.viewOnly')" tone="neutral" />
                  </template>
                  <template v-else>
                    <StatusBadge :label="t('classHub.roleSubject')" tone="neutral" />
                    <StatusBadge
                      v-if="c.activeTugas > 0"
                      :label="`${c.activeTugas} ${t('classHub.kpiActiveAssignments')}`"
                      tone="warning"
                    />
                    <StatusBadge
                      v-if="c.needsGrading > 0"
                      :label="`${c.needsGrading} ${t('classHub.kpiNeedsGrading')}`"
                      tone="danger"
                    />
                  </template>
                </span>
              </span>
              <span class="text-slate-300">›</span>
            </button>
          </div>
        </section>
      </div>
    </AsyncView>
  </div>
</template>
