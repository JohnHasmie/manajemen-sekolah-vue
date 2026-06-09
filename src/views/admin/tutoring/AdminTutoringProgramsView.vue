<!--
  AdminTutoringProgramsView — list bimbel programs (package/group
  counts), inline form to create, row delete with FK-restrict toast.
  Rebuilt on the tutoring shared components.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringProgram } from '@/types/tutoring';

import TutoringPageHeader from '@/components/feature/tutoring/TutoringPageHeader.vue';
import TutoringFlowTag from '@/components/feature/tutoring/TutoringFlowTag.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();
const router = useRouter();

const loading = ref(true);
const error = ref<string | null>(null);
const programs = ref<TutoringProgram[]>([]);

const showForm = ref(false);
const saving = ref(false);
const form = ref({ name: '', target_education_level: '', description: '' });

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
  if (!window.confirm(t('tutoring.programs.confirmDelete', { name: p.name })))
    return;
  try {
    await TutoringService.deleteProgram(p.id);
    toast.success(t('tutoring.programs.deleted'));
    await load();
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

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-3xl p-4 sm:p-6">
    <TutoringPageHeader
      :title="t('tutoring.programs.title')"
      crumbs="Bimbel · Program"
    >
      <template #right>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-role-admin hover:bg-role-admin/90 text-white rounded-xl px-3.5 py-2 text-sm font-semibold"
          @click="showForm = !showForm"
        >
          <NavIcon name="plus" :size="14" />
          {{ showForm ? t('tutoring.common.close') : t('tutoring.programs.addBtn') }}
        </button>
      </template>
    </TutoringPageHeader>

    <TutoringFlowTag
      class="mb-3"
      text="Setup katalog: Program → Paket → Kelompok"
    />

    <!-- Create form -->
    <section
      v-if="showForm"
      class="mb-4 space-y-2.5 bg-white border border-slate-100 rounded-2xl p-4"
    >
      <input
        v-model="form.name"
        :placeholder="t('tutoring.programs.namePh')"
        class="w-full rounded-lg border border-slate-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
      />
      <input
        v-model="form.target_education_level"
        :placeholder="t('tutoring.programs.levelPh')"
        class="w-full rounded-lg border border-slate-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
      />
      <textarea
        v-model="form.description"
        :placeholder="t('tutoring.programs.descPh')"
        rows="2"
        class="w-full rounded-lg border border-slate-200 px-3 py-2 focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
      />
      <button
        :disabled="saving"
        class="rounded-lg bg-role-admin hover:bg-role-admin/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
        @click="create"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.common.save') }}
      </button>
    </section>

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="error"
      :text="error"
      icon="alert-circle"
    />
    <TutoringEmpty
      v-else-if="programs.length === 0"
      :text="t('tutoring.programs.empty')"
      icon="layers"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="p in programs"
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
            class="p-1.5 rounded-lg text-status-danger hover:bg-status-danger-soft"
            :title="t('tutoring.programs.delete')"
            @click.stop="remove(p)"
          >
            <NavIcon name="trash-2" :size="16" />
          </button>
        </template>
      </TutoringListTile>
    </div>
  </div>
</template>
