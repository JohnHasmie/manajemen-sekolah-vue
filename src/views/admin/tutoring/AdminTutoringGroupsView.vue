<!--
  AdminTutoringGroupsView — list of all group in this tenant with
  full CRUD (create + edit + delete + assign tutor) per card.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringGroup, TutoringProgram, TutoringTutorRow } from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminActionMenu from '@/components/feature/tutoring/AdminActionMenu.vue';
import AdminConfirmDialog from '@/components/feature/tutoring/AdminConfirmDialog.vue';

const router = useRouter();
const toast = useToast();
const { t } = useI18n();

const loading = ref(true);
const groups = ref<TutoringGroup[]>([]);
const programs = ref<TutoringProgram[]>([]);
const tutors = ref<TutoringTutorRow[]>([]);
const query = ref('');
const status = ref<'all' | 'active' | 'full' | 'closed'>('all');

type ModalKind = null | 'create' | 'edit' | 'assign' | 'delete';
const modal = ref<ModalKind>(null);
const target = ref<TutoringGroup | null>(null);
const saving = ref(false);

const form = ref({ name: '', capacity: 10, program_id: '', tutor_user_id: '' });

async function load() {
  loading.value = true;
  try {
    [groups.value, programs.value, tutors.value] = await Promise.all([
      TutoringService.getAllGroups(),
      TutoringService.getPrograms(),
      TutoringService.getAdminTutors(),
    ]);
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

const filtered = computed(() => {
  let list = groups.value;
  if (status.value === 'active') list = list.filter((g) => /active|aktif|open/i.test(g.status));
  if (status.value === 'full') list = list.filter((g) => (g.enrollments_count ?? 0) >= g.capacity);
  if (status.value === 'closed') list = list.filter((g) => /closed|selesai/i.test(g.status));
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((g) => g.name.toLowerCase().includes(q));
  return list;
});

const needsAttention = computed(() => groups.value.filter((g) => !g.tutor_user_id).length);

function programNameFor(g: TutoringGroup): string {
  return programs.value.find((p) => p.id === g.program_id)?.name ?? '—';
}

function openCreate() {
  target.value = null;
  form.value = { name: '', capacity: 10, program_id: programs.value[0]?.id ?? '', tutor_user_id: '' };
  modal.value = 'create';
}

function pickAction(g: TutoringGroup, key: string) {
  target.value = g;
  if (key === 'edit') {
    form.value = { name: g.name, capacity: g.capacity, program_id: g.program_id, tutor_user_id: '' };
    modal.value = 'edit';
  } else if (key === 'assign') {
    form.value = { ...form.value, tutor_user_id: g.tutor_user_id ?? '' };
    modal.value = 'assign';
  } else if (key === 'delete') {
    modal.value = 'delete';
  } else if (key === 'open') {
    router.push({ name: 'admin.tutoring.group-detail', params: { groupId: g.id } });
  }
}

async function submitCreate() {
  if (form.value.name.trim().length < 3) { toast.error(t('admin.bimbel.groups.name_too_short')); return; }
  if (!form.value.program_id) { toast.error(t('admin.bimbel.groups.pick_program')); return; }
  saving.value = true;
  try {
    await TutoringService.createGroup({
      program_id: form.value.program_id,
      name: form.value.name.trim(),
      capacity: form.value.capacity,
      tutor_user_id: form.value.tutor_user_id || undefined,
    });
    toast.success(t('admin.bimbel.groups.created'));
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : t('admin.bimbel.groups.create_fail')); }
  finally { saving.value = false; }
}

async function submitEdit() {
  if (!target.value) return;
  if (form.value.name.trim().length < 3) { toast.error(t('admin.bimbel.groups.name_too_short')); return; }
  saving.value = true;
  try {
    await TutoringService.updateGroup(target.value.id, {
      name: form.value.name.trim(),
      capacity: form.value.capacity,
    });
    toast.success(t('admin.bimbel.groups.updated'));
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : t('admin.bimbel.groups.update_fail')); }
  finally { saving.value = false; }
}

