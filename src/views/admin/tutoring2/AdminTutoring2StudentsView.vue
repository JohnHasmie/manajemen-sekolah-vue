<!--
  AdminTutoring2StudentsView.vue — admin "Siswa" list, full CRUD spine
  (WEB-11). Extends the WEB-3 MVP: swaps the derive-from-enrollments
  shortcut for the real BE-18 endpoint (`/api/tutoring-v2/students*`),
  and adds the create / edit / deactivate row actions the MVP flagged.

  Shape (same 5-block layout as the other admin tutoring2 views):
    1. `BrandPageHeader`
    2. `KpiStripCards` — 4 tiles (total/active/inactive/with-bills)
    3. `PageFilterToolbar` + `AppFilterChip`s (search + include-inactive)
    4. `AsyncView` → white rounded-3xl table card with row actions
    5. Floating "+ Tambah siswa" CTA (only when tutoring.student.manage)

  Ability gates:
    - `tutoring.student.view` — the whole view (mount guard is upstream,
      but every mutation is also `.manage`-gated at the button level)
    - `tutoring.student.manage` — new / edit / deactivate CTAs
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDebounceFn } from '@vueuse/core';
import AsyncView from '@/components/data/AsyncView.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useConfirm } from '@/composables/useConfirm';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { TutoringStudentsService } from '@/services/tutoring2/students';
import type { BimbelStudent } from '@/types/tutoring2/student';
import type { StatusBadgeTone } from '@/types/status-badge';
import AdminTutoring2StudentCreateEditSheet from './AdminTutoring2StudentCreateEditSheet.vue';

const { t } = useI18n();
const { can } = useMe();
const { confirm } = useConfirm();
const toast = useToast();

const canManage = computed(() => can('tutoring.student.manage'));

// ── Filters ────────────────────────────────────────────────────────

const search = ref('');
// Two-state switch, NOT an include-toggle: off → only active (default),
// on → only inactive. The BE has no "both" mode.
const inactiveOnly = ref(false);

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

// ── Data ───────────────────────────────────────────────────────────

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringStudentsService.list({
    per_page: 100,
    // BE takes boolean-ish; `active=false` returns ONLY inactive students
    // (`student_status='lulus'`), it does not widen the set. `active=true`
    // is the default so omitting is equivalent — keeps the query minimal.
    ...(inactiveOnly.value ? { active: false } : {}),
    ...(debouncedSearch.value.trim() ? { search: debouncedSearch.value.trim() } : {}),
  });
  return items;
});

watch([debouncedSearch, inactiveOnly], () => reload());
useAcademicYearWatcher(reload);

// ── Derived rendering ──────────────────────────────────────────────

const rows = computed<BimbelStudent[]>(() =>
  (state.value.status === 'content' ? state.value.data : []) as BimbelStudent[],
);

const kpiCards = computed<KpiCard[]>(() => {
  const items = rows.value;
  const total = items.length;
  const active = items.filter((s) => s.active !== false).length;
  const inactive = items.filter((s) => s.active === false).length;
  const withBills = items.filter((s) => (s.active_bill_count ?? 0) > 0).length;
  return [
    { icon: 'users', label: t('tutoring2.admin.students.kpiTotal'), value: String(total) },
    { icon: 'circle-check', label: t('tutoring2.admin.students.kpiActive'), value: String(active) },
    {
      icon: 'log-out',
      label: t('tutoring2.admin.students.kpiGraduated'),
      value: String(inactive),
      tone: inactive > 0 ? 'slate' : undefined,
    },
    {
      icon: 'sparkles',
      label: t('tutoring2.admin.students.kpiWithBills'),
      value: String(withBills),
      tone: withBills > 0 ? 'amber' : undefined,
    },
  ];
});

function statusToneFor(s: BimbelStudent): StatusBadgeTone {
  // active flag is authoritative — student_status may be null on
  // never-graduated rows and the BE resource maps that to active=true.
  if (s.active === false) return 'neutral';
  if (s.student_status === 'trial') return 'warning';
  return 'success';
}

function statusLabelFor(s: BimbelStudent): string {
  if (s.active === false) return t('tutoring2.admin.students.kpiGraduated');
  if (s.student_status === 'trial') return t('tutoring2.admin.students.kpiTrial');
  return t('tutoring2.admin.students.kpiActive');
}

// ── Sheet state ────────────────────────────────────────────────────

/**
 * `undefined` → sheet closed. `null` → open in create mode.
 * A BimbelStudent → open in edit mode (pre-hydrated).
 */
const sheetTarget = ref<BimbelStudent | null | undefined>(undefined);

