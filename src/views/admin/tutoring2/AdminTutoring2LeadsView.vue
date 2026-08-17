<!--
  AdminTutoring2LeadsView.vue — greenfield "Leads / Calon Siswa"
  admin funnel (WEB-8, backed by BE-15).

  Mirrors AdminTutoring2ProgramsView.vue / EnrollmentsView.vue in
  layout: BrandPageHeader → KpiStripCards → PageFilterToolbar (+ chips)
  → AsyncView wrapping the table → floating "+ Tambah Lead" CTA. Data
  loads via `useDataRefresh(loader)` and re-runs when the debounced
  search, either filter chip, or the active academic year changes.

  Modal stack (all local, no route param — the detail sheet lives in
  the same view so the admin's filter state and scroll position stay
  intact when they inspect/convert/drop leads):
    - "Tambah Lead" modal  — CreateLeadPayload; source + name required
    - Detail sheet         — full editable form + activity note
    - "Convert" modal      — ConvertLeadPayload (delegates to BE-3
                             CreateEnrollmentAction server-side)
    - "Drop" confirmation  — free-text reason, appends to notes

  Ability gates (server-side authoritative — this only hides UI the
  user can't act on):
    - reads (list/detail)             → tutoring.lead.view
    - writes (create/convert/drop/    → tutoring.lead.manage
      update/destroy)

  KPI monthly counters are computed from the current in-memory page
  (list is capped at 100 per fetch — same as the sibling enrollments
  view). A future MR can promote these to a dedicated BE
  `/tutoring-v2/leads/summary` endpoint if the funnel gets deep enough
  that a page-slice count reads misleading.
-->
<script setup lang="ts">
import { computed, ref, toRaw, watch } from 'vue';
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
import Modal from '@/components/ui/Modal.vue';
import FormField from '@/components/ui/FormField.vue';
import Button from '@/components/ui/Button.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useMe } from '@/composables/useMe';
import { useToast } from '@/composables/useToast';
import { toLocalYmd } from '@/lib/local-date';
import { TutoringLeadsService } from '@/services/tutoring2/leads';
import {
  LEAD_SOURCE_LABEL,
  LEAD_SOURCE_VALUES,
  LEAD_STATUS_LABEL,
  LEAD_STATUS_VALUES,
  type BimbelLead,
  type ConvertLeadPayload,
  type CreateLeadPayload,
  type LeadSource,
  type LeadStatus,
  type UpdateLeadPayload,
} from '@/types/tutoring2/lead';
import type { StatusBadgeTone } from '@/types/status-badge';

const { t, te } = useI18n();
const toast = useToast();
const { can } = useMe();

// ─── Ability shortcuts ─────────────────────────────────────────────
// `can` reads the /me `abilities` snapshot which is scoped by the
// currently active X-Active-Role (see reference_authz_client_gating_rule).
// The controller re-authorises server-side; these gates only hide
// affordances the user can't act on.
const canView = computed(() => can('tutoring.lead.view'));
const canManage = computed(() => can('tutoring.lead.manage'));

// ─── Filter + search state ─────────────────────────────────────────
const search = ref('');
const statusFilter = ref<LeadStatus | ''>('');
const sourceFilter = ref<LeadSource | ''>('');

const debouncedSearch = ref('');
const applyDebounced = useDebounceFn((v: string) => {
  debouncedSearch.value = v;
}, 300);
watch(search, (v) => applyDebounced(v));

/** Small i18n helper — falls back to the enum's Indonesian label if the
 *  view's i18n bundle hasn't been extended yet. Keeps this file
 *  translation-safe without a locale-bundle PR blocker. */
function tOr(key: string, fallback: string): string {
  return te(key) ? t(key) : fallback;
}

// ─── Data load ─────────────────────────────────────────────────────
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringLeadsService.list({
    per_page: 100,
    status: statusFilter.value || undefined,
    source: sourceFilter.value || undefined,
  });
  const q = debouncedSearch.value.trim().toLowerCase();
  if (!q) return items;
  return items.filter(
    (l) =>
      (l.name ?? '').toLowerCase().includes(q) ||
      (l.phone ?? '').toLowerCase().includes(q) ||
      (l.email ?? '').toLowerCase().includes(q),
  );
});

