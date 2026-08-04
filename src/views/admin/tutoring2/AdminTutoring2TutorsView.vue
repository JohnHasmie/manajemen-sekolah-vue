<!--
  AdminTutoring2TutorsView.vue — greenfield "Tutor & Staf" list.

  Wave 4 (WEB-10): switched from the MVP `listGroups → unique tutor_id`
  derivation to the dedicated BE-17 endpoint (`/tutoring-v2/tutors`).
  Row click deep-links to AdminTutoring2TutorDetailView; the "Undang
  tutor" CTA opens AdminTutoring2InviteTutorModal.

  Mirrors AdminTutoring2ProgramsView shape:
    1. `BrandPageHeader`
    2. `KpiStripCards` — 4 tiles (Total / Aktif / Nonaktif / Kelompok aktif)
    3. `PageFilterToolbar` + `AppFilterChip`s
    4. `AsyncView` → white rounded-3xl table card (row-click → detail)
    5. Floating "+ Undang tutor" CTA (gated on `tutoring.tutor.manage`).
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useAuthStore } from '@/stores/auth';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { Tutor } from '@/types/tutoring2/tutor';
import type { StatusBadgeTone } from '@/types/status-badge';
import AdminTutoring2InviteTutorModal from './AdminTutoring2InviteTutorModal.vue';

const { t } = useI18n();
const router = useRouter();
const auth = useAuthStore();

const canView = computed(() => auth.hasAbility('tutoring.tutor.view'));
const canManage = computed(() => auth.hasAbility('tutoring.tutor.manage'));

const search = ref('');
// `activeFilter`: undefined = all, true = only aktif, false = only nonaktif.
// BE reads a missing `active` param as "return both", matching this ternary.
const activeFilter = ref<boolean | undefined>(undefined);

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringTutorsService.list({
    per_page: 50,
    search: debouncedSearch.value || undefined,
    active: activeFilter.value,
  });
  return items;
});

watch([debouncedSearch, activeFilter], () => reload());
useAcademicYearWatcher(reload);

const tutors = computed<Tutor[]>(() =>
  state.value.status === 'content' ? (state.value.data as Tutor[]) : [],
);

const kpiCards = computed<KpiCard[]>(() => {
  const items = tutors.value;
  const active = items.filter((t) => t.is_active).length;
  const inactive = items.length - active;
  const groupsCovered = items.reduce((sum, t) => sum + (t.active_group_count ?? 0), 0);
  return [
    { icon: 'user', label: t('tutoring2.admin.tutors.kpiTutors'), value: String(items.length) },
    { icon: 'circle-check', label: t('tutoring2.admin.tutors.kpiActive'), value: String(active) },
    { icon: 'coffee', label: t('tutoring2.admin.tutors.kpiInactive'), value: String(inactive) },
    { icon: 'users', label: t('tutoring2.admin.tutors.kpiGroupsCovered'), value: String(groupsCovered) },
  ];
});

function statusTone(active: boolean): StatusBadgeTone {
  return active ? 'success' : 'neutral';
}

function statusLabel(active: boolean): string {
  return active
    ? t('tutoring2.admin.tutors.statusActive')
    : t('tutoring2.admin.tutors.statusInactive');
}

function toggleActiveFilter() {
  // Three-way cycle so admins can flip "Semua → Aktif → Nonaktif → Semua"
  // via the single chip. Explicit ternary — `!activeFilter.value` would
  // collapse `false` and `undefined`.
  if (activeFilter.value === undefined) activeFilter.value = true;
  else if (activeFilter.value === true) activeFilter.value = false;
  else activeFilter.value = undefined;
}

const activeFilterLabel = computed(() => {
  if (activeFilter.value === true) return t('tutoring2.admin.tutors.filterActive');
  if (activeFilter.value === false) return t('tutoring2.admin.tutors.filterInactive');
  return t('tutoring2.common.all');
});

function goToDetail(tutor: Tutor) {
  router.push({ name: 'admin.tutoring2.tutor.detail', params: { id: tutor.id } });
}

// ── Invite modal ─────────────────────────────────────────────────────
const inviteOpen = ref(false);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

function openInvite() {
  if (!canManage.value) return;
  inviteOpen.value = true;
}

function onInvited(tutor: Tutor) {
  toast.value = {
    message: t('tutoring2.admin.tutorInvite.success', { name: tutor.name }),
    tone: 'success',
  };
  reload();
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.tutors.title')"
      :meta="state.status === 'content'
        ? t('tutoring2.common.metaTutors', { count: tutors.length })
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.tutors.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="activeFilterLabel"
          icon-name="circle-check"
          :active="activeFilter !== undefined"
          @click="toggleActiveFilter"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.tutors.emptyTitle')"
      :empty-description="t('tutoring2.admin.tutors.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.name') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.tutors.thEmail') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.tutors.thActiveGroups') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.common.status') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="tutor in tutors"
                :key="tutor.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50 cursor-pointer"
                @click="goToDetail(tutor)"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ tutor.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ tutor.email ?? '—' }}</td>
                <td class="px-4 py-3 text-slate-600">
                  {{ tutor.active_group_count }} {{ t('tutoring2.common.group').toLowerCase() }}
                </td>
                <td class="px-4 py-3">
                  <StatusBadge
                    :label="statusLabel(tutor.is_active)"
                    :tone="statusTone(tutor.is_active)"
                    uppercase
                    dot
                  />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </AsyncView>

    <button
      v-if="canManage"
      type="button"
      class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
      @click="openInvite"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.tutors.inviteCta') }}
    </button>

    <AdminTutoring2InviteTutorModal
      v-if="inviteOpen && canManage"
      @close="inviteOpen = false"
      @saved="onInvited"
    />

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />

    <!-- Silent guard: if the caller has no view ability, render nothing
         beyond the header — matches the sidebar which hides this entry
         entirely for non-admins. Kept as v-else on a spare div so the
         chrome (KPIs / filters / table) can be stripped without a
         template restructure if we later want a friendlier stub. -->
    <div v-if="!canView" class="hidden" aria-hidden="true"></div>
  </div>
</template>