async function submitAssign() {
  if (!target.value) return;
  saving.value = true;
  try {
    await TutoringService.assignGroupTutor(target.value.id, form.value.tutor_user_id || null);
    toast.success(t('admin.bimbel.groups.tutor_updated'));
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : t('admin.bimbel.groups.tutor_update_fail')); }
  finally { saving.value = false; }
}

async function submitDelete() {
  if (!target.value) return;
  saving.value = true;
  try {
    await TutoringService.deleteGroup(target.value.id);
    toast.success(t('admin.bimbel.groups.deleted'));
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : t('admin.bimbel.groups.delete_fail')); }
  finally { saving.value = false; }
}

function cardActions(g: TutoringGroup) {
  return [
    { key: 'open', label: t('admin.bimbel.groups.action_open'), icon: 'chevron-right' },
    { key: 'edit', label: t('admin.bimbel.groups.action_edit'), icon: 'edit' },
    { key: 'assign', label: g.tutor_user_id ? t('admin.bimbel.groups.action_assign_change') : t('admin.bimbel.groups.action_assign_new'), icon: 'user-check' },
    { key: 'delete', label: t('admin.bimbel.groups.action_delete'), icon: 'trash-2', danger: true },
  ];
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('admin.bimbel.groups.hero_kicker')"
      :title="t('admin.bimbel.groups.hero_title')"
      :subtitle="t('admin.bimbel.groups.hero_subtitle', { total: groups.length, needs: needsAttention })"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-tutoring-accent px-3 py-1.5 text-[14px] font-bold hover:opacity-90"
          @click="openCreate"
        >
          <NavIcon name="plus" :size="13" class="inline -mt-0.5" /> {{ t('admin.bimbel.groups.create') }}
        </button>
      </template>
    </TutorHomeHero>

    <div class="flex flex-wrap items-center gap-2">
      <div class="relative min-w-0 flex-1">
        <NavIcon name="search" :size="14" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-tutoring-text-lo" />
        <input
          v-model="query"
          type="text"
          :placeholder="t('admin.bimbel.groups.search_ph')"
          class="w-full rounded-xl border border-tutoring-border bg-tutoring-panel pl-9 pr-3 py-2 text-[14px] text-tutoring-text-hi placeholder:text-tutoring-text-lo focus:border-tutoring-accent focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all' as const, label: t('admin.bimbel.groups.filter_all') },
            { id: 'active' as const, label: t('admin.bimbel.groups.filter_active') },
            { id: 'full' as const, label: t('admin.bimbel.groups.filter_full') },
            { id: 'closed' as const, label: t('admin.bimbel.groups.filter_closed') },
          ]"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
          :class="status === opt.id ? 'border-tutoring-accent bg-tutoring-accent-dim text-tutoring-accent' : 'border-tutoring-border bg-tutoring-panel text-tutoring-text-mid'"
          @click="status = opt.id"
        >{{ opt.label }}</button>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.groups.loading') }}</div>

    <div v-else-if="filtered.length" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <div
        v-for="g in filtered"
        :key="g.id"
        class="group relative rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3.5 transition hover:border-tutoring-accent/40"
      >
        <div class="flex items-start justify-between gap-2">
          <button
            type="button"
            class="min-w-0 text-left flex-1"
            @click="router.push({ name: 'admin.tutoring.group-detail', params: { groupId: g.id } })"
          >
            <p class="text-[14px] font-bold text-tutoring-text-hi truncate">{{ g.name }}</p>
            <p class="text-[13px] text-tutoring-text-mid truncate">{{ programNameFor(g) }}</p>
          </button>
          <AdminActionMenu
            :items="cardActions(g)"
            :aria-label="t('admin.bimbel.groups.action_aria')"
            @pick="(k) => pickAction(g, k)"
          />
        </div>
        <div class="mt-2.5 flex items-center gap-2 text-[13px] text-tutoring-text-mid">
          <span class="inline-flex items-center gap-1">
            <NavIcon name="users" :size="12" /> {{ g.enrollments_count ?? 0 }} / {{ g.capacity }}
          </span>
          <span v-if="g.tutor?.name" class="inline-flex items-center gap-1 truncate">
            · <NavIcon name="user-check" :size="12" /> {{ g.tutor.name }}
          </span>
          <span v-else class="inline-flex items-center gap-1 rounded-md bg-amber-500/15 px-1.5 py-0.5 text-[12px] font-bold text-amber-700 dark:text-amber-300">
            <NavIcon name="alert-circle" :size="10" /> {{ t('admin.bimbel.groups.needs_tutor') }}
          </span>
        </div>
      </div>
    </div>

    <div v-else class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid">
      {{ t('admin.bimbel.groups.empty') }}
    </div>

    <!-- Create / Edit modal -->
    <div v-if="modal === 'create' || modal === 'edit'" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="modal = null">
      <div class="w-full max-w-md rounded-2xl bg-tutoring-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-tutoring-text-hi">
          {{ modal === 'create' ? t('admin.bimbel.groups.modal_create') : t('admin.bimbel.groups.modal_edit') }}
        </h3>
        <label v-if="modal === 'create'" class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.groups.field_program') }} <span class="text-rose-500">*</span></span>
          <select v-model="form.program_id" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none">
            <option v-for="p in programs" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.groups.field_name') }} <span class="text-rose-500">*</span></span>
          <input v-model="form.name" type="text" :placeholder="t('admin.bimbel.groups.name_ph')" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.groups.field_capacity') }}</span>
          <input v-model.number="form.capacity" type="number" min="1" max="100" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <label v-if="modal === 'create'" class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.groups.field_tutor_optional') }}</span>
          <select v-model="form.tutor_user_id" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none">
            <option value="">{{ t('admin.bimbel.groups.no_tutor_option') }}</option>
            <option v-for="tt in tutors" :key="tt.user_id" :value="tt.user_id">{{ tt.name }}</option>
          </select>
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft" @click="modal = null">{{ t('admin.bimbel.groups.cancel') }}</button>
          <button type="button" :disabled="saving" class="flex-1 rounded-lg bg-tutoring-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="modal === 'create' ? submitCreate() : submitEdit()">{{ saving ? t('admin.bimbel.groups.saving') : t('admin.bimbel.groups.save') }}</button>
        </div>
      </div>
    </div>

    <!-- Assign tutor modal -->
    <div v-if="modal === 'assign'" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="modal = null">
      <div class="w-full max-w-md rounded-2xl bg-tutoring-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.groups.modal_assign') }}</h3>
        <p class="text-[14px] text-tutoring-text-mid">{{ target?.name }}</p>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.groups.field_tutor') }}</span>
          <select v-model="form.tutor_user_id" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none">
            <option value="">{{ t('admin.bimbel.groups.no_tutor_option') }}</option>
            <option v-for="tt in tutors" :key="tt.user_id" :value="tt.user_id">{{ tt.name }}</option>
          </select>
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft" @click="modal = null">{{ t('admin.bimbel.groups.cancel') }}</button>
          <button type="button" :disabled="saving" class="flex-1 rounded-lg bg-tutoring-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="submitAssign">{{ saving ? t('admin.bimbel.groups.saving') : t('admin.bimbel.groups.save') }}</button>
        </div>
      </div>
    </div>

    <AdminConfirmDialog
      :open="modal === 'delete'"
      :title="t('admin.bimbel.groups.delete_title')"
      :message="t('admin.bimbel.groups.delete_message', { name: target?.name ?? '' })"
      :confirm-label="t('admin.bimbel.groups.delete_confirm')"
      danger
      :busy="saving"
      @cancel="modal = null"
      @confirm="submitDelete"
    />
  </div>
</template>