watch([debouncedSearch, statusFilter, sourceFilter], () => {
  reload();
});

// ─── KPI derivation from the current page ──────────────────────────
// Uses the local-timezone Ymd to avoid the toISOString() WIB day-drop
// documented in reference_web_vue_local_date.
const currentMonthPrefix = computed(() => {
  const now = new Date();
  return toLocalYmd(now).slice(0, 7); // "YYYY-MM"
});

const kpiCards = computed<KpiCard[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelLead[];
  const baru = items.filter((l) => l.status === 'new').length;
  const pipeline = items.filter(
    (l) => l.status === 'contacted' || l.status === 'trial',
  ).length;
  const monthPrefix = currentMonthPrefix.value;
  const convertedThisMonth = items.filter(
    (l) =>
      l.status === 'converted' &&
      (l.updated_at ?? '').slice(0, 7) === monthPrefix,
  ).length;
  const droppedThisMonth = items.filter(
    (l) =>
      l.status === 'dropped' &&
      (l.updated_at ?? '').slice(0, 7) === monthPrefix,
  ).length;
  return [
    {
      icon: 'sparkles',
      label: tOr('tutoring2.admin.leads.kpiBaru', 'Baru'),
      value: String(baru),
      tone: baru > 0 ? 'amber' : undefined,
    },
    {
      icon: 'users',
      label: tOr('tutoring2.admin.leads.kpiPipeline', 'Dalam pipeline'),
      value: String(pipeline),
    },
    {
      icon: 'circle-check',
      label: tOr('tutoring2.admin.leads.kpiConvertedMonth', 'Konversi bulan ini'),
      value: String(convertedThisMonth),
      tone: convertedThisMonth > 0 ? 'green' : undefined,
    },
    {
      icon: 'x-circle',
      label: tOr('tutoring2.admin.leads.kpiDroppedMonth', 'Batal bulan ini'),
      value: String(droppedThisMonth),
      tone: droppedThisMonth > 0 ? 'red' : undefined,
    },
  ];
});

// ─── Table helpers ─────────────────────────────────────────────────
function statusTone(status: LeadStatus | null | undefined): StatusBadgeTone {
  switch (status) {
    case 'new': return 'info';
    case 'contacted': return 'info';
    case 'trial': return 'warning';
    case 'converted': return 'success';
    case 'dropped': return 'neutral';
    default: return 'neutral';
  }
}

function statusLabel(l: BimbelLead): string {
  return l.status_label ?? (l.status ? LEAD_STATUS_LABEL[l.status] : '—');
}

function sourceLabel(l: BimbelLead): string {
  return l.source_label ?? (l.source ? LEAD_SOURCE_LABEL[l.source] : '—');
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return toLocalYmd(d);
}

// ─── Modal orchestration ───────────────────────────────────────────
type Sheet = 'none' | 'create' | 'detail' | 'convert' | 'drop';
const openSheet = ref<Sheet>('none');
const activeLead = ref<BimbelLead | null>(null);
const submitting = ref(false);

const statusOptions = LEAD_STATUS_VALUES.map((v) => ({
  value: v,
  label: LEAD_STATUS_LABEL[v],
}));
const sourceOptions = LEAD_SOURCE_VALUES.map((v) => ({
  value: v,
  label: LEAD_SOURCE_LABEL[v],
}));
const billingModeOptions = [
  { value: 'prepaid', label: 'Prabayar (paket)' },
  { value: 'monthly', label: 'SPP bulanan' },
  { value: 'per_session', label: 'Per sesi' },
];

