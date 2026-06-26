<!--
  AdminTutoringTutorsView — full rewrite per mockup
  admin_redesign_w1_people frame 2.

  Hero (navy) → search + status pill filter → grid 3-col of tutor
  cards with avatar, stars, and 3-cell KPI mini-row.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringTutorRow } from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import InviteTutorModal from '@/views/admin/tutoring/InviteTutorModal.vue';
import AdminActionMenu from '@/components/feature/tutoring/AdminActionMenu.vue';
import AdminConfirmDialog from '@/components/feature/tutoring/AdminConfirmDialog.vue';
import { useToast } from '@/composables/useToast';

const router = useRouter();
const toast = useToast();
const { t } = useI18n();

const loading = ref(true);
const rows = ref<TutoringTutorRow[]>([]);
const query = ref('');
const status = ref<'all' | 'ACTIVE' | 'PENDING'>('all');
const showInvite = ref(false);

const editTarget = ref<TutoringTutorRow | null>(null);
const editName = ref('');
const editBusy = ref(false);
const deactivateTarget = ref<TutoringTutorRow | null>(null);
const deactivateBusy = ref(false);

function pickAction(r: TutoringTutorRow, key: string) {
  if (key === 'open') goDetail(r);
  else if (key === 'edit') { editTarget.value = r; editName.value = r.name; }
  else if (key === 'deactivate') deactivateTarget.value = r;
}

async function submitEdit() {
  if (!editTarget.value) return;
  if (editName.value.trim().length < 2) { toast.error(t('admin.bimbel.tutors.name_min')); return; }
  editBusy.value = true;
  try {
    await TutoringService.updateTutor(editTarget.value.user_id, { name: editName.value.trim() });
    toast.success(t('admin.bimbel.tutors.edit_ok'));
    editTarget.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : t('admin.bimbel.tutors.edit_fail')); }
  finally { editBusy.value = false; }
}

async function confirmDeactivate() {
  if (!deactivateTarget.value) return;
  deactivateBusy.value = true;
  try {
    const r = await TutoringService.deactivateTutor(deactivateTarget.value.user_id);
    toast.success(r.groups_unassigned > 0
      ? t('admin.bimbel.tutors.deactivate_ok_groups', { count: r.groups_unassigned })
      : t('admin.bimbel.tutors.deactivate_ok'));
    deactivateTarget.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : t('admin.bimbel.tutors.deactivate_fail')); }
  finally { deactivateBusy.value = false; }
}

