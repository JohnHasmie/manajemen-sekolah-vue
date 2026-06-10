<!--
  TutorMaterialsView — list / create / delete bahan ajar.

  Tutor pastes a share link (drive / dropbox / direct file host)
  rather than uploading inline — there's no MinIO put flow yet.
  Published-at toggle controls draft vs visible-to-siswa.
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
    toast.error(e instanceof Error ? e.message : 'Gagal memuat bahan ajar.');
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
    toast.error('Pilih kelompok dulu.');
    return;
  }
  if (fTitle.value.trim().length < 3) {
    toast.error('Judul minimal 3 karakter.');
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
    toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.');
  } finally {
    saving.value = false;
  }
}

async function remove(m: TutoringMaterial) {
  if (!window.confirm(`Hapus "${m.title}"?`)) return;
  try {
    await TutoringService.deleteMaterial(m.id);
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menghapus.');
  }
}

const publishedCount = computed(
  () => rows.value.filter((m) => m.published_at).length,
);
const draftCount = computed(() => rows.value.length - publishedCount.value);

const kpiCards = computed<KpiCard[]>(() => [
  {
    icon: 'book',
    label: 'Total materi',
    value: rows.value.length,
    tone: 'brand',
    accented: true,
  },
  {
    icon: 'check-circle',
    label: 'Terbit',
    value: publishedCount.value,
    tone: 'green',
  },
  {
    icon: 'edit',
    label: 'Draft',
    value: draftCount.value,
    tone: draftCount.value > 0 ? 'amber' : 'slate',
  },
]);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="guru"
      kicker="Bimbel · Materi"
      title="Bahan Ajar"
      :meta="`${rows.length} materi · ${publishedCount} terbit`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white text-role-teacher text-[12px] font-bold hover:bg-white/90"
        @click="openCreate"
      >
        <NavIcon name="plus" :size="13" />
        Materi
      </button>
    </BrandPageHeader>

    <KpiStripCards v-if="!loading" :cards="kpiCards" :lg-cols="3" />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      text="Belum ada bahan ajar. Klik &quot;+ Materi&quot; untuk menambahkan PDF / link."
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
            ? 'Terbit ' + formatDateShort(m.published_at)
            : 'Draft',
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
              class="p-1.5 rounded-lg text-role-teacher hover:bg-status-info-soft"
              title="Buka file"
              @click.stop
            >
              <NavIcon name="external-link" :size="14" />
            </a>
            <button
              type="button"
              class="p-1.5 rounded-lg text-status-danger hover:bg-status-danger-soft"
              title="Hapus"
              @click.stop="remove(m)"
            >
              <NavIcon name="trash-2" :size="14" />
            </button>
          </span>
        </template>
      </TutoringListTile>
    </div>

    <Modal v-if="showCreate" title="Bahan Ajar Baru" @close="showCreate = false">
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Kelompok
          </span>
          <select
            v-model="fGroupId"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option value="" disabled>Pilih kelompok</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Judul
          </span>
          <input
            v-model="fTitle"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            placeholder="cth. Ringkasan Trigonometri"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Deskripsi (opsional)
          </span>
          <textarea
            v-model="fDesc"
            rows="3"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher resize-none"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            URL file / link (opsional)
          </span>
          <input
            v-model="fUrl"
            type="url"
            placeholder="https://drive.google.com/…"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
        <label class="flex items-center gap-2">
          <input
            v-model="fPublish"
            type="checkbox"
            class="h-4 w-4 accent-role-teacher"
          />
          <span class="text-sm text-slate-700">
            Terbitkan sekarang (mati = draft)
          </span>
        </label>

        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
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
            {{ saving ? t('tutoring.common.saving') : 'Simpan' }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