// ─── Create modal state ────────────────────────────────────────────
const createForm = ref<CreateLeadPayload>({
  name: '',
  phone: '',
  email: '',
  source: 'website',
  notes: '',
});
function resetCreateForm() {
  createForm.value = {
    name: '',
    phone: '',
    email: '',
    source: 'website',
    notes: '',
  };
}
function openCreate() {
  if (!canManage.value) return;
  resetCreateForm();
  openSheet.value = 'create';
}
async function submitCreate() {
  if (!createForm.value.name.trim()) {
    toast.error(tOr('tutoring2.admin.leads.errNameRequired', 'Nama wajib diisi'));
    return;
  }
  submitting.value = true;
  try {
    // structuredClone via toRaw — see reference_vue_structuredclone_reactive.
    const payload = structuredClone(toRaw(createForm.value));
    await TutoringLeadsService.create(payload);
    toast.success(tOr('tutoring2.admin.leads.toastCreated', 'Lead ditambahkan'));
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    submitting.value = false;
  }
}

// ─── Detail sheet state ────────────────────────────────────────────
const detailForm = ref<UpdateLeadPayload>({});
async function openDetail(lead: BimbelLead) {
  activeLead.value = lead;
  detailForm.value = {
    name: lead.name,
    phone: lead.phone ?? '',
    email: lead.email ?? '',
    source: lead.source ?? 'website',
    status: lead.status ?? 'new',
    notes: lead.notes ?? '',
  };
  openSheet.value = 'detail';
  // Fresh fetch so the sheet shows the latest server truth, not the
  // possibly-stale row from the list page.
  try {
    const fresh = await TutoringLeadsService.get(lead.id);
    activeLead.value = fresh;
    detailForm.value = {
      name: fresh.name,
      phone: fresh.phone ?? '',
      email: fresh.email ?? '',
      source: fresh.source ?? 'website',
      status: fresh.status ?? 'new',
      notes: fresh.notes ?? '',
    };
  } catch {
    // Non-fatal — keep the row we already have on screen.
  }
}
async function submitDetail() {
  if (!activeLead.value || !canManage.value) return;
  submitting.value = true;
  try {
    const payload = structuredClone(toRaw(detailForm.value));
    await TutoringLeadsService.update(activeLead.value.id, payload);
    toast.success(tOr('tutoring2.admin.leads.toastUpdated', 'Perubahan disimpan'));
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    submitting.value = false;
  }
}

// ─── Convert modal state ───────────────────────────────────────────
const convertForm = ref<ConvertLeadPayload>({
  student_id: '',
  package_id: null,
  billing_mode: 'monthly',
  start_date: null,
  notes: '',
});
function openConvert(lead: BimbelLead) {
  if (!canManage.value) return;
  if (lead.status === 'converted' || lead.status === 'dropped') {
    toast.error(
      tOr(
        'tutoring2.admin.leads.errTerminal',
        'Lead sudah berada di status terminal',
      ),
    );
    return;
  }
  activeLead.value = lead;
  convertForm.value = {
    student_id: '',
    package_id: null,
    billing_mode: 'monthly',
    start_date: toLocalYmd(new Date()),
    notes: '',
  };
  openSheet.value = 'convert';
}
async function submitConvert() {
  if (!activeLead.value) return;
  if (!convertForm.value.student_id.trim()) {
    toast.error(
      tOr('tutoring2.admin.leads.errStudentRequired', 'Siswa wajib dipilih'),
    );
    return;
  }
  submitting.value = true;
  try {
    const payload = structuredClone(toRaw(convertForm.value));
    // Prune blank optional strings so the BE validator doesn't reject them.
    if (!payload.package_id) delete payload.package_id;
    if (!payload.learning_group_id) delete payload.learning_group_id;
    if (!payload.start_date) delete payload.start_date;
    if (!payload.notes) delete payload.notes;
    await TutoringLeadsService.convert(activeLead.value.id, payload);
    toast.success(
      tOr('tutoring2.admin.leads.toastConverted', 'Lead dikonversi ke pendaftaran'),
    );
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    submitting.value = false;
  }
}