async function load() {
  loading.value = true;
  try { rows.value = await TutoringService.getAdminTutors(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

const filtered = computed(() => {
  let list = rows.value;
  if (status.value !== 'all') list = list.filter((r) => r.status === status.value);
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((r) => r.name.toLowerCase().includes(q) || r.email.toLowerCase().includes(q));
  return list;
});

const counts = computed(() => ({
  all: rows.value.length,
  active: rows.value.filter((r) => r.status === 'ACTIVE').length,
  pending: rows.value.filter((r) => r.status === 'PENDING').length,
}));

function initials(name: string): string {
  return name.split(/\s+/).slice(0, 2).map((s) => s[0]?.toUpperCase() ?? '').join('');
}

function studentsCount(r: TutoringTutorRow): number {
  return r.groups.length * 8;
}

function goDetail(r: TutoringTutorRow) {
  router.push({ name: 'admin.tutoring.tutor-detail', params: { userId: r.user_id } });
}

function onInvited() {
  showInvite.value = false;
  load();
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('admin.bimbel.tutors.hero_kicker')"
      :title="t('admin.bimbel.tutors.hero_title')"
      :subtitle="t('admin.bimbel.tutors.hero_subtitle', { active: counts.active, pending: counts.pending })"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-tutoring-accent px-3 py-1.5 text-[14px] font-bold"
          @click="showInvite = true"
        >
          <NavIcon name="mail" :size="13" class="inline -mt-0.5" /> {{ t('admin.bimbel.tutors.invite') }}
        </button>
      </template>
    </TutorHomeHero>

    <div class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1">
        <NavIcon name="search" :size="14" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-tutoring-text-lo" />
        <input
          v-model="query"
          type="text"
          :placeholder="t('admin.bimbel.tutors.search_ph')"
          class="w-full rounded-lg border border-tutoring-border bg-tutoring-bg pl-9 pr-3 py-1.5 text-[14px] text-tutoring-text-hi placeholder:text-tutoring-text-lo focus:border-tutoring-accent focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all' as const, label: t('admin.bimbel.tutors.filter_all', { count: counts.all }) },
            { id: 'ACTIVE' as const, label: t('admin.bimbel.tutors.filter_active', { count: counts.active }) },
            { id: 'PENDING' as const, label: t('admin.bimbel.tutors.filter_pending', { count: counts.pending }) },
          ]"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
          :class="status === opt.id ? 'border-tutoring-accent bg-tutoring-accent-dim text-tutoring-accent' : 'border-tutoring-border bg-tutoring-panel text-tutoring-text-mid'"
          @click="status = opt.id"
        >{{ opt.label }}</button>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.tutors.loading') }}</div>

    <div v-else-if="filtered.length" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <div
        v-for="r in filtered"
        :key="r.user_id"
        class="rounded-2xl border bg-tutoring-panel p-3.5 transition hover:border-tutoring-accent/40"
        :class="r.status === 'PENDING' ? 'border-dashed border-amber-500/40 opacity-90' : 'border-tutoring-border-soft'"
      >
        <div class="flex items-center gap-2.5 mb-2">
          <button type="button" class="flex items-center gap-2.5 text-left min-w-0 flex-1" @click="goDetail(r)">
            <span
              class="grid h-9 w-9 place-items-center rounded-full text-[14px] font-bold shrink-0"
              :class="r.status === 'PENDING' ? 'bg-amber-500/15 text-amber-700 dark:text-amber-300' : 'bg-tutoring-accent-dim text-tutoring-accent'"
            >{{ initials(r.name) }}</span>
            <div class="min-w-0">
              <p class="text-[14px] font-bold text-tutoring-text-hi truncate">{{ r.name }}</p>
              <p class="text-[13px] text-tutoring-text-mid truncate">
                {{ r.groups[0]?.program ?? '—' }}<template v-if="r.groups.length"> · {{ t('admin.bimbel.tutors.groups_count', { count: r.groups.length }) }}</template>
              </p>
            </div>
          </button>
          <AdminActionMenu
            :items="[
              { key: 'open', label: t('admin.bimbel.tutors.action_open'), icon: 'chevron-right' },
              { key: 'edit', label: t('admin.bimbel.tutors.action_edit'), icon: 'edit' },
              { key: 'deactivate', label: t('admin.bimbel.tutors.action_deactivate'), icon: 'user-x', danger: true },
            ]"
            :aria-label="t('admin.bimbel.tutors.action_aria')"
            @pick="(k) => pickAction(r, k)"
          />
        </div>
        <template v-if="r.status === 'ACTIVE'">
          <div class="grid grid-cols-3 gap-1.5 mt-2">
            <div class="rounded-lg bg-tutoring-bg/40 p-1.5 text-center">
              <p class="text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.tutors.stat_classes') }}</p>
              <p class="text-[14px] font-bold">{{ r.group_count }}</p>
            </div>
            <div class="rounded-lg bg-tutoring-bg/40 p-1.5 text-center">
              <p class="text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.tutors.stat_students') }}</p>
              <p class="text-[14px] font-bold">{{ studentsCount(r) }}</p>
            </div>
            <div class="rounded-lg bg-tutoring-bg/40 p-1.5 text-center">
              <p class="text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.tutors.stat_sessions_30d') }}</p>
              <p class="text-[14px] font-bold">{{ r.sessions_30d }}</p>
            </div>
          </div>
          <p v-if="r.attendance_rate != null" class="text-[13px] text-tutoring-text-mid mt-2">
            {{ t('admin.bimbel.tutors.attendance_line', { rate: r.attendance_rate }) }}
          </p>
        </template>
        <template v-else>
          <div class="mt-2 text-[14px] text-amber-700 dark:text-amber-300">
            {{ t('admin.bimbel.tutors.pending_line', { date: r.joined_at ? new Date(r.joined_at).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' }) : '—' }) }}
          </div>
          <div class="mt-2">
            <span class="inline-flex items-center gap-1 rounded-md bg-tutoring-accent text-white px-2.5 py-1 text-[13px] font-bold">
              {{ t('admin.bimbel.tutors.pending_cta') }}
            </span>
          </div>
        </template>
      </div>
    </div>

    <div v-else class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid">
      {{ t('admin.bimbel.tutors.empty') }}
    </div>

    <InviteTutorModal v-if="showInvite" @close="showInvite = false" @done="onInvited" />

    <div v-if="editTarget" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="editTarget = null">
      <div class="w-full max-w-md rounded-2xl bg-tutoring-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.tutors.modal_edit_title') }}</h3>
        <p class="text-[14px] text-tutoring-text-mid">{{ editTarget.email }}</p>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.tutors.field_name') }}</span>
          <input v-model="editName" type="text" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft" @click="editTarget = null">{{ t('admin.bimbel.tutors.cancel') }}</button>
          <button type="button" :disabled="editBusy" class="flex-1 rounded-lg bg-tutoring-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="submitEdit">{{ editBusy ? t('admin.bimbel.tutors.saving') : t('admin.bimbel.tutors.save') }}</button>
        </div>
      </div>
    </div>

    <AdminConfirmDialog
      :open="!!deactivateTarget"
      :title="t('admin.bimbel.tutors.deactivate_title')"
      :message="t('admin.bimbel.tutors.deactivate_message', { name: deactivateTarget?.name ?? '' })"
      :confirm-label="t('admin.bimbel.tutors.deactivate_confirm')"
      danger
      :busy="deactivateBusy"
      @cancel="deactivateTarget = null"
      @confirm="confirmDeactivate"
    />
  </div>
</template>
