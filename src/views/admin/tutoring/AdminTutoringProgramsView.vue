<!--
  AdminTutoringProgramsView — list bimbel programs (package/group
  counts) with inline create form. Uses the BrandPageHeader +
  KpiStripCards + PageFilterToolbar chrome.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import type { TutoringProgram } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

type Filter = 'all' | 'active' | 'empty';

const { t } = useI18n();
const toast = useToast();
const { confirm } = useConfirm();
const router = useRouter();

const loading = ref(true);
const error = ref<string | null>(null);
const programs = ref<TutoringProgram[]>([]);
const search = ref('');

const showForm = ref(false);
const saving = ref(false);
const form = ref({ name: '', target_education_level: '', description: '' });

const filter = ref<Filter>('all');
const showFilterPicker = ref(false);

const FILTER_OPTIONS = computed<{ key: Filter; label: string }[]>(() => [
  { key: 'all', label: t('admin.bimbel.programs.filter_all') },
  { key: 'active', label: t('admin.bimbel.programs.filter_active') },
  { key: 'empty', label: t('admin.bimbel.programs.filter_empty') },
]);

const activeFilterLabel = computed(
  () => FILTER_OPTIONS.value.find((o) => o.key === filter.value)?.label ?? t('admin.bimbel.programs.filter_all'),
);

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  return programs.value.filter((p) => {
    if (filter.value === 'active' && (p.packages_count ?? 0) === 0) return false;
    if (filter.value === 'empty' && (p.packages_count ?? 0) > 0) return false;
    if (q && !p.name.toLowerCase().includes(q)) return false;
    return true;
  });
});

async function load() {
  loading.value = true;
  error.value = null;
  try {
    programs.value = await TutoringService.getPrograms();
  } catch (e) {
    error.value =
      e instanceof Error ? e.message : t('tutoring.programs.loadFailed');
  } finally {
    loading.value = false;
  }
}

async function create() {
  if (form.value.name.trim().length < 3) {
    toast.error(t('tutoring.programs.nameTooShort'));
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createProgram({
      name: form.value.name.trim(),
      target_education_level:
        form.value.target_education_level.trim() || undefined,
      description: form.value.description.trim() || undefined,
    });
    toast.success(t('tutoring.programs.created'));
    showForm.value = false;
    form.value = { name: '', target_education_level: '', description: '' };
    await load();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.programs.createFailed'),
    );
  } finally {
    saving.value = false;
  }
}

async function remove(p: TutoringProgram) {
  if (
    !(await confirm({
      message: t('tutoring.programs.confirmDelete', { name: p.name }),
      danger: true,
      confirmLabel: t('common.delete'),
    }))
  )
    return;
  // Snapshot the fields the createProgram payload needs — anything
  // computed / server-owned (id, packages_count, groups_count) is
  // discarded so the restore lands as a fresh row.
  const snapshot = {
    name: p.name,
    description: p.description ?? undefined,
    target_education_level: p.target_education_level ?? undefined,
  };
  try {
    await TutoringService.deleteProgram(p.id);
    await load();
    toast.undoable(t('tutoring.programs.deleted'), async () => {
      try {
        await TutoringService.createProgram(snapshot);
        await load();
        toast.success(t('tutoring.programs.restored'));
      } catch (e) {
        toast.error(
          e instanceof Error
            ? `${t('tutoring.programs.restoreFailed')}: ${e.message}`
            : t('tutoring.programs.restoreFailed'),
        );
      }
    });
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.programs.deleteFailed'),
    );
  }
}

function openDetail(p: TutoringProgram) {
  router.push({
    name: 'admin.tutoring.program-detail',
    params: { programId: p.id },
    query: { name: p.name },
  });
}

function pickFilter(k: Filter) {
  filter.value = k;
  showFilterPicker.value = false;
}