function openCreate() {
  if (!canManage.value) return;
  sheetTarget.value = null;
}
function openEdit(row: BimbelStudent) {
  if (!canManage.value) return;
  sheetTarget.value = row;
}
function closeSheet() {
  sheetTarget.value = undefined;
}
function onSaved() {
  // The child already toasts success — the parent just re-fetches so
  // the new/updated row shows with fresh subselect counts.
  reload();
}

// ── Deactivate ─────────────────────────────────────────────────────

async function deactivate(row: BimbelStudent) {
  if (!canManage.value) return;
  const ok = await confirm({
    title: t('tutoring2.admin.students.deactivateConfirmTitle'),
    message: t('tutoring2.admin.students.deactivateConfirmMsg'),
    confirmLabel: t('tutoring2.admin.students.actionDeactivate'),
    danger: true,
  });
  if (!ok) return;
  try {
    await TutoringStudentsService.deactivate(row.id);
    toast.success(t('tutoring2.admin.students.deactivateSuccess'));
    reload();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[tutoring2/students] deactivate failed', err);
    toast.error(t('tutoring2.admin.students.deactivateError'));
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="t('tutoring2.common.roleAdmin')"
      :title="t('tutoring2.admin.students.title')"
      :meta="state.status === 'content'
        ? `${rows.length} ${t('tutoring2.common.student').toLowerCase()}`
        : t('tutoring2.common.loading')"
    />

    <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

    <PageFilterToolbar v-model:search="search" :search-placeholder="t('tutoring2.admin.students.searchPh')">
      <template #chips>
        <AppFilterChip
          :label="t('tutoring2.common.status')"
          :value="inactiveOnly ? t('tutoring2.admin.students.showInactive') : t('tutoring2.admin.students.kpiActive')"
          icon-name="circle-check"
          :active="inactiveOnly"
          @click="inactiveOnly = !inactiveOnly"
        />
      </template>
    </PageFilterToolbar>

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="6"
      :empty-title="t('tutoring2.admin.students.emptyTitle')"
      :empty-description="t('tutoring2.admin.students.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.students.colName') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.students.colStudentNumber') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.students.colWali') }}</th>
                <th class="px-4 py-3 font-bold">{{ t('tutoring2.admin.students.colStatus') }}</th>
                <th class="px-4 py-3 font-bold text-right">{{ t('tutoring2.admin.students.colEnrollments') }}</th>
                <th class="px-4 py-3 font-bold text-right">{{ t('tutoring2.admin.students.colBills') }}</th>
                <th
                  v-if="canManage"
                  class="px-4 py-3 font-bold text-right"
                >
                  {{ t('tutoring2.admin.students.colActions') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="r in rows"
                :key="r.id"
                class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
              >
                <td class="px-4 py-3 font-bold text-slate-900">{{ r.name }}</td>
                <td class="px-4 py-3 text-slate-600">{{ r.student_number ?? '—' }}</td>
                <td class="px-4 py-3 text-slate-600">
                  <div class="flex flex-col">
                    <span>{{ r.guardian_name ?? '—' }}</span>
                    <span v-if="r.guardian_email" class="text-xs text-slate-400">{{ r.guardian_email }}</span>
                  </div>
                </td>
                <td class="px-4 py-3">
                  <StatusBadge :label="statusLabelFor(r)" :tone="statusToneFor(r)" uppercase />
                </td>
                <td class="px-4 py-3 text-right text-slate-600">{{ r.active_enrollment_count ?? 0 }}</td>
                <td class="px-4 py-3 text-right text-slate-600">{{ r.active_bill_count ?? 0 }}</td>
                <td
                  v-if="canManage"
                  class="px-4 py-3 text-right"
                >
                  <div class="inline-flex items-center gap-2">
                    <button
                      type="button"
                      class="text-xs font-semibold text-brand-cobalt hover:underline"
                      @click="openEdit(r)"
                    >
                      {{ t('tutoring2.admin.students.actionEdit') }}
                    </button>
                    <span class="text-slate-300" aria-hidden="true">·</span>
                    <button
                      type="button"
                      class="text-xs font-semibold text-status-danger hover:underline disabled:opacity-40 disabled:no-underline"
                      :disabled="r.active === false"
                      @click="deactivate(r)"
                    >
                      {{ t('tutoring2.admin.students.actionDeactivate') }}
                    </button>
                  </div>
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
      @click="openCreate"
    >
      <span aria-hidden="true">+</span> {{ t('tutoring2.admin.students.newCta') }}
    </button>

    <!--
      Sheet mount — `v-if` gate keeps the form state fresh on every
      open (create-mode reactive form resets from empty props). The
      child owns POST/PUT via TutoringStudentsService and toasts on
      success; parent just reloads and closes.
    -->
    <AdminTutoring2StudentCreateEditSheet
      v-if="sheetTarget !== undefined"
      :student="sheetTarget"
      @close="closeSheet"
      @saved="onSaved"
    />
  </div>
</template>
