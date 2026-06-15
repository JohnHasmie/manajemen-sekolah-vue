<!--
  AdminSchoolLevelSettingsView.vue — admin Pengaturan Umum hub.

  Mirrors Flutter's `SchoolLevelSettingsScreen`. Two stacked sections:

    1. Informasi Sekolah — name / address / jenjang as info-tile rows.
       Tapping any row (or the Edit link) opens the edit modal.
    2. Tahun Ajaran — active-year hero card with the canonical AY
       label + semester pill, plus an "Arsip & kelola" tile that
       drills into `admin.settings.kelola-tahun-ajaran` (Phase 3).

  Endpoints:
    GET  /school/settings
    POST /school/settings
    GET  /semesters
    AcademicYearStore (already bootstrapped at app start)
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { SettingsService, type SchoolSettings, type Semester } from '@/services/settings.service';
import { useAcademicYearStore } from '@/stores/academic-year';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Toast from '@/components/ui/Toast.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();
const ayStore = useAcademicYearStore();
const { t } = useI18n();

const settings = ref<SchoolSettings>({
  education_level: 'SMA',
  name: '',
  address: '',
});
const activeSemester = ref<Semester | null>(null);
const isLoading = ref(true);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const JENJANG_OPTIONS = ['SD', 'SMP', 'SMA', 'SMK'] as const;

function jenjangFullLabel(code: string): string {
  switch (code) {
    case 'SD': return t('admin.sekolah.school_level_settings.jenjang_sd');
    case 'SMP': return t('admin.sekolah.school_level_settings.jenjang_smp');
    case 'SMA': return t('admin.sekolah.school_level_settings.jenjang_sma');
    case 'SMK': return t('admin.sekolah.school_level_settings.jenjang_smk');
    default: return code || '—';
  }
}

async function loadAll() {
  isLoading.value = true;
  try {
    const [school, sem] = await Promise.all([
      SettingsService.getSchool().catch(() => settings.value),
      SettingsService.getActiveSemester().catch(() => null),
    ]);
    settings.value = school;
    activeSemester.value = sem;
  } finally {
    isLoading.value = false;
  }
}

onMounted(loadAll);

// ── Edit modal ─────────────────────────────────────────────────────
const showEditModal = ref(false);
const formName = ref('');
const formAddress = ref('');
const formJenjang = ref<string>('SMA');
const isSaving = ref(false);

function openEdit() {
  formName.value = settings.value.name;
  formAddress.value = settings.value.address;
  formJenjang.value = settings.value.education_level || 'SMA';
  showEditModal.value = true;
}

async function saveEdit() {
  if (!formName.value.trim()) {
    toast.value = { message: t('admin.sekolah.school_level_settings.toast_name_required'), tone: 'error' };
    return;
  }
  isSaving.value = true;
  try {
    const updated = await SettingsService.updateSchool({
      name: formName.value.trim(),
      address: formAddress.value.trim(),
      education_level: formJenjang.value,
    });
    settings.value = updated;
    showEditModal.value = false;
    toast.value = { message: t('admin.sekolah.school_level_settings.toast_saved'), tone: 'success' };
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isSaving.value = false;
  }
}

// ── Tahun Ajaran ───────────────────────────────────────────────────
const activeYear = computed(() => ayStore.activeYear);
const semesterLabel = computed(() => {
  const fromAY = activeYear.value?.semester;
  const fromSem = activeSemester.value?.name;
  const raw = (fromAY || fromSem || '').toLowerCase();
  // Canonical backend slugs: `odd` / `even`. Legacy values kept for
  // defensive reads against un-migrated rows or older /current-period
  // payloads. The `1` / `semester 1` matches handle the older
  // `academic_years.semester` numeric form returned by some legacy
  // endpoints.
  if (raw === 'odd' || raw === 'ganjil' || raw === 'gasal' || raw === '1' || raw === 'semester 1') return t('admin.sekolah.school_level_settings.semester_odd');
  if (raw === 'even' || raw === 'genap' || raw === '2' || raw === 'semester 2') return t('admin.sekolah.school_level_settings.semester_even');
  return fromAY || fromSem || '—';
});

