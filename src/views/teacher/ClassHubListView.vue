<!--
  The "Kelas" list — class-first entry for the teacher web app.
  Guru sees their classes grouped into Kelas wali / Kelas ajar with a role
  badge each and a Semua / Wali kelas / Mengajar filter. A card opens the hub.
  Mirrors the mobile ClassHubListScreen; parent (child-scoped) support is a
  follow-up.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import { useRoleColor } from '@/composables/useRoleColor';
import { ClassHubService } from '@/services/class-hub.service';
import type { ClassCard } from '@/types/class-hub';

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
    if (filter.value === 'mengajar') return c.isTeaching;
    return true;
  }),
);
const waliClasses = computed(() =>
  filtered.value.filter((c) => c.isHomeroom),
);
const ajarClasses = computed(() =>
  filtered.value.filter((c) => c.isTeaching && !c.isHomeroom),
);

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

function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

function openClass(c: ClassCard) {
  router.push({ name: 'teacher.classes.detail', params: { id: c.id } });
}
</script>

<template>
  <div class="p-4 md:p-6">
    <header
      class="rounded-2xl px-5 py-4 mb-4"
      :style="{ backgroundColor: role.hex + '1A' }"
    >
      <h1 class="text-lg font-medium" :style="{ color: role.hex }">
        {{ t('classHub.title') }}
      </h1>
      <p class="text-sm text-slate-500">{{ t('classHub.listSubtitle') }}</p>
    </header>

    <div class="flex gap-2 mb-4">
      <button
        v-for="f in filters"
        :key="f.key"
        type="button"
        class="text-xs px-3 py-1.5 rounded-full border transition"
        :class="
          filter === f.key
            ? 'text-white border-transparent'
            : 'text-slate-600 border-slate-300 bg-white'
        "
        :style="filter === f.key ? { backgroundColor: role.hex } : {}"
        @click="filter = f.key"
      >
        {{ t(f.labelKey) }}
      </button>
    </div>

    <AsyncView
      :state="state"
      :empty-title="t('classHub.emptyListTitle')"
      :empty-description="t('classHub.emptyListMsg')"
    >
      <div class="space-y-6">
        <section v-if="waliClasses.length">
          <h2 class="text-xs font-medium text-slate-500 mb-2">
            {{ t('classHub.groupHomeroom') }}
          </h2>
          <div class="space-y-2.5">
            <button
              v-for="c in waliClasses"
              :key="c.id"
              type="button"
              class="w-full text-left bg-white rounded-xl border border-slate-200 p-3 flex items-center gap-3 hover:border-slate-300"
              @click="openClass(c)"
            >
              <span
                class="w-11 h-11 rounded-xl flex items-center justify-center font-medium shrink-0"
                :style="{ backgroundColor: role.hex + '26', color: role.hex }"
              >{{ initials(c.name) }}</span>
              <span class="flex-1 min-w-0">
                <span class="block text-sm font-medium">{{ c.name }}</span>
                <span class="block text-xs text-slate-500">
                  {{ c.studentCount }} {{ t('classHub.kpiStudents') }}
                </span>
                <span class="flex flex-wrap gap-1.5 mt-1.5">
                  <span
                    class="text-[11px] font-medium px-2 py-0.5 rounded-full text-white"
                    :style="{ backgroundColor: role.hex }"
                  >{{ t('classHub.roleHomeroom') }}</span>
                  <span
                    v-if="c.activeTugas > 0"
                    class="text-[11px] font-medium px-2 py-0.5 rounded-full"
                    style="background:#FAEEDA;color:#854F0B"
                  >{{ c.activeTugas }} {{ t('classHub.kpiActiveAssignments') }}</span>
                  <span
                    v-if="c.needsGrading > 0"
                    class="text-[11px] font-medium px-2 py-0.5 rounded-full"
                    style="background:#FCEBEB;color:#791F1F"
                  >{{ c.needsGrading }} {{ t('classHub.kpiNeedsGrading') }}</span>
                </span>
              </span>
              <span class="text-slate-300">›</span>
            </button>
          </div>
        </section>

        <section v-if="ajarClasses.length">
          <h2 class="text-xs font-medium text-slate-500 mb-2">
            {{ t('classHub.groupTeaching') }}
          </h2>
          <div class="space-y-2.5">
            <button
              v-for="c in ajarClasses"
              :key="c.id"
              type="button"
              class="w-full text-left bg-white rounded-xl border border-slate-200 p-3 flex items-center gap-3 hover:border-slate-300"
              @click="openClass(c)"
            >
              <span
                class="w-11 h-11 rounded-xl flex items-center justify-center font-medium shrink-0"
                :style="{ backgroundColor: role.hex + '26', color: role.hex }"
              >{{ initials(c.name) }}</span>
              <span class="flex-1 min-w-0">
                <span class="block text-sm font-medium">{{ c.name }}</span>
                <span class="block text-xs text-slate-500">
                  {{ c.studentCount }} {{ t('classHub.kpiStudents') }}
                </span>
                <span class="flex flex-wrap gap-1.5 mt-1.5">
                  <span
                    class="text-[11px] font-medium px-2 py-0.5 rounded-full"
                    :style="{ backgroundColor: role.hex + '1F', color: role.hex }"
                  >{{ t('classHub.roleSubject') }}</span>
                  <span
                    v-if="c.needsGrading > 0"
                    class="text-[11px] font-medium px-2 py-0.5 rounded-full"
                    style="background:#FCEBEB;color:#791F1F"
                  >{{ c.needsGrading }} {{ t('classHub.kpiNeedsGrading') }}</span>
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
