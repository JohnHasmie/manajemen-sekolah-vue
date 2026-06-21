<!--
  AdminTeacherAttendanceView.vue — admin config + report for PRESENSI GURU.

  Two tabs:
    (a) Pengaturan — toggle camera_required / location_required /
        checkout_enabled, set the geofence centre (lat/lng), radius,
        out-of-radius behaviour, and the late grace. The geofence centre
        falls back to the school pin (school_latitude/longitude) when
        left blank. Partial PUT — only changed keys are sent.
    (b) Laporan — two stacked sections sharing one periode (date-range)
        filter:
          · REKAP per-guru — aggregated Hadir/Telat/(Alpa/Izin…)/Total/%
            table (GET …/admin/summary) with an Export Excel (CSV) button.
            Status columns are DYNAMIC — driven by meta.statuses.
          · Detail per-baris — the school-scoped per-row list
            (GET …/admin) with the existing date/teacher/status filters,
            collapsible below the rekap.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import GeofenceMapPicker from '@/components/feature/GeofenceMapPicker.vue';
import { useToast } from '@/composables/useToast';
import type {
  TeacherAttendanceAdminSummary,
  TeacherAttendanceListResult,
  TeacherAttendanceRecord,
  TeacherAttendanceSettings,
  TeacherAttendanceSummaryRow,
} from '@/types/teacher-attendance';
import {
  DEFAULT_TEACHER_ATTENDANCE_SETTINGS,
  teacherAttendanceStatusColumnLabel,
  teacherAttendanceStatusLabel,
} from '@/types/teacher-attendance';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';

const toast = useToast();
const { t } = useI18n();

type Tab = 'settings' | 'rules' | 'report';
const tab = ref<Tab>('settings');

// ─────────────────────────────────────────────────────────────────
// Settings tab
// ─────────────────────────────────────────────────────────────────
/** Working copy edited by the form. */
const form = ref<TeacherAttendanceSettings>({
  ...DEFAULT_TEACHER_ATTENDANCE_SETTINGS,
});
const settingsLoading = ref(true);
const settingsError = ref<string | null>(null);
const saving = ref(false);

/**
 * lat/lng are bound as strings so an empty field reads as "use the
 * school pin" (null) rather than 0. We convert on save.
 */
const geofenceLatStr = ref('');
const geofenceLngStr = ref('');

function syncGeofenceStrings(s: TeacherAttendanceSettings) {
  geofenceLatStr.value = s.geofence_lat != null ? String(s.geofence_lat) : '';
  geofenceLngStr.value = s.geofence_lng != null ? String(s.geofence_lng) : '';
}

const schoolPinLabel = computed(() => {
  const lat = form.value.school_latitude;
  const lng = form.value.school_longitude;
  if (lat == null || lng == null) return 'Belum diatur';
  return `${lat.toFixed(6)}, ${lng.toFixed(6)}`;
});

async function loadSettings() {
  settingsLoading.value = true;
  settingsError.value = null;
  try {
    const s = await TeacherAttendanceService.getSettings();
    form.value = s;
    syncGeofenceStrings(s);
  } catch (e) {
    settingsError.value = (e as Error).message;
  } finally {
    settingsLoading.value = false;
  }
}