const totalPackages = computed(
  () => programs.value.reduce((s, p) => s + (p.packages_count ?? 0), 0),
);
const totalGroups = computed(
  () => programs.value.reduce((s, p) => s + (p.groups_count ?? 0), 0),
);
const emptyPrograms = computed(
  () => programs.value.filter((p) => (p.packages_count ?? 0) === 0).length,
);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'layers',
    label: t('tutoring.programs.title'),
    value: programs.value.length,
    suffix: 'program',
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'package',
    label: t('tutoring.programs.packages'),
    value: totalPackages.value,
    tone: 'violet',
  },
  {
    icon: 'users',
    label: t('tutoring.programs.groups'),
    value: totalGroups.value,
    tone: 'green',
  },
  {
    icon: 'alert-circle',
    label: t('admin.bimbel.programs.kpi_empty'),
    value: emptyPrograms.value,
    tone: emptyPrograms.value > 0 ? 'amber' : 'slate',
  },
]);

onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.bimbel.programs.kicker')"
      :title="t('tutoring.programs.title')"
      :meta="t('admin.bimbel.programs.meta', { programs: programs.length, packages: totalPackages, groups: totalGroups })"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-tutoring-panel text-tutoring-accent text-[13px] font-bold hover:bg-tutoring-panel/90"
        @click="showForm = !showForm"
      >
        <NavIcon name="plus" :size="13" />
        {{ showForm ? t('tutoring.common.close') : t('tutoring.programs.addBtn') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards :cards="kpiCards" :loading="loading" />

    <PageFilterToolbar
      :search="search"
      :search-placeholder="t('admin.bimbel.programs.search_ph')"
      @update:search="(v: string) => (search = v)"
    >
      <template #chips>
        <AppFilterChip
          :label="t('admin.bimbel.programs.filter_status')"
          :value="activeFilterLabel"
          icon-name="layers"
          tone="violet"
          @click="showFilterPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <!-- Create form -->
    <section
      v-if="showForm"
      class="space-y-2.5 bg-tutoring-panel border border-tutoring-border-soft rounded-2xl p-4"
    >
      <input
        v-model="form.name"
        :placeholder="t('tutoring.programs.namePh')"
        class="w-full rounded-lg border border-tutoring-border px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
      />
      <input
        v-model="form.target_education_level"
        :placeholder="t('tutoring.programs.levelPh')"
        class="w-full rounded-lg border border-tutoring-border px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
      />
      <textarea
        v-model="form.description"
        :placeholder="t('tutoring.programs.descPh')"
        rows="2"
        class="w-full rounded-lg border border-tutoring-border px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-tutoring-accent"
      />
      <button
        :disabled="saving"
        class="rounded-lg bg-tutoring-accent hover:opacity-90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        @click="create"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.common.save') }}
      </button>
    </section>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty v-else-if="error" :text="error" icon="alert-circle" />
    <TutoringEmpty
      v-else-if="filtered.length === 0"
      :text="t('tutoring.programs.empty')"
      icon="layers"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="p in filtered"
        :key="p.id"
        icon="layers"
        :title="p.name"
        :subtitle="
          [
            p.target_education_level,
            (p.packages_count ?? 0) + ' ' + t('tutoring.programs.packages'),
            (p.groups_count ?? 0) + ' ' + t('tutoring.programs.groups'),
          ]
            .filter(Boolean)
            .join(' · ')
        "
        :to="() => openDetail(p)"
      >
        <template #trailing>
          <button
            type="button"
            class="p-1.5 rounded-lg text-tutoring-red hover:bg-tutoring-red-soft"
            :title="t('tutoring.programs.delete')"
            @click.stop="remove(p)"
          >
            <NavIcon name="trash-2" :size="16" />
          </button>
        </template>
      </TutoringListTile>
    </div>

    <Modal
      v-if="showFilterPicker"
      :title="t('admin.bimbel.programs.filter_modal')"
      @close="showFilterPicker = false"
    >
      <ul class="space-y-1">
        <li v-for="o in FILTER_OPTIONS" :key="o.key">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-tutoring-bg"
            :class="{ 'bg-tutoring-accent/5 text-tutoring-accent font-bold': filter === o.key }"
            @click="pickFilter(o.key)"
          >
            {{ o.label }}
          </button>
        </li>
      </ul>
    </Modal>
  </div>
</template>
