<!--
  AdminTutoringGroupAnnouncementsView — also used by tutors (same
  role gate as other admin tutoring tooling). Pass ?group_id= to
  scope to one kelompok; without it, lists all tenant announcements.

  Header CTA opens a compose modal; row trailing action deletes.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type {
  TutoringGroup,
  TutoringGroupAnnouncement,
} from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringListTile from '@/components/feature/tutoring/TutoringListTile.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const toast = useToast();

const initialGroupId = String(route.query.groupId ?? '');
const groupId = ref<string>(initialGroupId);
const groups = ref<TutoringGroup[]>([]);
const rows = ref<TutoringGroupAnnouncement[]>([]);
const loading = ref(true);

const showGroupPicker = ref(false);
const showCompose = ref(false);
const fGroupId = ref('');
const fTitle = ref('');
const fBody = ref('');
const saving = ref(false);

const activeGroupLabel = computed(() => {
  if (!groupId.value) return 'Semua kelompok';
  return groups.value.find((g) => g.id === groupId.value)?.name ?? '—';
});

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getGroupAnnouncements(
      groupId.value ? { group_id: groupId.value } : {},
    );
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat pengumuman.');
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  try {
    groups.value = await TutoringService.getAllGroups();
  } catch {/* non-fatal */}
  await load();
});

function pickGroup(id: string) {
  groupId.value = id;
  showGroupPicker.value = false;
  load();
}

function openCompose() {
  fGroupId.value = groupId.value || groups.value[0]?.id || '';
  fTitle.value = '';
  fBody.value = '';
  showCompose.value = true;
}

async function submitCompose() {
  if (!fGroupId.value) {
    toast.error('Pilih kelompok dulu.');
    return;
  }
  if (fTitle.value.trim().length < 3 || fBody.value.trim().length < 3) {
    toast.error('Judul + isi minimal 3 karakter.');
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createGroupAnnouncement({
      tutoring_group_id: fGroupId.value,
      title: fTitle.value.trim(),
      body: fBody.value.trim(),
    });
    showCompose.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menerbitkan.');
  } finally {
    saving.value = false;
  }
}

async function remove(a: TutoringGroupAnnouncement) {
  if (!window.confirm(`Hapus "${a.title}"?`)) return;
  try {
    await TutoringService.deleteGroupAnnouncement(a.id);
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menghapus.');
  }
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Pengumuman Kelompok"
      title="Pengumuman"
      :meta="`${rows.length} pengumuman${groupId ? ' di kelompok ini' : ''}`"
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white text-role-admin text-[12px] font-bold hover:bg-white/90"
        @click="openCompose"
      >
        <NavIcon name="plus" :size="13" />
        Tulis
      </button>
    </BrandPageHeader>

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          label="Kelompok"
          :value="activeGroupLabel"
          icon-name="users"
          tone="violet"
          @click="showGroupPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="rows.length === 0"
      text="Belum ada pengumuman. Klik &quot;+ Tulis&quot; untuk membuat baru."
      icon="megaphone"
    />
    <div v-else class="space-y-2">
      <article
        v-for="a in rows"
        :key="a.id"
        class="bg-white border border-slate-100 rounded-2xl p-4"
      >
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <h3 class="text-sm font-extrabold text-slate-900 tracking-tight">
              {{ a.title }}
            </h3>
            <p class="text-[11px] text-slate-500 mt-0.5">
              {{ a.group_name ?? '—' }}
              <template v-if="a.author_name">· oleh {{ a.author_name }}</template>
              <template v-if="a.created_at">· {{ formatDateShort(a.created_at) }}</template>
            </p>
          </div>
          <button
            type="button"
            class="p-1.5 rounded-lg text-slate-400 hover:text-status-danger hover:bg-status-danger-soft"
            title="Hapus"
            @click="remove(a)"
          >
            <NavIcon name="trash-2" :size="14" />
          </button>
        </div>
        <p class="text-sm text-slate-700 mt-2 whitespace-pre-wrap">
          {{ a.body }}
        </p>
      </article>
    </div>

    <Modal v-if="showGroupPicker" title="Filter Kelompok" @close="showGroupPicker = false">
      <ul class="space-y-1">
        <li>
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': groupId === '' }"
            @click="pickGroup('')"
          >
            Semua kelompok
          </button>
        </li>
        <li v-for="g in groups" :key="g.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-slate-50"
            :class="{ 'bg-role-admin/5 text-role-admin font-bold': groupId === g.id }"
            @click="pickGroup(g.id)"
          >
            {{ g.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <Modal v-if="showCompose" title="Pengumuman Baru" @close="showCompose = false">
      <div class="space-y-3">
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Kelompok
          </span>
          <select
            v-model="fGroupId"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
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
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Isi
          </span>
          <textarea
            v-model="fBody"
            rows="6"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/20 focus:border-role-admin resize-none"
          />
        </label>
        <div class="flex items-center gap-2 justify-end pt-2">
          <button
            type="button"
            class="rounded-lg px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
            @click="showCompose = false"
          >
            {{ t('tutoring.common.close') }}
          </button>
          <button
            type="button"
            :disabled="saving"
            class="rounded-lg bg-role-admin hover:bg-role-admin/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
            @click="submitCompose"
          >
            {{ saving ? t('tutoring.common.saving') : 'Terbitkan' }}
          </button>
        </div>
      </div>
    </Modal>
  </div>
</template>