// ─── Drop modal state ──────────────────────────────────────────────
const dropReason = ref('');
function openDrop(lead: BimbelLead) {
  if (!canManage.value) return;
  if (lead.status === 'converted' || lead.status === 'dropped') {
    toast.error(
      tOr(
        'tutoring2.admin.leads.errTerminal',
        'Lead sudah berada di status terminal',
      ),
    );
    return;
  }
  activeLead.value = lead;
  dropReason.value = '';
  openSheet.value = 'drop';
}
async function submitDrop() {
  if (!activeLead.value) return;
  submitting.value = true;
  try {
    await TutoringLeadsService.drop(activeLead.value.id, {
      notes: dropReason.value.trim() || null,
    });
    toast.success(tOr('tutoring2.admin.leads.toastDropped', 'Lead ditandai batal'));
    openSheet.value = 'none';
    await reload();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    submitting.value = false;
  }
}

function closeSheet() {
  openSheet.value = 'none';
  activeLead.value = null;
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="admin"
      :kicker="tOr('tutoring2.common.roleAdmin', 'Admin bimbel')"
      :title="tOr('tutoring2.admin.leads.title', 'Leads / Calon Siswa')"
      :meta="state.status === 'content'
        ? `${(state.data as BimbelLead[]).length} ${tOr('tutoring2.admin.leads.metaSuffix', 'lead')}`
        : tOr('tutoring2.common.loading', 'Memuat…')"
    />

    <!-- Read-guard: users without tutoring.lead.view get a plain empty
         message rather than a broken 403 fetch loop. -->
    <div
      v-if="!canView"
      class="rounded-3xl border border-slate-100 bg-white p-lg text-sm text-slate-600 shadow-sm"
    >
      {{ tOr('tutoring2.admin.leads.forbidden', 'Anda tidak memiliki izin untuk melihat leads.') }}
    </div>

    <template v-else>
      <KpiStripCards :cards="kpiCards" :loading="state.status === 'loading'" />

      <PageFilterToolbar
        v-model:search="search"
        :search-placeholder="tOr('tutoring2.admin.leads.searchPh', 'Cari nama, nomor, atau email')"
      >
        <template #chips>
          <AppFilterChip
            :label="tOr('tutoring2.common.status', 'Status')"
            :value="statusFilter
              ? LEAD_STATUS_LABEL[statusFilter]
              : tOr('tutoring2.common.all', 'Semua')"
            icon-name="circle-check"
            :active="!!statusFilter"
            @click="statusFilter = statusFilter ? '' : 'new'"
          />
          <AppFilterChip
            :label="tOr('tutoring2.admin.leads.source', 'Sumber')"
            :value="sourceFilter
              ? LEAD_SOURCE_LABEL[sourceFilter]
              : tOr('tutoring2.common.all', 'Semua')"
            icon-name="megaphone"
            :active="!!sourceFilter"
            @click="sourceFilter = sourceFilter ? '' : 'whatsapp'"
          />
        </template>
      </PageFilterToolbar>

      <AsyncView
        :state="state"
        loading-variant="cards"
        :loading-rows="6"
        :empty-title="tOr('tutoring2.admin.leads.emptyTitle', 'Belum ada lead')"
        :empty-description="tOr('tutoring2.admin.leads.emptyDesc', 'Tambahkan calon siswa dari tombol di kanan bawah.')"
        @retry="reload"
      >
        <template #default="{ data }">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm overflow-hidden">
            <table class="w-full text-sm" data-testid="leads-table">
              <thead>
                <tr class="border-b border-slate-100 text-left text-2xs uppercase tracking-wide text-slate-400">
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.common.name', 'Nama') }}</th>
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.admin.leads.dateIn', 'Tanggal masuk') }}</th>
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.admin.leads.source', 'Sumber') }}</th>
                  <th class="px-4 py-3 font-bold">{{ tOr('tutoring2.common.status', 'Status') }}</th>
                  <th class="px-4 py-3 font-bold text-right">{{ tOr('tutoring2.common.actions', 'Aksi') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="l in (data as BimbelLead[])"
                  :key="l.id"
                  class="border-b border-slate-100 last:border-0 hover:bg-slate-50"
                  data-testid="lead-row"
                >
                  <td class="px-4 py-3">
                    <button
                      type="button"
                      class="font-bold text-slate-900 hover:text-brand-cobalt text-left"
                      @click="openDetail(l)"
                    >{{ l.name }}</button>
                    <div v-if="l.phone || l.email" class="text-xs text-slate-500 mt-0.5">
                      {{ [l.phone, l.email].filter(Boolean).join(' · ') }}
                    </div>
                  </td>
                  <td class="px-4 py-3 text-slate-600">{{ fmtDate(l.created_at) }}</td>
                  <td class="px-4 py-3 text-slate-600">{{ sourceLabel(l) }}</td>
                  <td class="px-4 py-3">
                    <StatusBadge :label="statusLabel(l)" :tone="statusTone(l.status)" uppercase />
                  </td>
                  <td class="px-4 py-3 text-right">
                    <div class="inline-flex items-center gap-1">
                      <button
                        type="button"
                        class="px-2 py-1 rounded-lg text-xs font-semibold text-slate-600 hover:bg-slate-100"
                        @click="openDetail(l)"
                      >{{ tOr('tutoring2.common.detail', 'Detail') }}</button>
                      <button
                        v-if="canManage && l.status !== 'converted' && l.status !== 'dropped'"
                        type="button"
                        data-testid="lead-convert-btn"
                        class="px-2 py-1 rounded-lg text-xs font-semibold text-emerald-700 hover:bg-emerald-50"
                        @click="openConvert(l)"
                      >{{ tOr('tutoring2.admin.leads.convert', 'Konversi') }}</button>
                      <button
                        v-if="canManage && l.status !== 'converted' && l.status !== 'dropped'"
                        type="button"
                        class="px-2 py-1 rounded-lg text-xs font-semibold text-red-700 hover:bg-red-50"
                        @click="openDrop(l)"
                      >{{ tOr('tutoring2.admin.leads.drop', 'Batalkan') }}</button>
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
        data-testid="lead-add-cta"
        class="fixed bottom-6 right-6 z-30 inline-flex items-center gap-2 px-5 py-3 rounded-2xl bg-brand-cobalt text-white font-bold shadow-xl shadow-brand-cobalt/30 hover:bg-brand-cobalt/90 transition-colors"
        @click="openCreate"
      >
        <span aria-hidden="true">+</span>
        {{ tOr('tutoring2.admin.leads.newCta', 'Tambah Lead') }}
      </button>
    </template>

    <!-- ── Create modal ─────────────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'create'"
      :title="tOr('tutoring2.admin.leads.newCta', 'Tambah Lead')"
      :subtitle="tOr('tutoring2.admin.leads.newSubtitle', 'Catat calon siswa baru untuk masuk pipeline.')"
      size="md"
      @close="closeSheet"
    >
      <form class="space-y-md" @submit.prevent="submitCreate">
        <FormField
          v-model="createForm.name"
          :label="tOr('tutoring2.common.name', 'Nama lengkap')"
          required
          :placeholder="'Nama lengkap'"
        />
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
          <FormField
            :model-value="createForm.phone ?? ''"
            :label="tOr('tutoring2.common.phone', 'Nomor telepon')"
            type="tel"
            :placeholder="'+62…'"
            @update:model-value="createForm.phone = String($event)"
          />
          <FormField
            :model-value="createForm.email ?? ''"
            :label="tOr('tutoring2.common.email', 'Email')"
            type="email"
            :placeholder="'email@…'"
            @update:model-value="createForm.email = String($event)"
          />
        </div>
        <FormField
          :model-value="createForm.source"
          :label="tOr('tutoring2.admin.leads.source', 'Sumber')"
          type="select"
          required
          :options="sourceOptions"
          @update:model-value="createForm.source = String($event) as LeadSource"
        />
        <FormField
          :model-value="createForm.notes ?? ''"
          :label="tOr('tutoring2.common.notes', 'Catatan')"
          type="textarea"
          :rows="3"
          @update:model-value="createForm.notes = String($event)"
        />
        <div class="flex justify-end gap-2 pt-md border-t border-slate-100">
          <Button variant="ghost" type="button" @click="closeSheet">
            {{ tOr('tutoring2.common.cancel', 'Batal') }}
          </Button>
          <Button variant="primary" type="submit" :loading="submitting">
            {{ tOr('tutoring2.common.save', 'Simpan') }}
          </Button>
        </div>
      </form>
    </Modal>

    <!-- ── Detail sheet ─────────────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'detail' && activeLead"
      :title="activeLead.name"
      :subtitle="tOr('tutoring2.admin.leads.detailSubtitle', 'Riwayat, catatan, dan tindakan lead.')"
      size="lg"
      @close="closeSheet"
    >
      <div class="space-y-md">
        <div class="flex items-center gap-2">
          <StatusBadge :label="statusLabel(activeLead)" :tone="statusTone(activeLead.status)" uppercase />
          <span class="text-xs text-slate-500">
            {{ tOr('tutoring2.admin.leads.dateIn', 'Tanggal masuk') }}:
            {{ fmtDate(activeLead.created_at) }}
          </span>
        </div>

        <form class="space-y-md" @submit.prevent="submitDetail">
          <FormField
            :model-value="detailForm.name ?? ''"
            :label="tOr('tutoring2.common.name', 'Nama lengkap')"
            :disabled="!canManage"
            @update:model-value="detailForm.name = String($event)"
          />
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
            <FormField
              :model-value="detailForm.phone ?? ''"
              :label="tOr('tutoring2.common.phone', 'Nomor telepon')"
              type="tel"
              :disabled="!canManage"
              @update:model-value="detailForm.phone = String($event)"
            />
            <FormField
              :model-value="detailForm.email ?? ''"
              :label="tOr('tutoring2.common.email', 'Email')"
              type="email"
              :disabled="!canManage"
              @update:model-value="detailForm.email = String($event)"
            />
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-md">
            <FormField
              :model-value="detailForm.source ?? 'website'"
              :label="tOr('tutoring2.admin.leads.source', 'Sumber')"
              type="select"
              :options="sourceOptions"
              :disabled="!canManage"
              @update:model-value="detailForm.source = String($event) as LeadSource"
            />
            <FormField
              :model-value="detailForm.status ?? 'new'"
              :label="tOr('tutoring2.common.status', 'Status')"
              type="select"
              :options="statusOptions"
              :disabled="!canManage"
              @update:model-value="detailForm.status = String($event) as LeadStatus"
            />
          </div>
          <FormField
            :model-value="detailForm.notes ?? ''"
            :label="tOr('tutoring2.admin.leads.activityLog', 'Catatan / aktivitas')"
            type="textarea"
            :rows="4"
            :disabled="!canManage"
            @update:model-value="detailForm.notes = String($event)"
          />

          <div class="flex flex-wrap justify-between gap-2 pt-md border-t border-slate-100">
            <div class="inline-flex gap-2">
              <Button
                v-if="canManage && activeLead.status !== 'converted' && activeLead.status !== 'dropped'"
                variant="ghost"
                type="button"
                @click="openConvert(activeLead)"
              >
                {{ tOr('tutoring2.admin.leads.convert', 'Konversi ke pendaftaran') }}
              </Button>
              <Button
                v-if="canManage && activeLead.status !== 'converted' && activeLead.status !== 'dropped'"
                variant="ghost"
                type="button"
                @click="openDrop(activeLead)"
              >
                {{ tOr('tutoring2.admin.leads.drop', 'Batalkan') }}
              </Button>
            </div>
            <div class="inline-flex gap-2">
              <Button variant="ghost" type="button" @click="closeSheet">
                {{ tOr('tutoring2.common.close', 'Tutup') }}
              </Button>
              <Button v-if="canManage" variant="primary" type="submit" :loading="submitting">
                {{ tOr('tutoring2.common.save', 'Simpan') }}
              </Button>
            </div>
          </div>
        </form>
      </div>
    </Modal>

    <!-- ── Convert modal ────────────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'convert' && activeLead"
      :title="tOr('tutoring2.admin.leads.convertTitle', 'Konversi ke pendaftaran')"
      :subtitle="activeLead.name"
      size="md"
      @close="closeSheet"
    >
      <form class="space-y-md" @submit.prevent="submitConvert" data-testid="lead-convert-form">
        <FormField
          v-model="convertForm.student_id"
          :label="tOr('tutoring2.admin.leads.studentId', 'Siswa (ID)')"
          required
          :placeholder="'st-…'"
        />
        <FormField
          :model-value="convertForm.package_id ?? ''"
          :label="tOr('tutoring2.admin.leads.packageId', 'Paket (opsional)')"
          :placeholder="'pk-…'"
          @update:model-value="convertForm.package_id = String($event) || null"
        />
        <FormField
          :model-value="convertForm.billing_mode"
          :label="tOr('tutoring2.common.billingMode', 'Skema tagihan')"
          type="select"
          required
          :options="billingModeOptions"
          @update:model-value="convertForm.billing_mode = String($event) as ConvertLeadPayload['billing_mode']"
        />
        <FormField
          :model-value="convertForm.start_date ?? ''"
          :label="tOr('tutoring2.admin.leads.startDate', 'Tanggal mulai')"
          type="text"
          :placeholder="'YYYY-MM-DD'"
          @update:model-value="convertForm.start_date = String($event)"
        />
        <FormField
          :model-value="convertForm.notes ?? ''"
          :label="tOr('tutoring2.common.notes', 'Catatan')"
          type="textarea"
          :rows="3"
          @update:model-value="convertForm.notes = String($event)"
        />
        <div class="flex justify-end gap-2 pt-md border-t border-slate-100">
          <Button variant="ghost" type="button" @click="closeSheet">
            {{ tOr('tutoring2.common.cancel', 'Batal') }}
          </Button>
          <Button variant="primary" type="submit" :loading="submitting">
            {{ tOr('tutoring2.admin.leads.convert', 'Konversi') }}
          </Button>
        </div>
      </form>
    </Modal>

    <!-- ── Drop confirmation ───────────────────────────────────── -->
    <Modal
      v-if="openSheet === 'drop' && activeLead"
      :title="tOr('tutoring2.admin.leads.dropTitle', 'Tandai lead sebagai batal')"
      :subtitle="activeLead.name"
      size="sm"
      @close="closeSheet"
    >
      <form class="space-y-md" @submit.prevent="submitDrop">
        <p class="text-sm text-slate-600">
          {{ tOr('tutoring2.admin.leads.dropHint', 'Beri alasan singkat — akan disimpan pada catatan lead.') }}
        </p>
        <FormField
          v-model="dropReason"
          type="textarea"
          :rows="3"
          :placeholder="tOr('tutoring2.admin.leads.dropReasonPh', 'Alasan pembatalan')"
        />
        <div class="flex justify-end gap-2 pt-md border-t border-slate-100">
          <Button variant="ghost" type="button" @click="closeSheet">
            {{ tOr('tutoring2.common.cancel', 'Batal') }}
          </Button>
          <Button variant="danger" type="submit" :loading="submitting">
            {{ tOr('tutoring2.admin.leads.drop', 'Batalkan lead') }}
          </Button>
        </div>
      </form>
    </Modal>
  </div>
</template>
