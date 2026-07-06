<!--
  AdminAttendanceConfigView.vue — unified "Pengaturan Kehadiran" (Wave 2
  IA refactor). Merges the TWO historical settings screens that both
  wrote to the same PUT /teacher-attendance/settings endpoint:

    · AdminTeacherAttendanceView (settings mode) — camera_required /
      location_required / checkout_enabled, geofence centre + radius +
      reject-outside, late grace, plus the checkin/checkout rules CRUD.
    · attendance/AttendanceSettingsView — allowed_methods (SELFIE /
      QR_GATE / QR_CARD), gate_qr_rotation_minutes,
      geofence_required_for_qr, issue_student_cards.

  The split was historical, not semantic — one endpoint, one screen now.
  Mirrors the mobile AdminTeacherAttendanceSettingsScreen (3 tabs):

    (a) Umum & Metode — union of both old forms in ONE form state with
        ONE save (merged payload; the endpoint stays partial-tolerant).
        SELFIE is always kept in `allowed_methods[]` (mobile parity) —
        the admin flips `camera_required` off for a no-photo path.
    (b) Aturan Jam Datang — checkin rules CRUD (ported verbatim).
    (c) Aturan Jam Pulang — checkout rules CRUD (ported verbatim).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import GeofenceMapPicker from '@/components/feature/GeofenceMapPicker.vue';
import { useToast } from '@/composables/useToast';
import { useConfirm } from '@/composables/useConfirm';
import type { TeacherAttendanceSettings } from '@/types/teacher-attendance';
import { DEFAULT_TEACHER_ATTENDANCE_SETTINGS } from '@/types/teacher-attendance';
import type { CheckInMethod } from '@/types/attendance-qr';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import AttendanceConfigWizard from '@/components/feature/AttendanceConfigWizard.vue';

const toast = useToast();
const { t } = useI18n();
const { confirm } = useConfirm();

type Tab = 'general' | 'checkin_rules' | 'checkout_rules';
const tab = ref<Tab>('general');

// ─────────────────────────────────────────────────────────────────
// Umum & Metode tab — merged form state
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

/**
 * The two QR-method toggles drive `allowed_methods[]` on save. SELFIE
 * stays in the array regardless (mobile parity — the backend enforces
 * ≥1 method, and selfie is the baseline method every school keeps).
 */
const qrGateEnabled = ref(false);
const qrCardEnabled = ref(false);

function syncFromSettings(s: TeacherAttendanceSettings) {
  geofenceLatStr.value = s.geofence_lat != null ? String(s.geofence_lat) : '';
  geofenceLngStr.value = s.geofence_lng != null ? String(s.geofence_lng) : '';
  const methods = s.allowed_methods ?? ['SELFIE'];
  qrGateEnabled.value = methods.includes('QR_GATE');
  qrCardEnabled.value = methods.includes('QR_CARD');
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
    syncFromSettings(s);
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
  const rot = form.value.gate_qr_rotation_minutes ?? 15;
  if (rot < 1 || rot > 60) {
    toast.error('Rotasi QR gerbang harus antara 1 dan 60 menit.');
    return;
  }

  // Reconstruct the canonical `allowed_methods[]` array. Selfie is
  // always implied present today; the admin can flip off
  // `camera_required` separately if they want a no-photo selfie path.
  const allowedMethods: CheckInMethod[] = ['SELFIE'];
  if (qrGateEnabled.value) allowedMethods.push('QR_GATE');
  if (qrCardEnabled.value) allowedMethods.push('QR_CARD');

  saving.value = true;
  try {
    // ONE merged PUT — the union of both former screens' payloads.
    // The endpoint stays partial-tolerant (`sometimes` rules), we just
    // send the complete picture so a save never clobbers half a form.
    const saved = await TeacherAttendanceService.updateSettings({
      camera_required: form.value.camera_required,
      location_required: form.value.location_required,
      checkout_enabled: form.value.checkout_enabled,
      geofence_lat: lat,
      geofence_lng: lng,
      geofence_radius_m: form.value.geofence_radius_m,
      reject_outside_geofence: form.value.reject_outside_geofence,
      late_grace_minutes: form.value.late_grace_minutes,
      allowed_methods: allowedMethods,
      gate_qr_rotation_minutes: rot,
      geofence_required_for_qr: !!form.value.geofence_required_for_qr,
      issue_student_cards: !!form.value.issue_student_cards,
    });
    form.value = { ...form.value, ...saved };
    syncFromSettings(form.value);
    toast.success('Pengaturan kehadiran tersimpan.');
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    saving.value = false;
  }
}

// ── Rules state (shared by both rules tabs) ─────────────────────────
const rules = ref<any[]>([]);
const teachersList = ref<any[]>([]);
const gradeLevelsList = ref<string[]>([]);
const rulesLoading = ref(false);
const rulesError = ref<string | null>(null);

