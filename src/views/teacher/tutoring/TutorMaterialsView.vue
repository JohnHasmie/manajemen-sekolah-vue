<!--
  TutorMaterialsView — list / create / delete bahan ajar.

  Tutor pastes a share link (drive / dropbox / direct file host)
  rather than uploading inline — there's no MinIO put flow yet.
  Published-at toggle controls draft vs visible-to-student.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type { TutoringGroup, TutoringMaterial } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const rows = ref<TutoringMaterial[]>([]);
const groups = ref<TutoringGroup[]>([]);

const showCreate = ref(false);
const fGroupId = ref('');
const fTitle = ref('');
const fDesc = ref('');
const fUrl = ref('');
const fPublish = ref(true);
const saving = ref(false);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getMaterials();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutor.bimbel.materials.load_failed'));
  } finally {
    loading.value = false;
  }
}

async function loadGroups() {
  try {
    groups.value = await TutoringService.getAllGroups();
    if (!fGroupId.value && groups.value[0]) fGroupId.value = groups.value[0].id;
  } catch {/* non-fatal */}
}

onMounted(async () => {
  await Promise.all([load(), loadGroups()]);
});

function openCreate() {
  fTitle.value = '';
  fDesc.value = '';
  fUrl.value = '';
  fPublish.value = true;
  if (!fGroupId.value && groups.value[0]) fGroupId.value = groups.value[0].id;
  showCreate.value = true;
}

async function submit() {
  if (!fGroupId.value) {
    toast.error(t('tutor.bimbel.materials.err_pick_group'));
    return;
  }
  if (fTitle.value.trim().length < 3) {
    toast.error(t('tutor.bimbel.materials.err_title_short'));
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createMaterial({
      tutoring_group_id: fGroupId.value,
      title: fTitle.value.trim(),
      description: fDesc.value.trim() || undefined,
      file_url: fUrl.value.trim() || undefined,
      published_at: fPublish.value ? new Date().toISOString() : null,
    });
    showCreate.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutor.bimbel.materials.err_save_failed'));
  } finally {
    saving.value = false;
  }
}

async function remove(m: TutoringMaterial) {
  if (!window.confirm(t('tutor.bimbel.materials.delete_confirm', { title: m.title }))) return;
  try {
    await TutoringService.deleteMaterial(m.id);
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('tutor.bimbel.materials.err_delete_failed'));
  }
}

const publishedCount = computed(
  () => rows.value.filter((m) => m.published_at).length,
);
const draftCount = computed(() => rows.value.length - publishedCount.value);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'book',
    label: t('tutor.bimbel.materials.kpi_total'),
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: t('tutor.bimbel.materials.kpi_published'),
    value: publishedCount.value,
    tone: 'green',
  },
  {
    icon: 'edit',
    label: t('tutor.bimbel.materials.kpi_draft'),
    value: draftCount.value,
    tone: draftCount.value > 0 ? 'amber' : 'slate',
  },
]);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="guru"
      :kicker="t('tutor.bimbel.materials.kicker')"
      :title="t('tutor.bimbel.materials.title')"
      :meta="t('tutor.bimbel.materials.meta', { total: rows.length, published: publishedCount })"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-tutoring-panel text-tutoring-accent text-[13px] font-bold hover:bg-tutoring-panel/90"
        @click="openCreate"
      >
        <NavIcon name="plus" :size="13" />
        {{ t('tutor.bimbel.materials.add_btn') }}
      </button>
    </BrandPageHeader>

    <KpiStripCards v-if="!loading" :cards="kpiCards" :lg-cols="3" />

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('tutor.bimbel.materials.empty')"
      icon="book"
    />
    <div v-else class="space-y-2">
      <TutoringListTile
        v-for="m in rows"
        :key="m.id"
        icon="book"
        accent="tutor"
        :title="m.title"
        :subtitle="[
          m.group?.name ?? m.program?.name,
          m.subject?.name,
          m.published_at
            ? t('tutor.bimbel.materials.row_published_prefix') + ' ' + formatDateShort(m.published_at)
            : t('tutor.bimbel.materials.row_draft'),
          m.description,
        ].filter(Boolean).join(' · ')"
        :to="m.file_url ? () => window.open(m.file_url!, '_blank') : null"
      >
        <template #trailing>
          <span class="inline-flex items-center gap-1">
            <a
              v-if="m.file_url"
              :href="m.file_url"
              target="_blank"
              rel="noopener"
              class="p-1.5 rounded-lg text-tutoring-accent hover:bg-status-info-soft"
              :title="t('tutor.bimbel.materials.open_file_title')"
              @click.stop
            >
              <NavIcon name="external-link" :size="14" />
            </a>
            <button
              type="button"
              class="p-1.5 rounded-lg text-tutoring-red hover:bg-tutoring-red-soft"
              :title="t('tutor.bimbel.materials.delete_title')"
              @click.stop="remove(m)"
            >
              <NavIcon name="trash-2" :size="14" />
            </button>
          </span>
        </template>
      </TutoringListTile>
    </div>

    <Modal v-if="showCreate" :title="t('tutor.bimbel.materials.modal_title')" @close="showCreate = false">
      <div class="space-y-3">
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.materials.field_group') }}
          </span>
          <select
            v-model="fGroupId"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option value="" disabled>{{ t('tutor.bimbel.materials.field_group_placeholder') }}</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.materials.field_title') }}
          </span>
          <input
            v-model="fTitle"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            :placeholder="t('tutor.bimbel.materials.field_title_placeholder')"
          />
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.materials.field_description') }}
          </span>
          <textarea
            v-model="fDesc"
            rows="3"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher resize-none"
          />
        </label>
        <label class="block">
          <span class="text-[12px] font-bold text-tutoring-text-mid uppercase tracking-wider">
            {{ t('tutor.bimbel.materials.field_url') }}
          </span>
          <input
            v-model="fUrl"
            type="url"
            placeholder="https://drive.google.com/…"
            class="mt-1.5 w-full rounded-lg border border-tutoring-border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
        <label class="flex items-center gap-2">
          <input
            v-model="fPublish"
            type="checkbox"
            class="h-4 w-4 accent-role-teacher"
          />
          <span class="text-sm text-tutoring-text-mid">
            {{ t('tutor.bimbel.materials.publish_label') }}
          </span>
        </label>

        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-tutoring-text-mid hover:bg-tutoring-border-soft"
            @click="showCreate = false"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="submit"
          >
            {{ saving ? t('tutoring.common.saving') : t('tutor.bimbel.materials.submit') }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