function parseCoord(raw: string): number | null {
  const t = raw.trim();
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

// Map picker → write the chosen point into the lat/long string fields
// (which save() then parses), so manual entry and the map stay in sync.
function onMapPick(p: { lat: number; lng: number }) {
  geofenceLatStr.value = String(p.lat);
  geofenceLngStr.value = String(p.lng);
}

async function saveSettings() {
  // Validate ranges client-side for a friendly message before the
  // backend's 422 (which uses the same bounds).
  const lat = parseCoord(geofenceLatStr.value);
  const lng = parseCoord(geofenceLngStr.value);
  if (lat != null && (lat < -90 || lat > 90)) {
    toast.error('Latitude geofence harus antara -90 dan 90.');
    return;
  }
  if (lng != null && (lng < -180 || lng > 180)) {
    toast.error('Longitude geofence harus antara -180 dan 180.');
    return;
  }
  if (
    form.value.geofence_radius_m < 10 ||
    form.value.geofence_radius_m > 5000
  ) {
    toast.error('Radius geofence harus antara 10 dan 5000 meter.');
    return;
  }
  if (
    form.value.late_grace_minutes < 0 ||
    form.value.late_grace_minutes > 600
  ) {
    toast.error('Toleransi keterlambatan harus antara 0 dan 600 menit.');
    return;
  }

  saving.value = true;
  try {
    const saved = await TeacherAttendanceService.updateSettings({
      camera_required: form.value.camera_required,
      location_required: form.value.location_required,
      checkout_enabled: form.value.checkout_enabled,
      geofence_lat: lat,
      geofence_lng: lng,
      geofence_radius_m: form.value.geofence_radius_m,
      reject_outside_geofence: form.value.reject_outside_geofence,
      late_grace_minutes: form.value.late_grace_minutes,
    });
    form.value = saved;
    syncGeofenceStrings(saved);
    toast.success('Pengaturan presensi guru tersimpan.');
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    saving.value = false;
  }
}

// ─────────────────────────────────────────────────────────────────
// Report tab — shared periode (date range) filter
//
// The periode drives BOTH the per-guru rekap (admin/summary) and the
// detail per-row list (admin). Empty bounds let the backend default to
// start-of-month → today.
// ─────────────────────────────────────────────────────────────────
const filterStartDate = ref('');
const filterEndDate = ref('');
const filterTeacher = ref('');
/** Detail-only filters (the rekap ignores these). */
const filterDate = ref('');
const filterStatus = ref<'' | 'present' | 'late'>('');
const reportPage = ref(1);
const reportPerPage = 25;
/** Detail per-row list is collapsed by default — rekap leads. */
const showDetail = ref(false);

// ── Per-guru REKAP (admin/summary) ──────────────────────────────────
const summary = ref<TeacherAttendanceAdminSummary | null>(null);
const summaryLoading = ref(false);
const summaryError = ref<string | null>(null);
const summaryLoaded = ref(false);

const summaryRows = computed<TeacherAttendanceSummaryRow[]>(
  () => summary.value?.data ?? [],
);
const summaryStatuses = computed<string[]>(
  () => summary.value?.meta.statuses ?? ['present', 'late'],
);
const summaryTotals = computed(() => summary.value?.totals ?? null);

const summaryState = computed<AsyncState<TeacherAttendanceSummaryRow[]>>(() => {
  if (summaryLoading.value && summaryRows.value.length === 0)
    return { status: 'loading' };
  if (summaryError.value)
    return { status: 'error', error: summaryError.value };
  if (summaryRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: summaryRows.value };
});

async function loadSummary() {
  summaryLoading.value = true;
  summaryError.value = null;
  try {
    summary.value = await TeacherAttendanceService.adminSummary({
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      teacher_id: filterTeacher.value.trim() || undefined,
    });
    summaryLoaded.value = true;
  } catch (e) {
    summaryError.value = (e as Error).message;
  } finally {
    summaryLoading.value = false;
  }
}

/** Pretty range label for the rekap card subtitle. */
const summaryRangeLabel = computed(() => {
  const m = summary.value?.meta;
  if (!m) return '';
  return `${fmtDate(m.start_date)} – ${fmtDate(m.end_date)}`;
});

// ── Export Excel (client-side CSV, opens in Excel) ──────────────────
function csvEscape(v: unknown): string {
  const s = v === null || v === undefined ? '' : String(v);
  if (s.includes(',') || s.includes('"') || s.includes('\n')) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function exportRekapCsv() {
  if (summaryRows.value.length === 0) {
    toast.error('Belum ada data rekap untuk diekspor.');
    return;
  }
  const statuses = summaryStatuses.value;
  const header = [
    'Nama Guru',
    'NIP',
    ...statuses.map(teacherAttendanceStatusColumnLabel),
    'Total',
    '% Kehadiran',
  ];
  const body = summaryRows.value.map((row) =>
    [
      row.teacher_name,
      row.employee_number ?? '',
      ...statuses.map((s) => row[s] ?? 0),
      row.total,
      `${row.present_pct}%`,
    ]
      .map(csvEscape)
      .join(','),
  );
  const t = summaryTotals.value;
  const footer = t
    ? [
        'TOTAL',
        '',
        ...statuses.map((s) => t[s] ?? 0),
        t.total,
        `${t.present_pct}%`,
      ]
        .map(csvEscape)
        .join(',')
    : null;
  const lines = [header.map(csvEscape).join(','), ...body];
  if (footer) lines.push(footer);
  const csv = lines.join('\n');
  // Prepend a UTF-8 BOM so Excel renders Indonesian characters.
  const blob = new Blob(['﻿' + csv], {
    type: 'text/csv;charset=utf-8;',
  });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  const range = summary.value
    ? `${summary.value.meta.start_date}_${summary.value.meta.end_date}`
    : new Date().toISOString().slice(0, 10);
  a.download = `rekap_presensi_guru_${range}.csv`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
  toast.success('Rekap presensi guru ter-export.');
}

const report = ref<TeacherAttendanceListResult | null>(null);
const reportLoading = ref(false);
const reportError = ref<string | null>(null);
const reportLoaded = ref(false);

const reportRows = computed<TeacherAttendanceRecord[]>(
  () => report.value?.items ?? [],
);
const reportMeta = computed(() => report.value?.meta ?? null);

const presentCount = computed(
  () => reportRows.value.filter((r) => r.status === 'present').length,
);
const lateCount = computed(
  () => reportRows.value.filter((r) => r.status === 'late').length,
);

const reportState = computed<AsyncState<TeacherAttendanceRecord[]>>(() => {
  if (reportLoading.value && reportRows.value.length === 0)
    return { status: 'loading' };
  if (reportError.value) return { status: 'error', error: reportError.value };
  if (reportRows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: reportRows.value };
});

async function loadReport() {
  reportLoading.value = true;
  reportError.value = null;
  try {
    report.value = await TeacherAttendanceService.adminReport({
      date: filterDate.value || undefined,
      start_date: filterStartDate.value || undefined,
      end_date: filterEndDate.value || undefined,
      teacher_id: filterTeacher.value.trim() || undefined,
      status: filterStatus.value || undefined,
      per_page: reportPerPage,
      page: reportPage.value,
    });
    reportLoaded.value = true;
  } catch (e) {
    reportError.value = (e as Error).message;
  } finally {
    reportLoading.value = false;
  }
}

/**
 * Apply the shared periode/teacher filter: always refresh the rekap;
 * refresh the detail list only when it's expanded (lazy — no wasted
 * request while collapsed).
 */
function applyReportFilters() {
  reportPage.value = 1;
  loadSummary();
  if (showDetail.value) loadReport();
}

function clearReportFilters() {
  filterDate.value = '';
  filterStartDate.value = '';
  filterEndDate.value = '';
  filterTeacher.value = '';
  filterStatus.value = '';
  reportPage.value = 1;
  loadSummary();
  if (showDetail.value) loadReport();
}

/** Expand/collapse the detail per-row list; load it on first open. */
function toggleDetail() {
  showDetail.value = !showDetail.value;
  if (showDetail.value && !reportLoaded.value) loadReport();
}

function goReportPage(n: number) {
  if (!reportMeta.value) return;
  if (
    n < 1 ||
    n > reportMeta.value.last_page ||
    n === reportMeta.value.current_page
  )
    return;
  reportPage.value = n;
  loadReport();
}

function switchTab(t: Tab) {
  tab.value = t;
  // The rekap leads the report tab — load it on first entry. The
  // detail list stays lazy until the admin expands it.
  if (t === 'report' && !summaryLoaded.value) loadSummary();
  if (t === 'rules') loadRules();
}

function fmtDate(d: string): string {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function fmtTime(iso?: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ── Rules Tab State ──
const rules = ref<any[]>([]);
const teachersList = ref<any[]>([]);
const gradeLevelsList = ref<string[]>([]);
const rulesLoading = ref(false);
const rulesError = ref<string | null>(null);

// Form for editing/adding a rule
const ruleForm = ref({
  id: null as string | null,
  scope_type: 'global' as 'global' | 'grade_level' | 'teacher',
  scope_value: '',
  checkout_time_validation_enabled: true,
  checkout_time_rule_type: 'all_days' as 'all_days' | 'custom_days',
  checkout_time_all_days: '14:00',
  checkout_times_custom_days: {
    '1': '14:00',
    '2': '14:00',
    '3': '14:00',
    '4': '14:00',
    '5': '14:00',
    '6': '14:00',
    '7': '14:00',
  } as Record<string, string>,
});
const savingRule = ref(false);
const showAddRuleForm = ref(false);

async function loadRules() {
  rulesLoading.value = true;
  rulesError.value = null;
  try {
    const data = await TeacherAttendanceService.getRules();
    rules.value = data.rules;
    teachersList.value = data.teachers;
    gradeLevelsList.value = data.grade_levels;
  } catch (e) {
    rulesError.value = (e as Error).message;
  } finally {
    rulesLoading.value = false;
  }
}

function resetRuleForm() {
  ruleForm.value = {
    id: null,
    scope_type: 'global',
    scope_value: '',
    checkout_time_validation_enabled: true,
    checkout_time_rule_type: 'all_days',
    checkout_time_all_days: '14:00',
    checkout_times_custom_days: {
      '1': '14:00',
      '2': '14:00',
      '3': '14:00',
      '4': '14:00',
      '5': '14:00',
      '6': '14:00',
      '7': '14:00',
    },
  };
  showAddRuleForm.value = false;
}

function editRule(rule: any) {
  ruleForm.value = {
    id: rule.id,
    scope_type: rule.scope_type,
    scope_value: rule.scope_value || '',
    checkout_time_validation_enabled: Boolean(rule.checkout_time_validation_enabled),
    checkout_time_rule_type: rule.checkout_time_rule_type,
    checkout_time_all_days: rule.checkout_time_all_days ? rule.checkout_time_all_days.substring(0, 5) : '14:00',
    checkout_times_custom_days: rule.checkout_times_custom_days
      ? Object.keys(rule.checkout_times_custom_days).reduce((acc, key) => {
          acc[key] = rule.checkout_times_custom_days[key].substring(0, 5);
          return acc;
        }, {} as Record<string, string>)
      : {
          '1': '14:00',
          '2': '14:00',
          '3': '14:00',
          '4': '14:00',
          '5': '14:00',
          '6': '14:00',
          '7': '14:00',
        },
  };
  showAddRuleForm.value = true;
}

async function saveRule() {
  savingRule.value = true;
  try {
    const payload = {
      id: ruleForm.value.id,
      scope_type: ruleForm.value.scope_type,
      scope_value: ruleForm.value.scope_type === 'global' ? null : ruleForm.value.scope_value,
      checkout_time_validation_enabled: ruleForm.value.checkout_time_validation_enabled,
      checkout_time_rule_type: ruleForm.value.checkout_time_rule_type,
      checkout_time_all_days: ruleForm.value.checkout_time_rule_type === 'all_days' ? ruleForm.value.checkout_time_all_days : null,
      checkout_times_custom_days: ruleForm.value.checkout_time_rule_type === 'custom_days' ? ruleForm.value.checkout_times_custom_days : null,
    };
    await TeacherAttendanceService.saveRule(payload);
    toast.success('Aturan presensi berhasil disimpan.');
    resetRuleForm();
    await loadRules();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    savingRule.value = false;
  }
}

async function deleteRule(id: string) {
  if (!confirm('Apakah Anda yakin ingin menghapus aturan presensi ini?')) return;
  try {
    await TeacherAttendanceService.deleteRule(id);
    toast.success('Aturan presensi berhasil dihapus.');
    await loadRules();
  } catch (e) {
    toast.error((e as Error).message);
  }
}

function getScopeLabel(rule: any): string {
  if (rule.scope_type === 'global') return 'Semua Guru (Global)';
  if (rule.scope_type === 'grade_level') return `Tingkat Kelas ${rule.scope_value}`;
  if (rule.scope_type === 'teacher') {
    const teacher = teachersList.value.find((t) => t.id === rule.scope_value);
    return teacher ? `Guru: ${teacher.name}` : `Guru ID: ${rule.scope_value}`;
  }
  return rule.scope_type;
}

function getRuleSummaryLabel(rule: any): string {
  if (!rule.checkout_time_validation_enabled) return 'Validasi jam pulang dinonaktifkan';
  if (rule.checkout_time_rule_type === 'all_days') {
    return `Minimal Jam Pulang: ${rule.checkout_time_all_days ? rule.checkout_time_all_days.substring(0, 5) : '-'}`;
  }
  return 'Jam pulang kustom per hari';
}

function getDayName(dayIndex: string): string {
  const names: Record<string, string> = {
    '1': 'Senin',
    '2': 'Selasa',
    '3': 'Rabu',
    '4': 'Kamis',
    '5': 'Jumat',
    '6': 'Sabtu',
    '7': 'Minggu',
  };
  return names[dayIndex] ?? dayIndex;
}

onMounted(loadSettings);
</script>

<template>
  <div class="space-y-md">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.teacher_attendance.header_kicker')"
      :title="t('admin.sekolah.teacher_attendance.header_title')"
      :meta="t('admin.sekolah.teacher_attendance.header_meta')"
    >
      <div
        class="inline-flex gap-0.5 p-0.5 rounded-xl bg-white/20 border border-white/25 backdrop-blur-sm"
      >
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="
            tab === 'settings'
              ? 'bg-white text-slate-900 shadow-sm'
              : 'text-white/90 hover:text-white'
          "
          @click="switchTab('settings')"
        >
          <NavIcon name="settings" :size="13" />{{ t('admin.sekolah.teacher_attendance.tab_settings') }}
        </button>
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="
            tab === 'rules'
              ? 'bg-white text-slate-900 shadow-sm'
              : 'text-white/90 hover:text-white'
          "
          @click="switchTab('rules')"
        >
          <NavIcon name="clock" :size="13" />{{ t('admin.sekolah.teacher_attendance.tab_rules') }}
        </button>
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="
            tab === 'report'
              ? 'bg-white text-slate-900 shadow-sm'
              : 'text-white/90 hover:text-white'
          "
          @click="switchTab('report')"
        >
          <NavIcon name="bar-chart" :size="13" />{{ t('admin.sekolah.teacher_attendance.tab_report') }}
        </button>
      </div>
    </BrandPageHeader>

    <!-- ════════════════════ SETTINGS TAB ════════════════════ -->
    <template v-if="tab === 'settings'">
      <div
        v-if="settingsLoading"
        class="flex items-center justify-center py-xl text-slate-400"
      >
        <Spinner size="md" />
      </div>

      <div
        v-else-if="settingsError"
        class="bg-red-50 border border-red-200 rounded-2xl p-4 text-center"
      >
        <p class="text-[13px] font-bold text-red-700">{{ settingsError }}</p>
        <Button
          variant="secondary"
          size="sm"
          class="mt-3"
          @click="loadSettings"
        >
          Coba lagi
        </Button>
      </div>

      <template v-else>
        <!-- Metode presensi -->
        <section
          class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
        >
          <div class="px-4 py-3 border-b border-slate-100">
            <h3 class="text-[13px] font-black text-slate-900">
              Metode Presensi
            </h3>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Tentukan syarat yang wajib dipenuhi guru saat presensi.
            </p>
          </div>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50"
          >
            <div
              class="w-9 h-9 rounded-lg bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0"
            >
              <NavIcon name="camera" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Wajib foto selfie
              </p>
              <p class="text-[11px] text-slate-500">
                Guru harus mengambil foto kamera langsung.
              </p>
            </div>
            <input
              v-model="form.camera_required"
              type="checkbox"
              class="w-5 h-5 accent-brand-cobalt"
            />
          </label>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50 border-t border-slate-100"
          >
            <div
              class="w-9 h-9 rounded-lg bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0"
            >
              <NavIcon name="map-pin" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Wajib lokasi GPS
              </p>
              <p class="text-[11px] text-slate-500">
                Verifikasi jarak ke sekolah (geofence).
              </p>
            </div>
            <input
              v-model="form.location_required"
              type="checkbox"
              class="w-5 h-5 accent-brand-cobalt"
            />
          </label>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50 border-t border-slate-100"
          >
            <div
              class="w-9 h-9 rounded-lg bg-violet-100 text-violet-700 grid place-items-center flex-shrink-0"
            >
              <NavIcon name="log-out" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Aktifkan presensi pulang
              </p>
              <p class="text-[11px] text-slate-500">
                Guru juga melakukan check-out di akhir hari.
              </p>
            </div>
            <input
              v-model="form.checkout_enabled"
              type="checkbox"
              class="w-5 h-5 accent-brand-cobalt"
            />
          </label>
        </section>

        <!-- Geofence -->
        <section
          class="bg-white border border-slate-200 rounded-2xl p-4 space-y-md"
        >
          <div>
            <h3 class="text-[13px] font-black text-slate-900">
              Geofence Sekolah
            </h3>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Titik pusat &amp; radius area presensi. Kosongkan koordinat untuk
              memakai pin sekolah ({{ schoolPinLabel }}).
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label
                class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Latitude
              </label>
              <input
                v-model="geofenceLatStr"
                type="number"
                step="any"
                placeholder="mis. -6.200000"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
              />
            </div>
            <div>
              <label
                class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Longitude
              </label>
              <input
                v-model="geofenceLngStr"
                type="number"
                step="any"
                placeholder="mis. 106.816666"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
              />
            </div>
          </div>

          <!-- Interactive OpenStreetMap picker: tap/drag the pin to set the
               geofence centre; it syncs to the Latitude/Longitude fields
               above (and they sync back to it). -->
          <GeofenceMapPicker
            :lat="parseCoord(geofenceLatStr)"
            :lng="parseCoord(geofenceLngStr)"
            :radius="form.geofence_radius_m"
            :fallback-lat="form.school_latitude ?? null"
            :fallback-lng="form.school_longitude ?? null"
            @pick="onMapPick"
          />
          <p class="text-[10px] text-slate-400 -mt-1">
            Geser atau ketuk pin di peta untuk memilih titik pusat geofence.
          </p>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label
                class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Radius (meter)
              </label>
              <input
                v-model.number="form.geofence_radius_m"
                type="number"
                min="10"
                max="5000"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
              />
              <p class="text-[10px] text-slate-400 mt-1">
                Rentang 10 – 5000 m.
              </p>
            </div>
            <div>
              <label
                class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Toleransi terlambat (menit)
              </label>
              <input
                v-model.number="form.late_grace_minutes"
                type="number"
                min="0"
                max="600"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
              />
              <p class="text-[10px] text-slate-400 mt-1">
                Terlambat dihitung setelah jam mengajar pertama + toleransi.
              </p>
            </div>
          </div>

          <label class="flex items-center gap-3 cursor-pointer">
            <input
              v-model="form.reject_outside_geofence"
              type="checkbox"
              class="w-5 h-5 accent-brand-cobalt"
            />
            <span class="text-[12.5px] text-slate-700">
              <span class="font-bold">Tolak presensi di luar radius.</span>
              Jika dimatikan, presensi di luar area tetap dicatat namun
              ditandai.
            </span>
          </label>
        </section>

        <div class="flex justify-end">
          <Button variant="primary" :loading="saving" @click="saveSettings">
            <NavIcon name="check" :size="15" />Simpan Pengaturan
          </Button>
        </div>
      </template>
    </template>

    <!-- ════════════════════ RULES TAB ════════════════════ -->
    <template v-else-if="tab === 'rules'">
      <div v-if="rulesLoading" class="flex items-center justify-center py-xl text-slate-400">
        <Spinner size="md" />
      </div>
      <div v-else-if="rulesError" class="bg-red-50 text-red-600 rounded-xl p-4 text-[13px]">
        {{ rulesError }}
      </div>
      <div v-else class="space-y-md">
        <!-- Add/Edit Rule Form -->
        <section v-if="showAddRuleForm" class="bg-white border border-slate-200 rounded-2xl p-5 space-y-md">
          <div class="flex items-center justify-between border-b border-slate-100 pb-3">
            <h3 class="text-sm font-bold text-slate-800">
              {{ ruleForm.id ? 'Edit Aturan Presensi' : 'Tambah Aturan Presensi Baru' }}
            </h3>
            <button @click="resetRuleForm" class="text-xs text-slate-400 hover:text-slate-600">Batal</button>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1">Cakupan (Scope)</label>
              <select v-model="ruleForm.scope_type" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30">
                <option value="global">Semua Guru (Global)</option>
                <option value="grade_level">Per Tingkat Kelas</option>
                <option value="teacher">Per Guru</option>
              </select>
            </div>

            <div v-if="ruleForm.scope_type === 'grade_level'">
              <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1">Tingkat Kelas</label>
              <select v-model="ruleForm.scope_value" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30">
                <option value="">Pilih Tingkat</option>
                <option v-for="level in gradeLevelsList" :key="level" :value="level">Tingkat {{ level }}</option>
              </select>
            </div>

            <div v-if="ruleForm.scope_type === 'teacher'">
              <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1">Guru</label>
              <select v-model="ruleForm.scope_value" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30">
                <option value="">Pilih Guru</option>
                <option v-for="teacher in teachersList" :key="teacher.id" :value="teacher.id">
                  {{ teacher.name }} ({{ teacher.employee_number || 'NIP -' }})
                </option>
              </select>
            </div>
          </div>

          <div class="border-t border-slate-100 pt-4 space-y-md">
            <label class="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" v-model="ruleForm.checkout_time_validation_enabled" class="w-5 h-5 accent-brand-cobalt" />
              <span class="text-[12.5px] text-slate-700 font-bold">Aktifkan Validasi Minimal Jam Pulang</span>
            </label>

            <div v-if="ruleForm.checkout_time_validation_enabled" class="space-y-md bg-slate-50 rounded-xl p-4 border border-slate-200">
              <div>
                <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1">Tipe Aturan Waktu</label>
                <div class="flex gap-2">
                  <button type="button" @click="ruleForm.checkout_time_rule_type = 'all_days'" class="px-4 py-2 rounded-lg text-xs font-bold transition-all border" :class="ruleForm.checkout_time_rule_type === 'all_days' ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'">
                    Sama untuk Semua Hari
                  </button>
                  <button type="button" @click="ruleForm.checkout_time_rule_type = 'custom_days'" class="px-4 py-2 rounded-lg text-xs font-bold transition-all border" :class="ruleForm.checkout_time_rule_type === 'custom_days' ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'">
                    Kustom per Hari
                  </button>
                </div>
              </div>

              <!-- Time Inputs -->
              <div v-if="ruleForm.checkout_time_rule_type === 'all_days'" class="w-48">
                <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1">Jam Pulang Minimal</label>
                <input type="time" v-model="ruleForm.checkout_time_all_days" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30" />
              </div>

              <div v-else class="grid grid-cols-2 sm:grid-cols-7 gap-3">
                <div v-for="day in ['1', '2', '3', '4', '5', '6', '7']" :key="day">
                  <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1">
                    {{ getDayName(day) }}
                  </label>
                  <input type="time" v-model="ruleForm.checkout_times_custom_days[day]" class="w-full rounded-lg border border-slate-200 px-2 py-1.5 text-[12px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30" />
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end gap-2 border-t border-slate-100 pt-4">
            <Button variant="secondary" @click="resetRuleForm">Batal</Button>
            <Button variant="primary" :loading="savingRule" @click="saveRule">Simpan Aturan</Button>
          </div>
        </section>

        <!-- Rules List -->
        <section v-else class="bg-white border border-slate-200 rounded-2xl p-5 space-y-md">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-bold text-slate-800">Daftar Aturan Presensi Guru</h3>
              <p class="text-[11px] text-slate-400">Atur batasan jam pulang khusus untuk jenjang kelas atau guru tertentu.</p>
            </div>
            <Button variant="primary" @click="showAddRuleForm = true">
              <NavIcon name="plus" :size="13" />Tambah Aturan
            </Button>
          </div>

          <div v-if="rules.length === 0" class="flex flex-col items-center justify-center py-10 text-slate-400 border border-dashed border-slate-200 rounded-xl">
            <NavIcon name="info-circle" :size="24" class="mb-2" />
            <p class="text-xs">Belum ada aturan presensi khusus yang dibuat.</p>
            <p class="text-[10px]">Semua guru akan mengikuti aturan presensi default sekolah.</p>
          </div>

          <div v-else class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="border-b border-slate-100 text-[10px] uppercase font-bold tracking-wider text-slate-400">
                  <th class="py-3 px-4">Cakupan Aturan</th>
                  <th class="py-3 px-4">Validasi Jam Pulang</th>
                  <th class="py-3 px-4">Tipe Aturan</th>
                  <th class="py-3 px-4">Batas Jam</th>
                  <th class="py-3 px-4 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody class="text-xs text-slate-700 divide-y divide-slate-50">
                <tr v-for="rule in rules" :key="rule.id" class="hover:bg-slate-50/50">
                  <td class="py-3 px-4 font-bold text-slate-900">{{ getScopeLabel(rule) }}</td>
                  <td class="py-3 px-4">
                    <span class="px-2 py-0.5 rounded-full text-[10px] font-bold" :class="rule.checkout_time_validation_enabled ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-600'">
                      {{ rule.checkout_time_validation_enabled ? 'Aktif' : 'Non-aktif' }}
                    </span>
                  </td>
                  <td class="py-3 px-4">
                    {{ rule.checkout_time_rule_type === 'all_days' ? 'Sama Setiap Hari' : 'Kustom per Hari' }}
                  </td>
                  <td class="py-3 px-4 tabular-nums">
                    <div v-if="rule.checkout_time_rule_type === 'all_days'">
                      {{ rule.checkout_time_all_days ? rule.checkout_time_all_days.substring(0, 5) : '-' }}
                    </div>
                    <div v-else class="text-[10px] text-slate-500">
                      <span v-for="(time, day) in rule.checkout_times_custom_days" :key="day" class="mr-2 inline-block">
                        <span class="font-bold text-slate-700">{{ getDayName(day).substring(0, 3) }}:</span> {{ time.substring(0, 5) }}
                      </span>
                    </div>
                  </td>
                  <td class="py-3 px-4 text-right space-x-2">
                    <button @click="editRule(rule)" class="text-brand-cobalt hover:underline font-bold">Edit</button>
                    <button @click="deleteRule(rule.id)" class="text-red-500 hover:underline font-bold">Hapus</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </template>

    <!-- ════════════════════ REPORT TAB ════════════════════ -->
    <template v-else-if="tab === 'report'">
      <!-- Periode filter (drives BOTH rekap + detail) -->
      <section
        class="bg-white border border-slate-200 rounded-2xl p-3 flex flex-wrap items-end gap-3"
      >
        <div>
          <label
            class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
          >
            Dari (periode)
          </label>
          <input
            v-model="filterStartDate"
            type="date"
            class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          />
        </div>
        <div>
          <label
            class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
          >
            Sampai (periode)
          </label>
          <input
            v-model="filterEndDate"
            type="date"
            class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          />
        </div>
        <div>
          <label
            class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
          >
            ID Guru
          </label>
          <input
            v-model="filterTeacher"
            type="text"
            placeholder="Teacher / User ID"
            class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 w-44 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
          />
        </div>
        <Button variant="primary" size="sm" @click="applyReportFilters">
          <NavIcon name="filter" :size="13" />Terapkan
        </Button>
        <Button
          v-if="filterStartDate || filterEndDate || filterTeacher"
          variant="ghost"
          size="sm"
          @click="clearReportFilters"
        >
          Reset
        </Button>
        <p class="basis-full text-[10.5px] text-slate-400">
          Kosongkan tanggal untuk memakai periode default (awal bulan ini
          sampai hari ini).
        </p>
      </section>

      <!-- ─────────────── REKAP PER-GURU (admin/summary) ─────────────── -->
      <section
        class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
      >
        <div
          class="px-4 py-3 border-b border-slate-100 flex items-center justify-between gap-3 flex-wrap"
        >
          <div>
            <h3 class="text-[13px] font-black text-slate-900">
              Rekap Kehadiran per Guru
            </h3>
            <p class="text-[11px] text-slate-500 mt-0.5">
              <template v-if="summaryRangeLabel"
                >Periode {{ summaryRangeLabel }} ·
              </template>
              {{ summaryTotals?.teacher_count ?? summaryRows.length }} guru
            </p>
          </div>
          <Button
            variant="secondary"
            size="sm"
            :disabled="summaryRows.length === 0"
            @click="exportRekapCsv"
          >
            <NavIcon name="download" :size="13" />Export Excel
          </Button>
        </div>

        <AsyncView
          :state="summaryState"
          :empty-title="t('admin.sekolah.teacher_attendance.empty_title')"
          :empty-description="t('admin.sekolah.teacher_attendance.empty_description')"
          @retry="loadSummary"
        >
          <template #default>
            <div class="overflow-x-auto">
              <table class="w-full min-w-[640px] text-left">
                <thead>
                  <tr
                    class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    <th class="px-4 py-2.5">Nama</th>
                    <th
                      v-for="s in summaryStatuses"
                      :key="s"
                      class="px-4 py-2.5 text-right tabular-nums"
                    >
                      {{ teacherAttendanceStatusColumnLabel(s) }}
                    </th>
                    <th class="px-4 py-2.5 text-right tabular-nums">Total</th>
                    <th class="px-4 py-2.5 text-right tabular-nums">
                      % Kehadiran
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="row in summaryRows"
                    :key="row.teacher_id"
                    class="border-t border-slate-100 text-[12.5px] hover:bg-slate-50"
                  >
                    <td class="px-4 py-2.5">
                      <p class="font-bold text-slate-900">
                        {{ row.teacher_name }}
                      </p>
                      <p
                        v-if="row.employee_number"
                        class="text-[10.5px] text-slate-400"
                      >
                        {{ row.employee_number }}
                      </p>
                    </td>
                    <td
                      v-for="s in summaryStatuses"
                      :key="s"
                      class="px-4 py-2.5 text-right tabular-nums text-slate-700"
                    >
                      {{ row[s] ?? 0 }}
                    </td>
                    <td
                      class="px-4 py-2.5 text-right tabular-nums font-bold text-slate-900"
                    >
                      {{ row.total }}
                    </td>
                    <td class="px-4 py-2.5 text-right">
                      <span
                        class="text-[11px] font-bold px-1.5 py-0.5 rounded-full tabular-nums"
                        :class="
                          row.present_pct >= 90
                            ? 'bg-emerald-100 text-emerald-700'
                            : row.present_pct >= 75
                              ? 'bg-amber-100 text-amber-700'
                              : 'bg-red-100 text-red-700'
                        "
                      >
                        {{ row.present_pct }}%
                      </span>
                    </td>
                  </tr>
                </tbody>
                <tfoot v-if="summaryTotals">
                  <tr
                    class="border-t-2 border-slate-200 bg-slate-50 text-[12.5px] font-black text-slate-900"
                  >
                    <td class="px-4 py-2.5">Total</td>
                    <td
                      v-for="s in summaryStatuses"
                      :key="s"
                      class="px-4 py-2.5 text-right tabular-nums"
                    >
                      {{ summaryTotals[s] ?? 0 }}
                    </td>
                    <td class="px-4 py-2.5 text-right tabular-nums">
                      {{ summaryTotals.total }}
                    </td>
                    <td class="px-4 py-2.5 text-right tabular-nums">
                      {{ summaryTotals.present_pct }}%
                    </td>
                  </tr>
                </tfoot>
              </table>
            </div>
          </template>
        </AsyncView>
      </section>

      <!-- ─────────────── DETAIL PER-BARIS (collapsible) ─────────────── -->
      <section
        class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
      >
        <button
          type="button"
          class="w-full px-4 py-3 flex items-center justify-between gap-3 hover:bg-slate-50 transition-colors"
          @click="toggleDetail"
        >
          <div class="text-left">
            <h3 class="text-[13px] font-black text-slate-900">
              Detail per Baris
            </h3>
            <p class="text-[11px] text-slate-500 mt-0.5">
              Catatan presensi harian guru (masuk/pulang, lokasi, foto).
            </p>
          </div>
          <NavIcon
            :name="showDetail ? 'chevron-up' : 'chevron-down'"
            :size="16"
            class="text-slate-400 flex-shrink-0"
          />
        </button>
      </section>

      <template v-if="showDetail">
        <!-- Detail-only filters (tanggal tunggal + status) -->
        <section
          class="bg-white border border-slate-200 rounded-2xl p-3 flex flex-wrap items-end gap-3"
        >
          <div>
            <label
              class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
            >
              Tanggal (1 hari)
            </label>
            <input
              v-model="filterDate"
              type="date"
              class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
            />
          </div>
          <div>
            <label
              class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
            >
              Status
            </label>
            <select
              v-model="filterStatus"
              class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
            >
              <option value="">Semua</option>
              <option value="present">Tepat Waktu</option>
              <option value="late">Terlambat</option>
            </select>
          </div>
          <Button variant="primary" size="sm" @click="applyReportFilters">
            <NavIcon name="filter" :size="13" />Terapkan
          </Button>
        </section>

        <!-- Summary chips -->
      <div
        v-if="reportRows.length > 0"
        class="flex items-center gap-2 flex-wrap"
      >
        <span
          class="text-[11px] font-bold px-2.5 py-1 rounded-full bg-slate-100 text-slate-600"
        >
          {{ reportMeta?.total ?? reportRows.length }} catatan
        </span>
        <span
          class="text-[11px] font-bold px-2.5 py-1 rounded-full bg-emerald-100 text-emerald-700"
        >
          {{ presentCount }} tepat waktu (hal. ini)
        </span>
        <span
          class="text-[11px] font-bold px-2.5 py-1 rounded-full bg-amber-100 text-amber-700"
        >
          {{ lateCount }} terlambat (hal. ini)
        </span>
      </div>

      <!-- List -->
      <AsyncView
        :state="reportState"
        empty-title="Belum ada data presensi"
        empty-description="Tidak ada catatan presensi guru untuk filter ini."
        @retry="loadReport"
      >
        <template #default>
          <div
            class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
          >
            <div class="overflow-x-auto">
              <table class="w-full min-w-[720px] text-left">
                <thead>
                  <tr
                    class="bg-slate-50 text-[10px] font-bold text-slate-400 uppercase tracking-widest"
                  >
                    <th class="px-4 py-2.5">Guru</th>
                    <th class="px-4 py-2.5">Tanggal</th>
                    <th class="px-4 py-2.5">Status</th>
                    <th class="px-4 py-2.5">Masuk</th>
                    <th class="px-4 py-2.5">Pulang</th>
                    <th class="px-4 py-2.5">Lokasi</th>
                    <th class="px-4 py-2.5">Foto</th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="r in reportRows"
                    :key="r.id"
                    class="border-t border-slate-100 text-[12.5px] hover:bg-slate-50"
                  >
                    <td class="px-4 py-2.5">
                      <p class="font-bold text-slate-900">
                        {{ r.teacher?.name ?? '-' }}
                      </p>
                      <p
                        v-if="r.teacher?.employee_number"
                        class="text-[10.5px] text-slate-400"
                      >
                        {{ r.teacher.employee_number }}
                      </p>
                    </td>
                    <td class="px-4 py-2.5 text-slate-600">
                      {{ fmtDate(r.date) }}
                    </td>
                    <td class="px-4 py-2.5">
                      <span
                        class="text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                        :class="
                          r.status === 'late'
                            ? 'bg-amber-100 text-amber-700'
                            : 'bg-emerald-100 text-emerald-700'
                        "
                      >
                        {{ teacherAttendanceStatusLabel(r.status) }}
                      </span>
                    </td>
                    <td
                      class="px-4 py-2.5 text-slate-700 font-bold tabular-nums"
                    >
                      {{ fmtTime(r.check_in_at) }}
                    </td>
                    <td
                      class="px-4 py-2.5 text-slate-700 font-bold tabular-nums"
                    >
                      {{ fmtTime(r.check_out_at) }}
                    </td>
                    <td class="px-4 py-2.5">
                      <span
                        v-if="r.check_in_outside_geofence"
                        class="text-[11px] font-bold text-red-600"
                      >
                        Luar area
                      </span>
                      <span
                        v-else-if="r.check_in_distance_m != null"
                        class="text-[11px] text-slate-500"
                      >
                        {{ r.check_in_distance_m }} m
                      </span>
                      <span v-else class="text-[11px] text-slate-300">-</span>
                    </td>
                    <td class="px-4 py-2.5">
                      <div class="flex flex-col gap-1">
                        <!-- Foto Masuk (check-in selfie) -->
                        <a
                          v-if="r.check_in_photo_url"
                          :href="r.check_in_photo_url"
                          target="_blank"
                          rel="noopener"
                          class="inline-flex items-center gap-1 text-brand-cobalt text-[11px] font-bold hover:underline"
                        >
                          <NavIcon name="camera" :size="12" />Masuk
                        </a>
                        <span v-else class="text-[11px] text-slate-300">
                          Masuk -
                        </span>
                        <!-- Foto Pulang (check-out selfie) -->
                        <a
                          v-if="r.check_out_photo_url"
                          :href="r.check_out_photo_url"
                          target="_blank"
                          rel="noopener"
                          class="inline-flex items-center gap-1 text-brand-cobalt text-[11px] font-bold hover:underline"
                        >
                          <NavIcon name="camera" :size="12" />Pulang
                        </a>
                        <span
                          v-else
                          class="inline-flex items-center text-[11px] text-slate-300"
                        >
                          Pulang -
                        </span>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Pagination -->
          <div
            v-if="reportMeta && reportMeta.last_page > 1"
            class="flex items-center justify-center gap-2 pt-3"
          >
            <Button
              variant="secondary"
              size="sm"
              :disabled="reportMeta.current_page <= 1"
              @click="goReportPage(reportMeta.current_page - 1)"
            >
              <NavIcon name="chevron-left" :size="13" />
            </Button>
            <span class="text-[12px] text-slate-500 font-bold px-2">
              Hal {{ reportMeta.current_page }} / {{ reportMeta.last_page }}
            </span>
            <Button
              variant="secondary"
              size="sm"
              :disabled="reportMeta.current_page >= reportMeta.last_page"
              @click="goReportPage(reportMeta.current_page + 1)"
            >
              <NavIcon name="chevron-right" :size="13" />
            </Button>
          </div>
        </template>
      </AsyncView>
      </template>
    </template>
  </div>
</template>