// Computed properties to filter rules by type
const checkoutRules = computed(() => rules.value.filter(r => r.rule_type === 'checkout'));
const checkinRules = computed(() => rules.value.filter(r => r.rule_type === 'checkin'));

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

// Form for editing/adding a check-in rule
const checkinRuleForm = ref({
  id: null as string | null,
  scope_type: 'global' as 'global' | 'grade_level' | 'teacher',
  scope_value: '',
  checkin_time_validation_enabled: true,
  checkin_time_rule_type: 'all_days' as 'all_days' | 'custom_days',
  checkin_time_all_days: '07:00',
  checkin_times_custom_days: {
    '1': '07:00',
    '2': '07:00',
    '3': '07:00',
    '4': '07:00',
    '5': '07:00',
    '6': '07:00',
    '7': '07:00',
  } as Record<string, string>,
});
const savingCheckinRule = ref(false);
const showAddCheckinRuleForm = ref(false);

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

function switchTab(t: Tab) {
  tab.value = t;
  if (t === 'checkout_rules') loadRules();
}

// Watch tab changes to load rules data when accessing rules tabs
watch(tab, (newTab) => {
  if (newTab === 'checkout_rules' || newTab === 'checkin_rules') {
    if (!rulesLoading.value && rules.value.length === 0) {
      loadRules();
    }
  }
});

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
      rule_type: 'checkout',
      scope_type: ruleForm.value.scope_type,
      scope_value: ruleForm.value.scope_type === 'global' ? null : ruleForm.value.scope_value,
      checkout_time_validation_enabled: ruleForm.value.checkout_time_validation_enabled,
      checkout_time_rule_type: ruleForm.value.checkout_time_rule_type,
      checkout_time_all_days: ruleForm.value.checkout_time_rule_type === 'all_days' ? ruleForm.value.checkout_time_all_days : null,
      checkout_times_custom_days: ruleForm.value.checkout_time_rule_type === 'custom_days' ? ruleForm.value.checkout_times_custom_days : null,
      checkin_time_validation_enabled: false,
      checkin_time_rule_type: 'all_days',
      checkin_time_all_days: null,
      checkin_times_custom_days: null,
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
  if (
    !(await confirm({
      title: 'Hapus aturan presensi?',
      message: 'Aturan presensi ini akan dihapus permanen.',
      danger: true,
      confirmLabel: t('common.delete'),
    }))
  )
    return;
  // Snapshot BEFORE deleting so undo can re-post the exact same
  // payload (saveRule accepts create+update through the same shape,
  // differentiated by `id`). We drop the id on restore so the server
  // materialises a fresh row rather than colliding.
  const snapshot = rules.value.find((r) => r.id === id);
  try {
    await TeacherAttendanceService.deleteRule(id);
    await loadRules();
    if (!snapshot) {
      toast.success('Aturan presensi berhasil dihapus.');
      return;
    }
    toast.undoable('Aturan presensi dihapus.', async () => {
      try {
        await TeacherAttendanceService.saveRule({ ...snapshot, id: null });
        await loadRules();
        toast.success('Aturan presensi dikembalikan.');
      } catch (e) {
        toast.error(`Gagal mengembalikan: ${(e as Error).message}`);
      }
    });
  } catch (e) {
    toast.error((e as Error).message);
  }
}

// ── Check-in Rule Functions ──────────────────────────────────────────
function resetCheckinRuleForm() {
  checkinRuleForm.value = {
    id: null,
    scope_type: 'global',
    scope_value: '',
    checkin_time_validation_enabled: true,
    checkin_time_rule_type: 'all_days',
    checkin_time_all_days: '07:00',
    checkin_times_custom_days: {
      '1': '07:00',
      '2': '07:00',
      '3': '07:00',
      '4': '07:00',
      '5': '07:00',
      '6': '07:00',
      '7': '07:00',
    },
  };
  showAddCheckinRuleForm.value = false;
}

function editCheckinRule(rule: any) {
  checkinRuleForm.value = {
    id: rule.id,
    scope_type: rule.scope_type,
    scope_value: rule.scope_value || '',
    checkin_time_validation_enabled: rule.checkin_time_validation_enabled,
    checkin_time_rule_type: rule.checkin_time_rule_type,
    checkin_time_all_days: rule.checkin_time_all_days || '07:00',
    checkin_times_custom_days: rule.checkin_times_custom_days || {
      '1': '07:00',
      '2': '07:00',
      '3': '07:00',
      '4': '07:00',
      '5': '07:00',
      '6': '07:00',
      '7': '07:00',
    },
  };
  showAddCheckinRuleForm.value = true;
}

