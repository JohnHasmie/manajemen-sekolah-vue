<!--
  SuperAdminDemoRequestDetailView.vue — FULL super-admin view of a
  single demo request: EVERY form input the requester submitted in the
  multi-step register-demo wizard + the identity screen.

  Why this exists
  ---------------
  The list page (SuperAdminDemoRequestView) only shows a condensed
  summary in its modal (identity + school summary + a few counters). The
  founder wants the team to be able to inspect ALL submitted inputs
  before activating a demo. The backend already returns the complete
  payload — `GET /api/demo-requests/{id}` →
  DemoRequestAdminController@show → (new DemoRequestResource)->withPayload()
  embeds the stored `school_payload` (JSON with top-level keys: school,
  identity, subjects, teachers, classes, students, parents, schedule,
  billing, scenarios). This view simply renders all of it, section by
  section, gracefully handling missing/empty parts.

  Sections (in submission order):
    1. Identitas Pemohon   — requester identity + social channels + meta
    2. Data Sekolah        — school name / level / city / npsn / TA + role mode
    3. Mata Pelajaran      — chip list of subject names
    4. Teacher                — count + fill mode + manual list table
    5. Kelas               — pattern + per-grade table
    6. Student               — per-class + fill mode
    7. Orang Tua           — link mode
    8. Schedule              — mode + active days + JP + hours
    9. Skenario            — enabled scenario chips (labelled)
   10. Pembayaran          — mode + SPP nominal + template chips

  Plus a request-meta header (status, requester, created/reviewed) and
  Approve/Reject actions identical to the list modal, available inline
  while the request is still `pending`.

  Route: /super-admin/demo-requests/:id  (meta.superAdmin: true). Guarded
  client-side by the super-admin router guard AND server-side by the
  EnsureSuperAdmin middleware (a 403 surfaces as a friendly error state).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { DemoRequestService } from '@/services/demo-request.service';
import {
  DEMO_REQUEST_STATUS_LABELS,
  DEMO_SOCIAL_LABELS,
  type DemoRequest,
  type DemoRequesterSocialMedia,
  type DemoRequestStatus,
} from '@/types/demo-request';
import { SCENARIO_DEFINITIONS, type DemoScenarioKey } from '@/types/demo';
import { normalizeTenantType } from '@/lib/labels';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import Modal from '@/components/ui/Modal.vue';
import DemoAccountManagementSection from './DemoAccountManagementSection.vue';
import type {
  DeleteDemoSchoolResult,
  DemoAccountDeleteResult,
} from '@/types/demo-account';
import { formatDateTime, formatRupiah } from '@/lib/format';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const requestId = computed(() => String(route.params.id ?? ''));

// ── Detail state ────────────────────────────────────────────────────
const detail = ref<DemoRequest | null>(null);
const isLoading = ref(true);
const loadError = ref<string | null>(null);