function openKelolaTahunAjaran() {
  // Phase 3 ports KelolaTahunAjaranScreen here. Until then, only push
  // when the route actually exists so we don't blow up the page with
  // an unmatched-name warning.
  if (router.hasRoute('admin.settings.kelola-tahun-ajaran')) {
    router.push({ name: 'admin.settings.kelola-tahun-ajaran' });
  } else {
    toast.value = {
      message: t('admin.sekolah.school_level_settings.toast_ay_coming'),
      tone: 'error',
    };
  }
}

function goBack() {
  router.push({ name: 'admin.settings' });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      {{ t('admin.sekolah.school_level_settings.back_to_settings') }}
    </button>

    <BrandPageHeader
      role="admin"
      :kicker="t('admin.sekolah.school_level_settings.header_kicker')"
      :title="t('admin.sekolah.school_level_settings.header_title')"
      :meta="t('admin.sekolah.school_level_settings.header_meta')"
      :live-dot="false"
    />

    <!-- Loading skeleton -->
    <div v-if="isLoading" class="space-y-3">
      <div class="h-24 bg-white border border-slate-200 rounded-2xl animate-pulse" />
      <div class="h-24 bg-white border border-slate-200 rounded-2xl animate-pulse" />
    </div>

    <template v-else>
      <!-- ── Section 1: Informasi Sekolah ── -->
      <div class="flex items-center gap-3 px-1 pt-1">
        <div class="w-9 h-9 rounded-xl bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0">
          <NavIcon name="home" :size="16" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-black text-slate-900">{{ t('admin.sekolah.school_level_settings.section_info_title') }}</p>
          <p class="text-[11px] text-slate-500">{{ t('admin.sekolah.school_level_settings.section_info_desc') }}</p>
        </div>
        <button
          type="button"
          class="text-[12px] font-bold text-role-admin hover:underline inline-flex items-center gap-1"
          @click="openEdit"
        >
          <NavIcon name="edit" :size="12" />
          {{ t('admin.sekolah.school_level_settings.edit') }}
        </button>
      </div>

      <section class="bg-white border border-slate-200 rounded-2xl overflow-hidden">
        <button
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-slate-50"
          @click="openEdit"
        >
          <div class="w-9 h-9 rounded-lg bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0">
            <NavIcon name="home" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.school_level_settings.field_name') }}</p>
            <p class="text-[13.5px] font-bold text-slate-900 truncate">
              {{ settings.name || '—' }}
            </p>
          </div>
          <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
        </button>

        <button
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-slate-50 border-t border-slate-100"
          @click="openEdit"
        >
          <div class="w-9 h-9 rounded-lg bg-violet-100 text-violet-700 grid place-items-center flex-shrink-0">
            <NavIcon name="flag" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.school_level_settings.field_address') }}</p>
            <p class="text-[13.5px] font-bold text-slate-900 leading-snug">
              {{ settings.address || '—' }}
            </p>
          </div>
          <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
        </button>

        <button
          type="button"
          class="w-full text-left px-4 py-3 flex items-center gap-3 hover:bg-slate-50 border-t border-slate-100"
          @click="openEdit"
        >
          <div class="w-9 h-9 rounded-lg bg-role-admin/10 text-role-admin grid place-items-center flex-shrink-0">
            <NavIcon name="layers" :size="16" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.school_level_settings.field_jenjang') }}</p>
            <p class="text-[13.5px] font-bold text-slate-900 truncate">
              {{ jenjangFullLabel(settings.education_level) }}
            </p>
          </div>
          <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
        </button>
      </section>

      <!-- ── Section 2: Tahun Ajaran ── -->
      <div class="flex items-center gap-3 px-1 pt-3">
        <div class="w-9 h-9 rounded-xl bg-emerald-100 text-emerald-700 grid place-items-center flex-shrink-0">
          <NavIcon name="calendar" :size="16" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13px] font-black text-slate-900">{{ t('admin.sekolah.school_level_settings.section_ay_title') }}</p>
          <p class="text-[11px] text-slate-500">{{ t('admin.sekolah.school_level_settings.section_ay_desc') }}</p>
        </div>
        <button
          type="button"
          class="text-[12px] font-bold text-role-admin hover:underline inline-flex items-center gap-1"
          @click="openKelolaTahunAjaran"
        >
          {{ t('admin.sekolah.school_level_settings.manage') }}
          <NavIcon name="chevron-right" :size="12" />
        </button>
      </div>

      <!-- Active year hero card -->
      <button
        v-if="activeYear"
        type="button"
        class="w-full text-left rounded-2xl overflow-hidden bg-gradient-to-br from-emerald-600 to-emerald-700 text-white p-4 shadow-lg hover:shadow-xl transition-shadow"
        @click="openKelolaTahunAjaran"
      >
        <p class="text-[10px] font-bold uppercase tracking-widest text-emerald-100">
          {{ t('admin.sekolah.school_level_settings.active_ay_label') }}
        </p>
        <p class="text-2xl font-black mt-1 tracking-tight">
          {{ activeYear.year }}
        </p>
        <div class="mt-3 flex items-center gap-2">
          <span class="inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-white/20 text-[11px] font-bold">
            <NavIcon name="check-circle" :size="11" />
            {{ semesterLabel }}
          </span>
        </div>
      </button>

      <button
        v-else
        type="button"
        class="w-full text-left rounded-2xl border border-dashed border-amber-300 bg-amber-50 p-4 hover:bg-amber-100 transition-colors"
        @click="openKelolaTahunAjaran"
      >
        <p class="text-[10px] font-bold uppercase tracking-widest text-amber-700">
          {{ t('admin.sekolah.school_level_settings.no_active_ay') }}
        </p>
        <p class="text-[13px] font-bold text-amber-900 mt-1">
          {{ t('admin.sekolah.school_level_settings.tap_to_create_ay') }}
        </p>
      </button>

      <button
        type="button"
        class="w-full text-left bg-white border border-slate-200 rounded-2xl px-4 py-3 flex items-center gap-3 hover:bg-slate-50"
        @click="openKelolaTahunAjaran"
      >
        <div class="w-9 h-9 rounded-lg bg-slate-100 text-slate-700 grid place-items-center flex-shrink-0">
          <NavIcon name="file-text" :size="16" />
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[13.5px] font-bold text-slate-900">{{ t('admin.sekolah.school_level_settings.archive_title') }}</p>
          <p class="text-[11px] text-slate-500">{{ t('admin.sekolah.school_level_settings.archive_desc') }}</p>
        </div>
        <NavIcon name="chevron-right" :size="14" class="text-slate-300" />
      </button>
    </template>

    <!-- Edit modal -->
    <Modal
      v-if="showEditModal"
      :title="t('admin.sekolah.school_level_settings.edit_modal_title')"
      :subtitle="t('admin.sekolah.school_level_settings.edit_modal_subtitle')"
      size="sm"
      @close="showEditModal = false"
    >
      <div class="space-y-3">
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.school_level_settings.field_name') }}</label>
          <input
            v-model="formName"
            type="text"
            :placeholder="t('admin.sekolah.school_level_settings.name_placeholder')"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.school_level_settings.field_address_label') }}</label>
          <textarea
            v-model="formAddress"
            rows="2"
            :placeholder="t('admin.sekolah.school_level_settings.address_placeholder')"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] text-slate-900 outline-none focus:border-role-admin resize-y"
          />
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">{{ t('admin.sekolah.school_level_settings.field_jenjang_short') }}</label>
          <div class="mt-1 grid grid-cols-4 gap-2">
            <button
              v-for="opt in JENJANG_OPTIONS"
              :key="opt"
              type="button"
              class="rounded-xl border px-2 py-2 text-[12px] font-bold transition-colors"
              :class="formJenjang === opt
                ? 'border-role-admin bg-role-admin/10 text-role-admin'
                : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'"
              @click="formJenjang = opt"
            >
              {{ opt }}
            </button>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block :disabled="isSaving" @click="showEditModal = false">
            {{ t('admin.sekolah.school_level_settings.cancel') }}
          </Button>
          <Button variant="primary" block :disabled="isSaving" @click="saveEdit">
            {{ isSaving ? t('admin.sekolah.school_level_settings.saving') : t('admin.sekolah.school_level_settings.save') }}
          </Button>
        </div>
      </div>
    </Modal>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