async function saveCheckinRule() {
  savingCheckinRule.value = true;
  try {
    const payload = {
      id: checkinRuleForm.value.id,
      rule_type: 'checkin',
      scope_type: checkinRuleForm.value.scope_type,
      scope_value: checkinRuleForm.value.scope_type === 'global' ? null : checkinRuleForm.value.scope_value,
      checkout_time_validation_enabled: false,
      checkout_time_rule_type: 'all_days',
      checkout_time_all_days: null,
      checkout_times_custom_days: null,
      checkin_time_validation_enabled: checkinRuleForm.value.checkin_time_validation_enabled,
      checkin_time_rule_type: checkinRuleForm.value.checkin_time_rule_type,
      checkin_time_all_days: checkinRuleForm.value.checkin_time_rule_type === 'all_days' ? checkinRuleForm.value.checkin_time_all_days : null,
      checkin_times_custom_days: checkinRuleForm.value.checkin_time_rule_type === 'custom_days' ? checkinRuleForm.value.checkin_times_custom_days : null,
    };
    await TeacherAttendanceService.saveRule(payload);
    toast.success('Aturan jam datang berhasil disimpan.');
    resetCheckinRuleForm();
    await loadRules();
  } catch (e) {
    toast.error((e as Error).message);
  } finally {
    savingCheckinRule.value = false;
  }
}

async function deleteCheckinRule(id: string) {
  if (
    !(await confirm({
      title: 'Hapus aturan?',
      message: 'Aturan ini akan dihapus permanen.',
      danger: true,
      confirmLabel: t('common.delete'),
    }))
  )
    return;
  const snapshot = rules.value.find((r) => r.id === id);
  try {
    await TeacherAttendanceService.deleteRule(id);
    await loadRules();
    if (!snapshot) {
      toast.success('Aturan jam datang berhasil dihapus.');
      return;
    }
    toast.undoable('Aturan jam datang dihapus.', async () => {
      try {
        await TeacherAttendanceService.saveRule({ ...snapshot, id: null });
        await loadRules();
        toast.success('Aturan jam datang dikembalikan.');
      } catch (e) {
        toast.error(`Gagal mengembalikan: ${(e as Error).message}`);
      }
    });
  } catch (e) {
    toast.error((e as Error).message);
  }
}