async function load() {
  isLoading.value = true;
  loadError.value = null;
  try {
    detail.value = await DemoRequestService.show(requestId.value);
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

const detailState = computed<AsyncState<DemoRequest>>(() => {
  if (isLoading.value && !detail.value) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (!detail.value) return { status: 'empty' };
  return { status: 'content', data: detail.value };
});

// The stored wizard payload (may be null if the backend ever omits it).
const payload = computed(() => detail.value?.school_payload ?? null);

/**
 * Was this payload a tutoring-tenant request? Tolerates the wire-value
 * transition (`tutoring` new / `bimbel` legacy) — older rows persisted
 * before the 2026-06-26 English-enum cutover still read `bimbel`, so a
 * raw string equality would mis-classify them as `school`.
 */
const isTutoringPayload = computed(
  () => normalizeTenantType(payload.value?.tenant_type) === 'tutoring',
);

/**
 * The tutoring slice inside the payload — JSON key renamed from
 * `bimbel` → `tutoring`. Read both during the transition: server may
 * still emit `bimbel` for legacy rows until backfill, but new submits
 * land under `tutoring`.
 */
const tutoringSlice = computed(() => {
  const p = payload.value as Record<string, any> | null;
  return p?.tutoring ?? p?.bimbel ?? null;
});

// ── Status pill styling (mirrors the list page) ─────────────────────
function statusTone(status: DemoRequestStatus): string {
  switch (status) {
    case 'pending':
      return 'bg-amber-50 text-amber-700 border-amber-200';
    case 'approved':
      return 'bg-emerald-50 text-emerald-700 border-emerald-200';
    case 'rejected':
      return 'bg-red-50 text-red-700 border-red-200';
    case 'expired':
      return 'bg-slate-100 text-slate-500 border-slate-200';
  }
}

function statusLabel(status: DemoRequestStatus): string {
  return DEMO_REQUEST_STATUS_LABELS[status] ?? status;
}

// ── Social-media helpers ────────────────────────────────────────────
function socialEntries(
  sm: DemoRequesterSocialMedia | null | undefined,
): { label: string; value: string }[] {
  if (!sm) return [];
  return (Object.keys(sm) as (keyof DemoRequesterSocialMedia)[])
    .filter((k) => sm[k]?.trim())
    .map((k) => ({
      label: DEMO_SOCIAL_LABELS[k] ?? k,
      value: sm[k] as string,
    }));
}

// ── Label maps for enum-ish payload fields ──────────────────────────
function roleModeLabel(mode: string | undefined): string {
  if (mode === 'single_role') return t('superAdmin.demoDetail.roleModeSingle');
  if (mode === 'all_roles') return t('superAdmin.demoDetail.roleModeAll');
  return '—';
}

function roleLabel(role: string | undefined): string {
  switch (role) {
    case 'admin':
      return t('superAdmin.demoDetail.roleAdmin');
    case 'teacher':
      return t('superAdmin.demoDetail.roleTeacher');
    case 'parent':
      return t('superAdmin.demoDetail.roleParent');
    default:
      return role ?? '—';
  }
}

function fillModeLabel(mode: string | undefined): string {
  switch (mode) {
    case 'random':
      return t('superAdmin.demoDetail.fillRandom');
    case 'manual':
      return t('superAdmin.demoDetail.fillManual');
    case 'csv':
      return t('superAdmin.demoDetail.fillCsv');
    default:
      return mode ?? '—';
  }
}

function classPatternLabel(pattern: string | undefined): string {
  switch (pattern) {
    case 'small':
      return t('superAdmin.demoDetail.patternSmall');
    case 'medium':
      return t('superAdmin.demoDetail.patternMedium');
    case 'large':
      return t('superAdmin.demoDetail.patternLarge');
    case 'custom':
      return t('superAdmin.demoDetail.patternCustom');
    default:
      return pattern ?? '—';
  }
}

function parentModeLabel(mode: string | undefined): string {
  if (mode === 'auto_link') return t('superAdmin.demoDetail.parentAutoLink');
  if (mode === 'skip') return t('superAdmin.demoDetail.parentSkip');
  return mode ?? '—';
}

function scheduleModeLabel(mode: string | undefined): string {
  if (mode === 'auto') return t('superAdmin.demoDetail.scheduleAuto');
  if (mode === 'manual') return t('superAdmin.demoDetail.scheduleManual');
  return mode ?? '—';
}

function billingModeLabel(
  mode: string | string[] | undefined,
): string {
  // The tutoring wizard now sends `billing_mode` as an array
  // (multi-select). Older school-path payloads + legacy demo_requests
  // rows still carry it as a single string — accept both shapes and
  // pretty-print the array as a comma-joined list.
  if (Array.isArray(mode)) {
    return mode.length === 0 ? '—' : mode.join(', ');
  }
  if (mode === 'build_year') return t('superAdmin.demoDetail.billingBuildYear');
  if (mode === 'skip') return t('superAdmin.demoDetail.billingSkip');
  return mode ?? '—';
}

// Indonesian weekday names indexed 1..7 (Monday=1, matching the wizard's
// `active_days` payload). 0 is unused.
const WEEKDAY_LABELS = [
  '',
  'superAdmin.demoDetail.dayMon',
  'superAdmin.demoDetail.dayTue',
  'superAdmin.demoDetail.dayWed',
  'superAdmin.demoDetail.dayThu',
  'superAdmin.demoDetail.dayFri',
  'superAdmin.demoDetail.daySat',
  'superAdmin.demoDetail.daySun',
];

const activeDayLabels = computed<string[]>(() => {
  const days = payload.value?.schedule?.active_days ?? [];
  return days
    .filter((d) => d >= 1 && d <= 7)
    .sort((a, b) => a - b)
    .map((d) => t(WEEKDAY_LABELS[d]));
});

// Billing templates → existing registerDemo.* labels (reused, not dup'd).
const BILLING_TEMPLATE_KEYS: Record<string, string> = {
  spp_bulanan: 'registerDemo.billingTemplateSppBulanan',
  uang_gedung: 'registerDemo.billingTemplateUangGedung',
  seragam: 'registerDemo.billingTemplateSeragam',
  buku_paket: 'registerDemo.billingTemplateBukuPaket',
  uts_uas: 'registerDemo.billingTemplateUtsUas',
  ekstrakurikuler: 'registerDemo.billingTemplateEkstrakurikuler',
};

function billingTemplateLabel(key: string): string {
  const k = BILLING_TEMPLATE_KEYS[key];
  return k ? t(k) : key;
}

// Scenario key → human label (reuse the wizard's SCENARIO_DEFINITIONS).
const SCENARIO_LABELS = new Map<DemoScenarioKey, string>(
  SCENARIO_DEFINITIONS.map((d) => [d.key, d.label]),
);

function scenarioLabel(key: DemoScenarioKey): string {
  return SCENARIO_LABELS.get(key) ?? key;
}

// ── Per-grade class rows (Record<grade, count> → sorted table rows) ──
const perGradeRows = computed<{ grade: string; count: number }[]>(() => {
  const pg = payload.value?.classes?.per_grade ?? {};
  return Object.entries(pg)
    .map(([grade, count]) => ({ grade, count: Number(count) }))
    .sort((a, b) => {
      const na = Number(a.grade);
      const nb = Number(b.grade);
      if (!Number.isNaN(na) && !Number.isNaN(nb)) return na - nb;
      return a.grade.localeCompare(b.grade);
    });
});

const totalClasses = computed(() =>
  perGradeRows.value.reduce((sum, r) => sum + r.count, 0),
);

// ── Review actions (approve / reject) ───────────────────────────────
type ReviewMode = 'approve' | 'reject';
const reviewMode = ref<ReviewMode | null>(null);
const reviewNote = ref('');
const reviewSubmitting = ref(false);
const reviewError = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

function startReview(mode: ReviewMode) {
  reviewMode.value = mode;
  reviewNote.value = '';
  reviewError.value = null;
}

function cancelReview() {
  reviewMode.value = null;
  reviewNote.value = '';
  reviewError.value = null;
}

async function submitReview() {
  if (!detail.value || !reviewMode.value) return;
  reviewSubmitting.value = true;
  reviewError.value = null;
  try {
    if (reviewMode.value === 'approve') {
      detail.value = await DemoRequestService.approve(
        detail.value.id,
        reviewNote.value,
      );
      toast.value = {
        message: t('superAdmin.demoDetail.approvedToast'),
        tone: 'success',
      };
    } else {
      detail.value = await DemoRequestService.reject(
        detail.value.id,
        reviewNote.value,
      );
      toast.value = {
        message: t('superAdmin.demoDetail.rejectedToast'),
        tone: 'success',
      };
    }
    cancelReview();
  } catch (e) {
    reviewError.value = (e as Error).message;
  } finally {
    reviewSubmitting.value = false;
  }
}

function goBack() {
  router.push({ name: 'super-admin.demo-requests' });
}

// ── Extend demo actions ─────────────────────────────────────────────
const extendModalOpen = ref(false);
const extendDays = ref(7);
const customExtendDays = ref(7);
const extendNote = ref('');
const extending = ref(false);
const extendError = ref<string | null>(null);

function openExtendModal() {
  extendModalOpen.value = true;
  extendDays.value = 7;
  customExtendDays.value = 7;
  extendNote.value = '';
  extendError.value = null;
}

function closeExtendModal() {
  extendModalOpen.value = false;
  extendError.value = null;
}

function getActualDays(): number {
  return extendDays.value === 0 ? customExtendDays.value : extendDays.value;
}

async function submitExtend() {
  if (!detail.value) return;
  const days = getActualDays();
  if (days <= 0) {
    extendError.value = 'Durasi perpanjangan harus minimal 1 hari.';
    return;
  }
  extending.value = true;
  extendError.value = null;
  try {
    detail.value = await DemoRequestService.extend(
      detail.value.id,
      days,
      extendNote.value,
    );
    toast.value = {
      message: `Masa aktif demo berhasil diperpanjang selama ${days} hari.`,
      tone: 'success',
    };
    closeExtendModal();
  } catch (e) {
    extendError.value = (e as Error).message;
  } finally {
    extending.value = false;
  }
}

// Called after a successful demo-account deletion from the management
// section. Surface a summary toast (the section itself refreshes counts).
function onAccountsDeleted(result: DemoAccountDeleteResult) {
  toast.value = {
    message: t('superAdmin.demoAccounts.deletedToast', {
      count: result.deleted_users,
    }),
    tone: 'success',
  };
}

// Called after the ENTIRE demo school is deleted. The school no longer
// exists, so this detail page can't meaningfully re-render — show a
// success toast, then navigate back to the demo-requests list. A short
// delay lets the operator see the confirmation before we leave.
function onSchoolDeleted(result: DeleteDemoSchoolResult) {
  toast.value = {
    message: t('superAdmin.demoAccounts.schoolDeletedToast', {
      name: result.school_name ?? detail.value?.school_summary?.name ?? '',
    }),
    tone: 'success',
  };
  window.setTimeout(goBack, 1200);
}

/**
 * Called after a successful demo-school reset. The school row was
 * REPLACED (delete + re-provision) — the request's
 * `activated_school_id` now points at a different uuid, the cached
 * `school_payload` is stale (if the operator used "Ubah konfigurasi"),
 * and the account counts in DemoAccountManagementSection are for the
 * old school. Easiest correct refresh: re-fetch the whole detail and
 * let the page re-render with the new linkage.
 */
function onSchoolReset(result: {
  school_id: string;
  school_name: string;
  tenant_type: string;
  demo_expires_at: string | null;
}) {
  toast.value = {
    message: `Sekolah demo "${result.school_name}" berhasil direset.`,
    tone: 'success',
  };
  // Re-fetch the detail so activated_school_id + school_payload reflect
  // the new school. `load()` is the same async fetch the page runs
  // on mount.
  void load();
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="admin"
      :kicker="t('superAdmin.kicker')"
      :title="detail?.school_summary?.name ?? t('superAdmin.demoDetail.title')"
      :meta="
        detail
          ? `${t('superAdmin.demoDetail.submittedAt')} ${formatDateTime(detail.created_at) || '—'}`
          : t('superAdmin.demoDetail.loading')
      "
    >
      <button
        type="button"
        class="inline-flex items-center gap-1.5 rounded-xl bg-white/15 hover:bg-white/25 px-3 py-1.5 text-xs font-bold text-white transition"
        @click="goBack"
      >
        <NavIcon name="chevron-left" :size="14" />
        {{ t('superAdmin.demoDetail.back') }}
      </button>
    </BrandPageHeader>

    <AsyncView
      :state="detailState"
      :empty-title="t('superAdmin.demoDetail.emptyTitle')"
      :empty-description="t('superAdmin.demoDetail.emptyDescription')"
      empty-icon="inbox"
      @retry="load"
    >
      <div v-if="detail" class="space-y-4">
        <!-- META / STATUS BANNER -->
        <div
          class="bg-white border border-slate-200 rounded-2xl p-4 flex flex-wrap items-start gap-x-6 gap-y-3"
        >
          <div
            class="rounded-xl border px-3 py-1.5 text-xs font-bold inline-flex items-center gap-2 self-center"
            :class="statusTone(detail.status)"
          >
            <span class="w-1.5 h-1.5 rounded-full bg-current"></span>
            {{ statusLabel(detail.status) }}
            <span
              v-if="detail.status === 'approved' && detail.demo_expires_at"
              class="font-medium opacity-80"
            >
              · {{ t('superAdmin.demoDetail.validUntil') }}
              {{ formatDateTime(detail.demo_expires_at) }}
            </span>
          </div>

          <dl class="flex flex-wrap gap-x-6 gap-y-2 text-sm flex-1 min-w-0">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.requester') }}
              </dt>
              <dd class="font-semibold text-slate-900 truncate">
                {{ detail.requester?.name ?? detail.full_name ?? '—' }}
              </dd>
            </div>
            <div v-if="detail.requester?.email">
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.accountEmail') }}
              </dt>
              <dd class="font-semibold text-slate-900 truncate">
                {{ detail.requester?.email }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.submittedAt') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ formatDateTime(detail.created_at) || '—' }}
              </dd>
            </div>
            <div v-if="detail.reviewed_at">
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.reviewedAt') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ formatDateTime(detail.reviewed_at) }}
              </dd>
            </div>
            <div v-if="detail.activated_school_id">
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.activatedSchool') }}
              </dt>
              <dd class="font-semibold text-emerald-600">
                {{ t('superAdmin.demoDetail.activatedYes') }}
              </dd>
            </div>
          </dl>
        </div>

        <!-- SECTION 1 · IDENTITAS PEMOHON -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionIdentity') }}
          </h2>
          <dl class="grid grid-cols-2 sm:grid-cols-3 gap-x-4 gap-y-3 text-sm">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.fullName') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ detail.full_name || '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.nip') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ detail.nip || '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.jabatan') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ detail.jabatan || '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.whatsapp') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ detail.whatsapp || '—' }}
              </dd>
            </div>
          </dl>

          <div class="mt-3">
            <p class="text-2xs text-slate-400 mb-1.5">
              {{ t('superAdmin.demoDetail.socialMedia') }}
            </p>
            <div
              v-if="socialEntries(detail.social_media).length"
              class="flex flex-wrap gap-1.5"
            >
              <span
                v-for="s in socialEntries(detail.social_media)"
                :key="s.label"
                class="inline-flex items-center gap-1 text-2xs font-medium bg-slate-100 text-slate-600 rounded-full px-2.5 py-1"
              >
                <span class="font-bold text-slate-500">{{ s.label }}:</span>
                <span class="truncate max-w-[220px]">{{ s.value }}</span>
              </span>
            </div>
            <p v-else class="text-xs text-slate-400 italic">
              {{ t('superAdmin.demoDetail.noSocial') }}
            </p>
          </div>
        </section>

        <!-- SECTION 1B · RIWAYAT PENDAFTARAN LAIN -->
        <section v-if="detail && ((detail.active_schools && detail.active_schools.length > 0) || (detail.other_requests && detail.other_requests.length > 0))" class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2 class="text-2xs font-black uppercase tracking-widest text-indigo-600 mb-3">
            Riwayat Pendaftar (Multi-Tenant)
          </h2>
          <p class="text-xs text-slate-500 mb-3">
            Pendaftar ini terdeteksi memiliki registrasi atau lembaga aktif lain di bawah akun yang sama.
          </p>

          <div class="space-y-2">
            <!-- Active schools -->
            <div v-for="school in detail.active_schools" :key="school.id" class="flex items-center justify-between p-2.5 bg-slate-50 border border-slate-100 rounded-lg text-xs">
              <div class="flex items-center gap-2">
                <span>{{ normalizeTenantType(school.tenant_type) === 'tutoring' ? '📚' : '🏫' }}</span>
                <div>
                  <div class="font-bold text-slate-800">{{ school.name }}</div>
                  <div class="text-3xs text-slate-400 uppercase tracking-wider font-semibold">Lembaga Aktif</div>
                </div>
              </div>
              <span class="px-2 py-0.5 rounded bg-emerald-50 text-emerald-700 font-semibold text-3xs uppercase tracking-wider">
                Aktif
              </span>
            </div>

            <!-- Other requests -->
            <div v-for="req in detail.other_requests" :key="req.id" class="flex items-center justify-between p-2.5 bg-slate-50/50 border border-slate-100/50 rounded-lg text-xs">
              <div class="flex items-center gap-2">
                <span>{{ normalizeTenantType(req.tenant_type) === 'tutoring' ? '📚' : '🏫' }}</span>
                <div>
                  <div class="font-semibold text-slate-700">{{ req.school_name || 'Tanpa Nama' }}</div>
                  <div class="text-3xs text-slate-400">Pengajuan: {{ formatDateTime(req.created_at) }}</div>
                </div>
              </div>
              <div>
                <span v-if="req.status === 'pending'" class="px-2 py-0.5 rounded bg-amber-50 text-amber-700 font-semibold text-3xs uppercase tracking-wider">
                  Pending
                </span>
                <span v-else-if="req.status === 'rejected'" class="px-2 py-0.5 rounded bg-red-50 text-red-700 font-semibold text-3xs uppercase tracking-wider">
                  Ditolak
                </span>
                <span v-else-if="req.status === 'expired'" class="px-2 py-0.5 rounded bg-slate-100 text-slate-600 font-semibold text-3xs uppercase tracking-wider">
                  Kedaluwarsa
                </span>
                <span v-else class="px-2 py-0.5 rounded bg-emerald-50 text-emerald-700 font-semibold text-3xs uppercase tracking-wider">
                  Disetujui
                </span>
              </div>
            </div>
          </div>
        </section>

        <!-- SECTION 2 · DATA SEKOLAH ATAU BIMBEL -->
        <section v-if="isTutoringPayload" class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            DATA BIMBEL
          </h2>
          <dl class="grid grid-cols-2 sm:grid-cols-3 gap-x-4 gap-y-3 text-sm">
            <div>
              <dt class="text-2xs text-slate-400">
                Nama Bimbel
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ tutoringSlice?.name ?? detail.school_summary?.name ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                Jenjang
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ tutoringSlice?.target_levels?.join(', ') ?? detail.school_summary?.education_level ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                Kota
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ tutoringSlice?.city ?? detail.school_summary?.city ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                Skala Siswa
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ tutoringSlice?.student_scale ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                Skala Tutor
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ tutoringSlice?.tutor_scale ?? '—' }}
              </dd>
            </div>
          </dl>
        </section>

        <section v-else class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionSchool') }}
          </h2>
          <dl class="grid grid-cols-2 sm:grid-cols-3 gap-x-4 gap-y-3 text-sm">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.schoolName') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{
                  payload?.school?.name ?? detail.school_summary?.name ?? '—'
                }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.educationLevel') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{
                  payload?.school?.education_level ??
                  detail.school_summary?.education_level ??
                  '—'
                }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.city') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{
                  payload?.school?.city ?? detail.school_summary?.city ?? '—'
                }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.npsn') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{
                  payload?.school?.npsn ?? detail.school_summary?.npsn ?? '—'
                }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.academicYear') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ payload?.school?.academic_year_label ?? '—' }}
              </dd>
            </div>
            <div v-if="payload?.identity">
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.roleMode') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ roleModeLabel(payload.identity.mode) }}
                <span class="text-slate-400 font-normal">
                  · {{ roleLabel(payload.identity.primary_role) }}
                </span>
              </dd>
            </div>
          </dl>
        </section>

        <template v-if="!isTutoringPayload">
        <!-- SECTION 3 · MATA PELAJARAN -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionSubjects') }}
            <span
              v-if="payload?.subjects?.names?.length"
              class="text-slate-300 font-bold"
            >
              · {{ payload.subjects.names.length }}
            </span>
          </h2>
          <div
            v-if="payload?.subjects?.names?.length"
            class="flex flex-wrap gap-1.5"
          >
            <span
              v-for="name in payload.subjects.names"
              :key="name"
              class="inline-flex text-xs font-medium bg-role-admin-soft text-role-admin rounded-lg px-2.5 py-1"
            >
              {{ name }}
            </span>
          </div>
          <p v-else class="text-xs text-slate-400 italic">
            {{ t('superAdmin.demoDetail.emptySection') }}
          </p>
        </section>

        <!-- SECTION 4 · GURU -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionTeachers') }}
          </h2>
          <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm mb-3">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.teacherCount') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ payload?.teachers?.count ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.fillMode') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ fillModeLabel(payload?.teachers?.fill_mode) }}
              </dd>
            </div>
          </dl>

          <div
            v-if="payload?.teachers?.manual_list?.length"
            class="overflow-x-auto rounded-xl border border-slate-100"
          >
            <table class="w-full text-sm">
              <thead>
                <tr class="bg-slate-50 text-2xs text-slate-400 text-left">
                  <th class="px-3 py-2 font-bold">#</th>
                  <th class="px-3 py-2 font-bold">
                    {{ t('superAdmin.demoDetail.teacherName') }}
                  </th>
                  <th class="px-3 py-2 font-bold">
                    {{ t('superAdmin.demoDetail.teacherSubject') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(teacher, i) in payload.teachers.manual_list"
                  :key="i"
                  class="border-t border-slate-100"
                >
                  <td class="px-3 py-2 text-slate-400 tabular-nums">
                    {{ i + 1 }}
                  </td>
                  <td class="px-3 py-2 font-medium text-slate-900">
                    {{ teacher.name || '—' }}
                  </td>
                  <td class="px-3 py-2 text-slate-600">
                    {{ teacher.subject || '—' }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p
            v-else-if="payload?.teachers?.fill_mode === 'manual'"
            class="text-xs text-slate-400 italic"
          >
            {{ t('superAdmin.demoDetail.emptyManualTeachers') }}
          </p>
        </section>

        <!-- SECTION 5 · KELAS -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionClasses') }}
          </h2>
          <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm mb-3">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.classPattern') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ classPatternLabel(payload?.classes?.pattern) }}
              </dd>
            </div>
            <div v-if="totalClasses > 0">
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.totalClasses') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ totalClasses }}
              </dd>
            </div>
          </dl>

          <div
            v-if="perGradeRows.length"
            class="overflow-x-auto rounded-xl border border-slate-100"
          >
            <table class="w-full text-sm">
              <thead>
                <tr class="bg-slate-50 text-2xs text-slate-400 text-left">
                  <th class="px-3 py-2 font-bold">
                    {{ t('superAdmin.demoDetail.grade') }}
                  </th>
                  <th class="px-3 py-2 font-bold">
                    {{ t('superAdmin.demoDetail.classCount') }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in perGradeRows"
                  :key="row.grade"
                  class="border-t border-slate-100"
                >
                  <td class="px-3 py-2 font-medium text-slate-900">
                    {{
                      t('superAdmin.demoDetail.gradeLabel', {
                        grade: row.grade,
                      })
                    }}
                  </td>
                  <td class="px-3 py-2 text-slate-600 tabular-nums">
                    {{ row.count }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <p v-else class="text-xs text-slate-400 italic">
            {{ t('superAdmin.demoDetail.noPerGrade') }}
          </p>
        </section>

        <!-- SECTION 6 · SISWA -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionStudents') }}
          </h2>
          <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.perClass') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ payload?.students?.per_class ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.fillMode') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ fillModeLabel(payload?.students?.fill_mode) }}
              </dd>
            </div>
          </dl>
        </section>

        <!-- SECTION 7 · ORANG TUA -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionParents') }}
          </h2>
          <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.parentMode') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ parentModeLabel(payload?.parents?.mode) }}
              </dd>
            </div>
          </dl>
        </section>

        <!-- SECTION 8 · JADWAL -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionSchedule') }}
          </h2>
          <dl
            class="grid grid-cols-2 sm:grid-cols-4 gap-x-4 gap-y-3 text-sm mb-3"
          >
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.scheduleMode') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ scheduleModeLabel(payload?.schedule?.mode) }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.jpPerDay') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ payload?.schedule?.jp_per_day ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.startTime') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ payload?.schedule?.start_time ?? '—' }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.endTime') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{ payload?.schedule?.end_time ?? '—' }}
              </dd>
            </div>
          </dl>
          <div>
            <p class="text-2xs text-slate-400 mb-1.5">
              {{ t('superAdmin.demoDetail.activeDays') }}
            </p>
            <div v-if="activeDayLabels.length" class="flex flex-wrap gap-1.5">
              <span
                v-for="day in activeDayLabels"
                :key="day"
                class="inline-flex text-2xs font-medium bg-slate-100 text-slate-600 rounded-full px-2.5 py-1"
              >
                {{ day }}
              </span>
            </div>
            <p v-else class="text-xs text-slate-400 italic">
              {{ t('superAdmin.demoDetail.emptySection') }}
            </p>
          </div>
        </section>

        <!-- SECTION 9 · SKENARIO -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionScenarios') }}
            <span
              v-if="payload?.scenarios?.enabled?.length"
              class="text-slate-300 font-bold"
            >
              · {{ payload.scenarios.enabled.length }}
            </span>
          </h2>
          <div
            v-if="payload?.scenarios?.enabled?.length"
            class="flex flex-wrap gap-1.5"
          >
            <span
              v-for="key in payload.scenarios.enabled"
              :key="key"
              class="inline-flex items-center gap-1 text-2xs font-medium bg-emerald-50 text-emerald-700 border border-emerald-100 rounded-full px-2.5 py-1"
            >
              <NavIcon name="check" :size="12" />
              {{ scenarioLabel(key) }}
            </span>
          </div>
          <p v-else class="text-xs text-slate-400 italic">
            {{ t('superAdmin.demoDetail.noScenarios') }}
          </p>
        </section>
        </template>

        <!-- SECTION 10 · PEMBAYARAN -->
        <section class="bg-white border border-slate-200 rounded-2xl p-4">
          <h2
            class="text-2xs font-black uppercase tracking-widest text-role-admin mb-3"
          >
            {{ t('superAdmin.demoDetail.sectionBilling') }}
          </h2>
          <dl class="grid grid-cols-2 gap-x-4 gap-y-3 text-sm mb-3">
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.billingMode') }}
              </dt>
              <dd class="font-semibold text-slate-900">
                {{ billingModeLabel(payload?.bimbel?.billing_mode ?? payload?.billing?.mode) }}
              </dd>
            </div>
            <div>
              <dt class="text-2xs text-slate-400">
                {{ t('superAdmin.demoDetail.sppNominal') }}
              </dt>
              <dd class="font-semibold text-slate-900 tabular-nums">
                {{
                  payload?.billing?.spp_nominal != null
                    ? formatRupiah(payload.billing.spp_nominal)
                    : '—'
                }}
              </dd>
            </div>
          </dl>
          <div>
            <p class="text-2xs text-slate-400 mb-1.5">
              {{ t('superAdmin.demoDetail.billingTemplates') }}
            </p>
            <div
              v-if="payload?.billing?.templates?.length"
              class="flex flex-wrap gap-1.5"
            >
              <span
                v-for="tpl in payload.billing.templates"
                :key="tpl"
                class="inline-flex text-2xs font-medium bg-slate-100 text-slate-600 rounded-full px-2.5 py-1"
              >
                {{ billingTemplateLabel(tpl) }}
              </span>
            </div>
            <p v-else class="text-xs text-slate-400 italic">
              {{ t('superAdmin.demoDetail.emptySection') }}
            </p>
          </div>
        </section>

        <!-- KELOLA AKUN DEMO — only for an ACTIVATED demo school.
             Deletion is gated server-side to is_demo=true tenants. -->
        <DemoAccountManagementSection
          v-if="['approved', 'expired'].includes(detail.status) && detail.activated_school_id"
          :school-id="detail.activated_school_id"
          :school-name="
            payload?.bimbel?.name ?? payload?.school?.name ?? detail.school_summary?.name ?? null
          "
          :current-payload="payload as Record<string, unknown> | null"
          @deleted="onAccountsDeleted"
          @school-deleted="onSchoolDeleted"
          @reset="onSchoolReset"
        />

        <!-- REVIEW NOTE (if reviewed) -->
        <section
          v-if="detail.review_note || detail.reviewed_at"
          class="bg-slate-50 border border-slate-200 rounded-2xl p-4"
        >
          <h2
            class="text-2xs font-black uppercase tracking-widest text-slate-400 mb-2"
          >
            {{ t('superAdmin.demoDetail.reviewNote') }}
          </h2>
          <p v-if="detail.review_note" class="text-sm text-slate-700">
            {{ detail.review_note }}
          </p>
          <p v-if="detail.reviewed_at" class="text-2xs text-slate-400 mt-1">
            {{ t('superAdmin.demoDetail.reviewedAt') }}
            {{ formatDateTime(detail.reviewed_at) }}
          </p>
        </section>

        <!-- REVIEW FORM (inline) -->
        <section
          v-if="reviewMode"
          class="rounded-2xl border px-4 py-3.5"
          :class="
            reviewMode === 'approve'
              ? 'border-emerald-200 bg-emerald-50/50'
              : 'border-red-200 bg-red-50/50'
          "
        >
          <p class="text-xs font-bold text-slate-700 mb-2">
            <template v-if="reviewMode === 'approve'">
              {{ t('superAdmin.demoDetail.approveConfirm') }}
            </template>
            <template v-else>
              {{ t('superAdmin.demoDetail.rejectConfirm') }}
            </template>
          </p>
          <label class="block text-2xs font-semibold text-slate-500 mb-1">
            {{
              reviewMode === 'approve'
                ? t('superAdmin.demoDetail.noteOptional')
                : t('superAdmin.demoDetail.reasonOptional')
            }}
          </label>
          <textarea
            v-model="reviewNote"
            rows="2"
            maxlength="1000"
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            :placeholder="
              reviewMode === 'approve'
                ? t('superAdmin.demoDetail.notePlaceholder')
                : t('superAdmin.demoDetail.reasonPlaceholder')
            "
          ></textarea>
          <p v-if="reviewError" class="text-xs text-red-600 mt-2">
            {{ reviewError }}
          </p>
          <div class="flex items-center justify-end gap-2 mt-3">
            <Button variant="ghost" size="sm" @click="cancelReview">
              {{ t('superAdmin.demoDetail.cancel') }}
            </Button>
            <Button
              :variant="reviewMode === 'approve' ? 'success' : 'danger'"
              size="sm"
              :loading="reviewSubmitting"
              @click="submitReview"
            >
              {{
                reviewMode === 'approve'
                  ? t('superAdmin.demoDetail.confirmApprove')
                  : t('superAdmin.demoDetail.confirmReject')
              }}
            </Button>
          </div>
        </section>

        <!-- FOOTER ACTIONS -->
        <footer
          v-if="!reviewMode"
          class="flex flex-wrap items-center justify-end gap-2 pt-1"
        >
          <Button variant="secondary" size="sm" @click="goBack">
            {{ t('superAdmin.demoDetail.backToList') }}
          </Button>
          
          <!-- Reactivate / Activate from registration payload (Scenario B or Pending) -->
          <template v-if="detail.status === 'pending' || (detail.status === 'expired' && !detail.activated_school_id)">
            <Button v-if="detail.status === 'pending'" variant="danger" size="sm" @click="startReview('reject')">
              <NavIcon name="x" :size="14" />
              {{ t('superAdmin.demoDetail.reject') }}
            </Button>
            <Button variant="success" size="sm" @click="startReview('approve')">
              <NavIcon name="check" :size="14" />
              {{ detail.status === 'expired' ? 'Aktifkan Kembali' : t('superAdmin.demoDetail.activate') }}
            </Button>
          </template>

          <!-- Extend / Reactivate existing school (Scenario A or Approved) -->
          <template v-else-if="['approved', 'expired'].includes(detail.status) && detail.activated_school_id">
            <Button variant="primary" size="sm" @click="openExtendModal">
              <NavIcon name="calendar" :size="14" />
              Perpanjang Demo
            </Button>
          </template>

          <!-- Fallback text for rejected or other conditions -->
          <span v-else class="text-2xs text-slate-400">
            {{
              t('superAdmin.demoDetail.alreadyReviewed', {
                status: statusLabel(detail.status).toLowerCase(),
              })
            }}
          </span>
        </footer>
      </div>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />

    <!-- EXTEND MODAL -->
    <Modal
      v-if="extendModalOpen"
      size="sm"
      title="Perpanjang Masa Aktif Demo"
      @close="closeExtendModal"
    >
      <div class="space-y-4 text-left">
        <p class="text-xs text-slate-500 leading-relaxed">
          Masukkan jumlah hari untuk memperpanjang masa aktif demo. Jika demo sudah kedaluwarsa, masa aktif baru akan dihitung mulai dari hari ini.
        </p>

        <div>
          <label class="block text-xs font-semibold text-slate-700 mb-1">
            Durasi Perpanjangan (Hari)
          </label>
          <select
            v-model="extendDays"
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300 bg-white"
          >
            <option :value="7">7 Hari</option>
            <option :value="14">14 Hari</option>
            <option :value="30">30 Hari</option>
            <option :value="0">Kustom...</option>
          </select>
        </div>

        <div v-if="extendDays === 0">
          <label class="block text-xs font-semibold text-slate-700 mb-1">
            Jumlah Hari Kustom
          </label>
          <input
            v-model.number="customExtendDays"
            type="number"
            min="1"
            max="90"
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300"
          />
        </div>

        <div>
          <label class="block text-xs font-semibold text-slate-700 mb-1">
            Catatan Perpanjangan
          </label>
          <textarea
            v-model="extendNote"
            rows="3"
            placeholder="Alasan perpanjangan atau catatan tambahan..."
            class="w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-primary-300 resize-none"
          ></textarea>
        </div>

        <p v-if="extendError" class="text-xs text-red-600">
          {{ extendError }}
        </p>

        <div class="flex items-center justify-end gap-2 pt-2">
          <Button variant="ghost" size="sm" :disabled="extending" @click="closeExtendModal">
            Batal
          </Button>
          <Button
            variant="primary"
            size="sm"
            :loading="extending"
            :disabled="extending || getActualDays() <= 0"
            @click="submitExtend"
          >
            <NavIcon name="calendar" :size="14" />
            Simpan
          </Button>
        </div>
      </div>
    </Modal>
  </div>
</template>