function getRuleScopeLabel(rule: any): string {
  if (rule.scope_type === 'global') return 'Semua Guru (Global)';
  if (rule.scope_type === 'grade_level') return `Tingkat Kelas ${rule.scope_value}`;
  if (rule.scope_type === 'teacher') {
    const teacher = teachersList.value.find((t) => t.id === rule.scope_value);
    return teacher ? `Guru: ${teacher.name}` : `Guru ID: ${rule.scope_value}`;
  }
  return rule.scope_type;
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

// Panduan wizard — a 5-step guided overlay that walks admins through
// the same fields the flat form exposes. Rendered lazily via v-if so
// the map + leaflet chunks aren't loaded until the admin actually
// clicks Panduan.
const showWizard = ref(false);
function onWizardSaved(saved: TeacherAttendanceSettings): void {
  // Merge the freshly-saved settings back into the flat form's model
  // so an admin closing the wizard sees their choices reflected there.
  form.value = { ...form.value, ...saved };
  syncFromSettings(form.value);
}

// Section-nav jump list — kept alongside the mount call so it's easy
// to add/reorder entries when new sections land. The Umum tab is dense
// (~30 controls across 4 groups); this lets an admin skip straight to
// the one they came for. The 4 ids match the section anchors above.
const sectionJumps = computed<{ id: string; label: string }[]>(() => [
  { id: 'section-metode', label: 'Metode' },
  { id: 'section-geofence', label: 'Geofence' },
  { id: 'section-qr', label: 'QR Gerbang' },
  { id: 'section-waktu', label: 'Waktu' },
]);

function jumpToSection(id: string): void {
  const el = document.getElementById(id);
  if (!el) return;
  el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  // Update the URL fragment so the destination is bookmarkable and
  // shareable ("open the presensi config, take me to Geofence").
  history.replaceState(null, '', `#${id}`);
}
</script>

<template>
  <div class="space-y-md">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.attendance_config.header_kicker')"
      :title="t('admin.sekolah.attendance_config.header_title')"
      :meta="t('admin.sekolah.attendance_config.header_meta')"
    >
      <div
        class="inline-flex gap-0.5 p-0.5 rounded-xl bg-white/20 border border-white/25 backdrop-blur-sm"
      >
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="
            tab === 'general'
              ? 'bg-white text-slate-900 shadow-sm'
              : 'text-white/90 hover:text-white'
          "
          @click="switchTab('general')"
        >
          <NavIcon name="settings" :size="13" />{{ t('admin.sekolah.attendance_config.tab_general') }}
        </button>
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="
            tab === 'checkin_rules'
              ? 'bg-white text-slate-900 shadow-sm'
              : 'text-white/90 hover:text-white'
          "
          @click="switchTab('checkin_rules')"
        >
          <NavIcon name="clock" :size="13" />{{ t('admin.sekolah.attendance_config.tab_checkin_rules') }}
        </button>
        <button
          type="button"
          class="px-3 py-1 rounded-lg text-[11.5px] font-bold inline-flex items-center gap-1.5 transition-all"
          :class="
            tab === 'checkout_rules'
              ? 'bg-white text-slate-900 shadow-sm'
              : 'text-white/90 hover:text-white'
          "
          @click="switchTab('checkout_rules')"
        >
          <NavIcon name="clock" :size="13" />{{ t('admin.sekolah.attendance_config.tab_checkout_rules') }}
        </button>
      </div>
    </BrandPageHeader>

    <!-- ════════════════════ UMUM & METODE TAB ════════════════════ -->
    <template v-if="tab === 'general'">
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
        <!-- SECTION NAV — sticky orientation strip. The Umum tab holds
             four dense sections; this chip row lets an admin jump
             straight to the one they came for instead of scrolling
             through 30+ controls. Sits under the fixed page header
             (top offset via top-16) and uses scroll-mt-* on each
             section so anchors don't slip under the sticky strip. -->
        <nav
          class="sticky top-16 z-10 -mx-md sm:mx-0 bg-slate-50/95 backdrop-blur border-b border-slate-200 px-md py-2 flex items-center gap-1.5 overflow-x-auto"
          aria-label="Bagian pengaturan presensi"
        >
          <span
            class="text-3xs font-bold text-slate-400 uppercase tracking-widest flex-shrink-0 mr-1"
          >
            Loncat ke
          </span>
          <a
            v-for="jump in sectionJumps"
            :key="jump.id"
            :href="`#${jump.id}`"
            class="text-2xs font-bold text-slate-700 hover:text-role-admin bg-white border border-slate-200 hover:border-role-admin/40 rounded-lg px-2.5 py-1 whitespace-nowrap transition-colors"
            @click.prevent="jumpToSection(jump.id)"
          >
            {{ jump.label }}
          </a>
          <div class="flex-1"></div>
          <!-- Guided path — for admins who want to be walked through
               the settings step-by-step instead of scanning the flat
               form. Fires the same updateSettings endpoint at the
               end, so both surfaces stay contract-compatible. -->
          <button
            type="button"
            class="text-2xs font-bold text-role-admin bg-role-admin/10 hover:bg-role-admin/20 border border-role-admin/25 rounded-lg px-2.5 py-1 whitespace-nowrap transition-colors inline-flex items-center gap-1.5 flex-shrink-0"
            @click="showWizard = true"
          >
            <NavIcon name="sparkles" :size="11" />
            Panduan
          </button>
        </nav>

        <!-- Metode presensi -->
        <section
          id="section-metode"
          class="bg-white border border-slate-200 rounded-2xl overflow-hidden scroll-mt-32"
        >
          <div class="px-4 py-3 border-b border-slate-100">
            <h3 class="text-[13px] font-black text-slate-900">
              Metode Presensi
            </h3>
            <p class="text-2xs text-slate-500 mt-0.5">
              Tentukan syarat dan metode yang tersedia saat presensi.
            </p>
          </div>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50"
          >
            <div
              class="w-9 h-9 rounded-lg bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0"
            >
              <NavIcon name="camera" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Wajib Selfie / Kamera
              </p>
              <p class="text-2xs text-slate-500">
                Guru harus mengambil foto kamera langsung.
              </p>
            </div>
            <input
              v-model="form.camera_required"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
          </label>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50 border-t border-slate-100"
          >
            <div
              class="w-9 h-9 rounded-lg bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0"
            >
              <NavIcon name="map-pin" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Wajib Lokasi / GPS
              </p>
              <p class="text-2xs text-slate-500">
                Verifikasi jarak ke sekolah (geofence).
              </p>
            </div>
            <input
              v-model="form.location_required"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
          </label>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50 border-t border-slate-100"
          >
            <div
              class="w-9 h-9 rounded-lg bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0"
            >
              <NavIcon name="qr-code" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Aktifkan QR Gerbang
              </p>
              <p class="text-2xs text-slate-500">
                Pindai QR berputar di gerbang sekolah.
              </p>
            </div>
            <input
              v-model="qrGateEnabled"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
          </label>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50 border-t border-slate-100"
          >
            <div
              class="w-9 h-9 rounded-lg bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0"
            >
              <NavIcon name="id-card" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Aktifkan Kartu QR Pegawai
              </p>
              <p class="text-2xs text-slate-500">
                Pindai QR pada kartu cetak pribadi.
              </p>
            </div>
            <input
              v-model="qrCardEnabled"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
          </label>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50 border-t border-slate-100"
          >
            <div
              class="w-9 h-9 rounded-lg bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0"
            >
              <NavIcon name="users" :size="16" />
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-[13px] font-bold text-slate-900">
                Terbitkan Kartu QR Siswa
              </p>
              <p class="text-2xs text-slate-500">
                Aktifkan untuk mencetak kartu QR siswa (default: hanya
                guru/staf).
              </p>
            </div>
            <input
              v-model="form.issue_student_cards"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
          </label>
        </section>

        <!-- Geofence -->
        <section
          id="section-geofence"
          class="bg-white border border-slate-200 rounded-2xl p-4 space-y-md scroll-mt-32"
        >
          <div>
            <h3 class="text-[13px] font-black text-slate-900">
              Geofence Sekolah
            </h3>
            <p class="text-2xs text-slate-500 mt-0.5">
              Titik pusat &amp; radius area presensi. Kosongkan koordinat untuk
              memakai pin sekolah ({{ schoolPinLabel }}).
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label
                class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Latitude
              </label>
              <input
                v-model="geofenceLatStr"
                type="number"
                step="any"
                placeholder="mis. -6.200000"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
              />
            </div>
            <div>
              <label
                class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Longitude
              </label>
              <input
                v-model="geofenceLngStr"
                type="number"
                step="any"
                placeholder="mis. 106.816666"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
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
          <p class="text-3xs text-slate-400 -mt-1">
            Geser atau ketuk pin di peta untuk memilih titik pusat geofence.
          </p>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label
                class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
              >
                Radius (meter)
              </label>
              <input
                v-model.number="form.geofence_radius_m"
                type="number"
                min="10"
                max="5000"
                class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
              />
              <p class="text-3xs text-slate-400 mt-1">
                Rentang 10 – 5000 m.
              </p>
            </div>
          </div>

          <label class="flex items-center gap-3 cursor-pointer">
            <input
              v-model="form.reject_outside_geofence"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
            <span class="text-[12.5px] text-slate-700">
              <span class="font-bold">Tolak presensi di luar radius.</span>
              Jika dimatikan, presensi di luar area tetap dicatat namun
              ditandai.
            </span>
          </label>
        </section>

        <!-- QR -->
        <section
          id="section-qr"
          class="bg-white border border-slate-200 rounded-2xl p-4 space-y-md scroll-mt-32"
        >
          <div>
            <h3 class="text-[13px] font-black text-slate-900">
              {{ t('admin.attendance.settings.rotation.section') }}
            </h3>
            <p class="text-2xs text-slate-500 mt-0.5">
              {{ t('admin.attendance.settings.rotation.sectionHint') }}
            </p>
          </div>

          <div class="flex items-center gap-md">
            <input
              v-model.number="form.gate_qr_rotation_minutes"
              type="range"
              :disabled="!qrGateEnabled"
              min="1"
              max="60"
              step="1"
              class="flex-1 accent-role-admin disabled:opacity-50"
            />
            <span
              :class="[
                'inline-flex items-baseline gap-1 min-w-[110px] justify-end',
                qrGateEnabled ? 'text-slate-900' : 'text-slate-400',
              ]"
            >
              <span class="font-mono text-2xl font-bold">{{
                form.gate_qr_rotation_minutes ?? 15
              }}</span>
              <span class="text-xs">{{
                t('admin.attendance.settings.rotation.minutes')
              }}</span>
            </span>
          </div>
          <p class="text-3xs text-slate-400 -mt-1">
            Rentang 1 – 60 menit. Rekomendasi: 15 menit.
          </p>

          <label class="flex items-center gap-3 cursor-pointer">
            <input
              v-model="form.geofence_required_for_qr"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
            <span class="text-[12.5px] text-slate-700">
              <span class="font-bold">{{
                t('admin.attendance.settings.flags.geofenceQr')
              }}</span>
              {{ t('admin.attendance.settings.flags.geofenceQrHint') }}
            </span>
          </label>
        </section>

        <!-- Waktu -->
        <section
          id="section-waktu"
          class="bg-white border border-slate-200 rounded-2xl overflow-hidden scroll-mt-32"
        >
          <div class="px-4 py-3 border-b border-slate-100">
            <h3 class="text-[13px] font-black text-slate-900">Waktu</h3>
            <p class="text-2xs text-slate-500 mt-0.5">
              Presensi pulang dan toleransi keterlambatan.
            </p>
          </div>

          <label
            class="flex items-center gap-3 px-4 py-3 cursor-pointer hover:bg-slate-50"
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
              <p class="text-2xs text-slate-500">
                Guru juga melakukan check-out di akhir hari.
              </p>
            </div>
            <input
              v-model="form.checkout_enabled"
              type="checkbox"
              class="w-5 h-5 accent-role-admin"
            />
          </label>

          <div class="px-4 py-3 border-t border-slate-100">
            <label
              class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1"
            >
              Toleransi terlambat (menit)
            </label>
            <input
              v-model.number="form.late_grace_minutes"
              type="number"
              min="0"
              max="600"
              class="w-full sm:w-64 rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30"
            />
            <p class="text-3xs text-slate-400 mt-1">
              Terlambat dihitung setelah jam mengajar pertama + toleransi.
            </p>
          </div>
        </section>

        <div class="flex justify-end">
          <Button variant="primary" :loading="saving" @click="saveSettings">
            <NavIcon name="check" :size="15" />Simpan Pengaturan
          </Button>
        </div>
      </template>
    </template>

    <!-- ════════════════════ CHECKIN RULES TAB ════════════════════ -->
    <template v-else-if="tab === 'checkin_rules'">
      <div v-if="rulesLoading" class="flex items-center justify-center py-xl text-slate-400">
        <Spinner size="md" />
      </div>
      <div v-else-if="rulesError" class="bg-red-50 text-red-600 rounded-xl p-4 text-[13px]">
        {{ rulesError }}
      </div>
      <div v-else class="space-y-md">
        <!-- Add/Edit Checkin Rule Form -->
        <section v-if="showAddCheckinRuleForm" class="bg-white border border-slate-200 rounded-2xl p-5 space-y-md">
          <div class="flex items-center justify-between border-b border-slate-100 pb-3">
            <h3 class="text-sm font-bold text-slate-800">
              {{ checkinRuleForm.id ? 'Edit Aturan Jam Datang' : 'Tambah Aturan Jam Datang Baru' }}
            </h3>
            <button @click="resetCheckinRuleForm" class="text-xs text-slate-400 hover:text-slate-600">Batal</button>
          </div>

          <!-- Scope Selection -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Cakupan (Scope)</label>
              <select v-model="checkinRuleForm.scope_type" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30">
                <option value="global">Semua Guru (Global)</option>
                <option value="grade_level">Per Tingkat Kelas</option>
                <option value="teacher">Per Guru</option>
              </select>
            </div>

            <div v-if="checkinRuleForm.scope_type === 'grade_level'">
              <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Tingkat Kelas</label>
              <select v-model="checkinRuleForm.scope_value" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30">
                <option value="">Pilih Tingkat</option>
                <option v-for="level in gradeLevelsList" :key="level" :value="level">Tingkat {{ level }}</option>
              </select>
            </div>

            <div v-if="checkinRuleForm.scope_type === 'teacher'">
              <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Guru</label>
              <select v-model="checkinRuleForm.scope_value" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30">
                <option value="">Pilih Guru</option>
                <option v-for="teacher in teachersList" :key="teacher.id" :value="teacher.id">
                  {{ teacher.name }} ({{ teacher.employee_number || 'NIP -' }})
                </option>
              </select>
            </div>
          </div>

          <div class="border-t border-slate-100 pt-4 space-y-md">
            <label class="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" v-model="checkinRuleForm.checkin_time_validation_enabled" class="w-5 h-5 accent-role-admin" />
              <span class="text-[12.5px] text-slate-700 font-bold">Aktifkan Validasi Jam Datang</span>
            </label>

            <div v-if="checkinRuleForm.checkin_time_validation_enabled" class="space-y-md bg-slate-50 rounded-xl p-4 border border-slate-200">
              <div>
                <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Tipe Aturan Waktu</label>
                <div class="flex gap-2">
                  <button type="button" @click="checkinRuleForm.checkin_time_rule_type = 'all_days'" class="px-4 py-2 rounded-lg text-xs font-bold transition-all border" :class="checkinRuleForm.checkin_time_rule_type === 'all_days' ? 'bg-role-admin text-white border-role-admin shadow-sm' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'">
                    Sama untuk Semua Hari
                  </button>
                  <button type="button" @click="checkinRuleForm.checkin_time_rule_type = 'custom_days'" class="px-4 py-2 rounded-lg text-xs font-bold transition-all border" :class="checkinRuleForm.checkin_time_rule_type === 'custom_days' ? 'bg-role-admin text-white border-role-admin shadow-sm' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'">
                    Kustom per Hari
                  </button>
                </div>
              </div>

              <!-- Time Inputs -->
              <div v-if="checkinRuleForm.checkin_time_rule_type === 'all_days'" class="w-48">
                <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Jam Datang Maksimal</label>
                <input type="time" v-model="checkinRuleForm.checkin_time_all_days" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30" />
              </div>

              <div v-else class="grid grid-cols-2 sm:grid-cols-7 gap-3">
                <div v-for="day in ['1', '2', '3', '4', '5', '6', '7']" :key="day">
                  <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">
                    {{ getDayName(day) }}
                  </label>
                  <input type="time" v-model="checkinRuleForm.checkin_times_custom_days[day]" class="w-full rounded-lg border border-slate-200 px-2 py-1.5 text-[12px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30" />
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end gap-2 border-t border-slate-100 pt-4">
            <Button variant="secondary" @click="resetCheckinRuleForm">Batal</Button>
            <Button variant="primary" :loading="savingCheckinRule" @click="saveCheckinRule">Simpan Aturan</Button>
          </div>
        </section>

        <!-- Checkin Rules List -->
        <section v-else class="bg-white border border-slate-200 rounded-2xl p-5 space-y-md">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-bold text-slate-800">Daftar Aturan Jam Datang</h3>
              <p class="text-2xs text-slate-400">Atur batasan jam datang khusus untuk jenjang kelas atau guru tertentu.</p>
            </div>
            <Button variant="primary" @click="showAddCheckinRuleForm = true">
              <NavIcon name="plus" :size="13" />Tambah Aturan
            </Button>
          </div>

          <div v-if="checkinRules.length === 0" class="flex flex-col items-center justify-center py-10 text-slate-400 border border-dashed border-slate-200 rounded-xl">
            <NavIcon name="info-circle" :size="24" class="mb-2" />
            <p class="text-xs">Belum ada aturan jam datang khusus yang dibuat.</p>
            <p class="text-3xs">Semua guru akan mengikuti aturan jam datang default sekolah.</p>
          </div>

          <div v-else class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="border-b border-slate-100 text-3xs uppercase font-bold tracking-wider text-slate-400">
                  <th class="py-3 px-4">Cakupan Aturan</th>
                  <th class="py-3 px-4">Validasi Jam Datang</th>
                  <th class="py-3 px-4">Tipe Aturan</th>
                  <th class="py-3 px-4">Batas Jam</th>
                  <th class="py-3 px-4 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody class="text-xs text-slate-700 divide-y divide-slate-50">
                <tr v-for="rule in checkinRules" :key="rule.id" class="hover:bg-slate-50/50">
                  <td class="py-3 px-4 font-bold text-slate-900">{{ getRuleScopeLabel(rule) }}</td>
                  <td class="py-3 px-4">
                    <span class="px-2 py-0.5 rounded-full text-3xs font-bold" :class="rule.checkin_time_validation_enabled ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-600'">
                      {{ rule.checkin_time_validation_enabled ? 'Aktif' : 'Non-aktif' }}
                    </span>
                  </td>
                  <td class="py-3 px-4">
                    {{ rule.checkin_time_rule_type === 'all_days' ? 'Sama Setiap Hari' : 'Kustom per Hari' }}
                  </td>
                  <td class="py-3 px-4 tabular-nums">
                    <div v-if="rule.checkin_time_rule_type === 'all_days'">
                      {{ rule.checkin_time_all_days ? rule.checkin_time_all_days.substring(0, 5) : '-' }}
                    </div>
                    <div v-else class="text-3xs text-slate-500">
                      <span v-for="(time, day) in rule.checkin_times_custom_days" :key="day" class="mr-2 inline-block">
                        <span class="font-bold text-slate-700">{{ getDayName(day).substring(0, 3) }}:</span> {{ time.substring(0, 5) }}
                      </span>
                    </div>
                  </td>
                  <td class="py-3 px-4 text-right space-x-2">
                    <button @click="editCheckinRule(rule)" class="text-role-admin hover:underline font-bold">Edit</button>
                    <button @click="deleteCheckinRule(rule.id)" class="text-red-500 hover:underline font-bold">Hapus</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </template>

    <!-- ════════════════════ CHECKOUT RULES TAB ════════════════════ -->
    <template v-else-if="tab === 'checkout_rules'">
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
              <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Cakupan (Scope)</label>
              <select v-model="ruleForm.scope_type" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30">
                <option value="global">Semua Guru (Global)</option>
                <option value="grade_level">Per Tingkat Kelas</option>
                <option value="teacher">Per Guru</option>
              </select>
            </div>

            <div v-if="ruleForm.scope_type === 'grade_level'">
              <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Tingkat Kelas</label>
              <select v-model="ruleForm.scope_value" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30">
                <option value="">Pilih Tingkat</option>
                <option v-for="level in gradeLevelsList" :key="level" :value="level">Tingkat {{ level }}</option>
              </select>
            </div>

            <div v-if="ruleForm.scope_type === 'teacher'">
              <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Guru</label>
              <select v-model="ruleForm.scope_value" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30">
                <option value="">Pilih Guru</option>
                <option v-for="teacher in teachersList" :key="teacher.id" :value="teacher.id">
                  {{ teacher.name }} ({{ teacher.employee_number || 'NIP -' }})
                </option>
              </select>
            </div>
          </div>

          <div class="border-t border-slate-100 pt-4 space-y-md">
            <label class="flex items-center gap-3 cursor-pointer">
              <input type="checkbox" v-model="ruleForm.checkout_time_validation_enabled" class="w-5 h-5 accent-role-admin" />
              <span class="text-[12.5px] text-slate-700 font-bold">Aktifkan Validasi Minimal Jam Pulang</span>
            </label>

            <div v-if="ruleForm.checkout_time_validation_enabled" class="space-y-md bg-slate-50 rounded-xl p-4 border border-slate-200">
              <div>
                <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Tipe Aturan Waktu</label>
                <div class="flex gap-2">
                  <button type="button" @click="ruleForm.checkout_time_rule_type = 'all_days'" class="px-4 py-2 rounded-lg text-xs font-bold transition-all border" :class="ruleForm.checkout_time_rule_type === 'all_days' ? 'bg-role-admin text-white border-role-admin shadow-sm' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'">
                    Sama untuk Semua Hari
                  </button>
                  <button type="button" @click="ruleForm.checkout_time_rule_type = 'custom_days'" class="px-4 py-2 rounded-lg text-xs font-bold transition-all border" :class="ruleForm.checkout_time_rule_type === 'custom_days' ? 'bg-role-admin text-white border-role-admin shadow-sm' : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'">
                    Kustom per Hari
                  </button>
                </div>
              </div>

              <!-- Time Inputs -->
              <div v-if="ruleForm.checkout_time_rule_type === 'all_days'" class="w-48">
                <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">Jam Pulang Minimal</label>
                <input type="time" v-model="ruleForm.checkout_time_all_days" class="w-full rounded-lg border border-slate-200 px-3 py-2 text-[13px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30" />
              </div>

              <div v-else class="grid grid-cols-2 sm:grid-cols-7 gap-3">
                <div v-for="day in ['1', '2', '3', '4', '5', '6', '7']" :key="day">
                  <label class="text-3xs font-bold text-slate-400 uppercase tracking-widest block mb-1">
                    {{ getDayName(day) }}
                  </label>
                  <input type="time" v-model="ruleForm.checkout_times_custom_days[day]" class="w-full rounded-lg border border-slate-200 px-2 py-1.5 text-[12px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-role-admin/30" />
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
              <p class="text-2xs text-slate-400">Atur batasan jam pulang khusus untuk jenjang kelas atau guru tertentu.</p>
            </div>
            <Button variant="primary" @click="showAddRuleForm = true">
              <NavIcon name="plus" :size="13" />Tambah Aturan
            </Button>
          </div>

          <div v-if="checkoutRules.length === 0" class="flex flex-col items-center justify-center py-10 text-slate-400 border border-dashed border-slate-200 rounded-xl">
            <NavIcon name="info-circle" :size="24" class="mb-2" />
            <p class="text-xs">Belum ada aturan presensi khusus yang dibuat.</p>
            <p class="text-3xs">Semua guru akan mengikuti aturan presensi default sekolah.</p>
          </div>

          <div v-else class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="border-b border-slate-100 text-3xs uppercase font-bold tracking-wider text-slate-400">
                  <th class="py-3 px-4">Cakupan Aturan</th>
                  <th class="py-3 px-4">Validasi Jam Pulang</th>
                  <th class="py-3 px-4">Tipe Aturan</th>
                  <th class="py-3 px-4">Batas Jam</th>
                  <th class="py-3 px-4 text-right">Aksi</th>
                </tr>
              </thead>
              <tbody class="text-xs text-slate-700 divide-y divide-slate-50">
                <tr v-for="rule in checkoutRules" :key="rule.id" class="hover:bg-slate-50/50">
                  <td class="py-3 px-4 font-bold text-slate-900">{{ getRuleScopeLabel(rule) }}</td>
                  <td class="py-3 px-4">
                    <span class="px-2 py-0.5 rounded-full text-3xs font-bold" :class="rule.checkout_time_validation_enabled ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-600'">
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
                    <div v-else class="text-3xs text-slate-500">
                      <span v-for="(time, day) in rule.checkout_times_custom_days" :key="day" class="mr-2 inline-block">
                        <span class="font-bold text-slate-700">{{ getDayName(day).substring(0, 3) }}:</span> {{ time.substring(0, 5) }}
                      </span>
                    </div>
                  </td>
                  <td class="py-3 px-4 text-right space-x-2">
                    <button @click="editRule(rule)" class="text-role-admin hover:underline font-bold">Edit</button>
                    <button @click="deleteRule(rule.id)" class="text-red-500 hover:underline font-bold">Hapus</button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </template>

    <!-- Panduan wizard — mounted at the view root so its z-index sits
         above the sticky section-nav. v-if lazy-mounts the leaflet
         map + step components only when the admin opens the wizard. -->
    <AttendanceConfigWizard
      v-if="showWizard"
      :initial="form"
      @close="showWizard = false"
      @saved="onWizardSaved"
    />
  </div>
</template>
