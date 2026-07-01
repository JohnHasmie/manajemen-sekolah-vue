<!--
  AttendanceSettingsView.vue — admin form for the four QR-related
  settings keys added in backend MR !226. Sits alongside the existing
  AdminTeacherAttendanceView (selfie + geofence settings) rather than
  replacing it; routes from the sidebar land here for QR-specific
  toggles. Picking a method here flips its availability on the mobile
  scanner (Phase 2 MR) and the gate display (this MR).

  Wire format mirrors the backend's `allowed_methods` JSON array
  contract. The form keeps a local Set so toggling chips stays cheap;
  on save we materialise it back into the array the API expects.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import { useToast } from '@/composables/useToast';
import type {
  TeacherAttendanceSettings,
} from '@/types/teacher-attendance';
import { DEFAULT_TEACHER_ATTENDANCE_SETTINGS } from '@/types/teacher-attendance';
import {
  CHECK_IN_METHODS,
  type CheckInMethod,
} from '@/types/attendance-qr';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Card from '@/components/ui/Card.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const saving = ref(false);
/**
 * Working copy edited by the form. Starts from the typed defaults so
 * the chips render with something selected before the GET lands.
 */
const form = ref<TeacherAttendanceSettings>({
  ...DEFAULT_TEACHER_ATTENDANCE_SETTINGS,
});

/**
 * Local mutable Set of allowed methods. The settings field is an array
 * but toggling via a Set keeps add/remove O(1) and avoids re-computing
 * `includes` on every render of the chip row.
 */
const methodsSet = ref<Set<CheckInMethod>>(new Set(['SELFIE']));

const methods: { key: CheckInMethod; labelKey: string; descKey: string }[] = [
  {
    key: 'SELFIE',
    labelKey: 'admin.attendance.settings.method.selfie',
    descKey: 'admin.attendance.settings.method.selfieDesc',
  },
  {
    key: 'QR_GATE',
    labelKey: 'admin.attendance.settings.method.gateQr',
    descKey: 'admin.attendance.settings.method.gateQrDesc',
  },
  {
    key: 'QR_CARD',
    labelKey: 'admin.attendance.settings.method.cardQr',
    descKey: 'admin.attendance.settings.method.cardQrDesc',
  },
];

/** Whether the form has gate-QR enabled — gates the rotation slider. */
const showRotationSlider = computed(() => methodsSet.value.has('QR_GATE'));

async function load() {
  loading.value = true;
  try {
    const s = await TeacherAttendanceService.getSettings();
    form.value = s;
    methodsSet.value = new Set(s.allowed_methods ?? ['SELFIE']);
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.settings.loadFail'),
    );
  } finally {
    loading.value = false;
  }
}

function toggleMethod(m: CheckInMethod) {
  // Mirror the backend's ≥1 constraint locally so the user can't end
  // up with an empty set (which would 422). The disabled state on the
  // last-selected chip's button click is a belt-and-suspenders guard.
  if (methodsSet.value.has(m)) {
    if (methodsSet.value.size <= 1) {
      toast.error(t('admin.attendance.settings.method.atLeastOne'));
      return;
    }
    const next = new Set(methodsSet.value);
    next.delete(m);
    methodsSet.value = next;
  } else {
    const next = new Set(methodsSet.value);
    next.add(m);
    methodsSet.value = next;
  }
}

async function save() {
  const rot = form.value.gate_qr_rotation_minutes ?? 15;
  if (rot < 5 || rot > 60) {
    toast.error(t('admin.attendance.settings.rotation.outOfRange'));
    return;
  }

  saving.value = true;
  try {
    const saved = await TeacherAttendanceService.updateSettings({
      allowed_methods: Array.from(methodsSet.value),
      gate_qr_rotation_minutes: rot,
      geofence_required_for_qr: !!form.value.geofence_required_for_qr,
      issue_student_cards: !!form.value.issue_student_cards,
    });
    // Merge in case the server returns the full payload — we only
    // overwrite the fields we touched.
    form.value = { ...form.value, ...saved };
    methodsSet.value = new Set(saved.allowed_methods ?? ['SELFIE']);
    toast.success(t('admin.attendance.settings.saved'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.settings.saveFail'),
    );
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.attendance.settings.kicker')"
      :title="t('admin.attendance.settings.title')"
      :meta="t('admin.attendance.settings.meta')"
    />

    <div
      v-if="loading"
      class="flex items-center justify-center py-16 text-slate-500"
    >
      <Spinner size="md" />
      <span class="ml-2 text-sm">{{ t('common.loading') }}</span>
    </div>

    <template v-else>
      <!-- Method chips. Each chip is a self-contained toggle so the
           user reads the description without expanding a menu. -->
      <Card
        :title="t('admin.attendance.settings.method.section')"
        :subtitle="t('admin.attendance.settings.method.sectionHint')"
      >
        <div class="grid gap-sm sm:grid-cols-3">
          <button
            v-for="m in methods"
            :key="m.key"
            type="button"
            :class="[
              'group text-left rounded-2xl border p-md transition focus:outline-none focus:ring-2 focus:ring-offset-1 focus:ring-role-admin',
              methodsSet.has(m.key)
                ? 'bg-role-admin/5 border-role-admin/40'
                : 'bg-white border-slate-200 hover:bg-slate-50',
            ]"
            @click="toggleMethod(m.key)"
          >
            <div class="flex items-center gap-2">
              <span
                :class="[
                  'inline-flex h-8 w-8 items-center justify-center rounded-lg',
                  methodsSet.has(m.key)
                    ? 'bg-role-admin text-white'
                    : 'bg-slate-100 text-slate-500',
                ]"
              >
                <NavIcon
                  :name="
                    m.key === 'SELFIE'
                      ? 'camera'
                      : m.key === 'QR_GATE'
                      ? 'qr-code'
                      : 'id-card'
                  "
                  :size="16"
                />
              </span>
              <span class="font-semibold text-slate-900">{{
                t(m.labelKey)
              }}</span>
              <span
                v-if="methodsSet.has(m.key)"
                class="ml-auto text-role-admin"
              >
                <NavIcon name="check" :size="16" />
              </span>
            </div>
            <p class="text-xs text-slate-600 mt-1 leading-relaxed">
              {{ t(m.descKey) }}
            </p>
          </button>
        </div>
      </Card>

      <!-- Rotation slider — only meaningful when gate QR is on, but
           we still render the section so the form layout is stable
           when toggling. Disabled state communicates the dependency. -->
      <Card
        :title="t('admin.attendance.settings.rotation.section')"
        :subtitle="t('admin.attendance.settings.rotation.sectionHint')"
      >
        <div class="space-y-sm">
          <div class="flex items-center gap-md">
            <input
              v-model.number="form.gate_qr_rotation_minutes"
              type="range"
              :disabled="!showRotationSlider"
              min="5"
              max="60"
              step="5"
              class="flex-1 accent-role-admin disabled:opacity-50"
            />
            <span
              :class="[
                'inline-flex items-baseline gap-1 min-w-[110px] justify-end',
                showRotationSlider ? 'text-slate-900' : 'text-slate-400',
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
          <p class="text-xs text-slate-500">
            {{ t('admin.attendance.settings.rotation.hint') }}
          </p>
        </div>
      </Card>

      <!-- Two-toggle row for the remaining flags. Plain checkboxes
           are clearer than custom switches at admin density and
           don't need extra a11y plumbing. -->
      <Card
        :title="t('admin.attendance.settings.flags.section')"
        :subtitle="t('admin.attendance.settings.flags.sectionHint')"
      >
        <label
          class="flex items-start gap-sm cursor-pointer rounded-xl px-sm py-sm hover:bg-slate-50"
        >
          <input
            v-model="form.geofence_required_for_qr"
            type="checkbox"
            class="mt-1 h-4 w-4 rounded text-role-admin accent-role-admin focus:ring-role-admin"
          />
          <span>
            <span class="block font-semibold text-slate-900 text-sm">{{
              t('admin.attendance.settings.flags.geofenceQr')
            }}</span>
            <span class="block text-xs text-slate-600 mt-0.5 leading-relaxed">{{
              t('admin.attendance.settings.flags.geofenceQrHint')
            }}</span>
          </span>
        </label>
        <label
          class="flex items-start gap-sm cursor-pointer rounded-xl px-sm py-sm hover:bg-slate-50"
        >
          <input
            v-model="form.issue_student_cards"
            type="checkbox"
            class="mt-1 h-4 w-4 rounded text-role-admin accent-role-admin focus:ring-role-admin"
          />
          <span>
            <span class="block font-semibold text-slate-900 text-sm">{{
              t('admin.attendance.settings.flags.studentCards')
            }}</span>
            <span class="block text-xs text-slate-600 mt-0.5 leading-relaxed">{{
              t('admin.attendance.settings.flags.studentCardsHint')
            }}</span>
          </span>
        </label>
      </Card>

      <div class="flex justify-end pt-sm">
        <Button :loading="saving" :disabled="saving" @click="save">
          {{
            saving
              ? t('common.saving')
              : t('admin.attendance.settings.save')
          }}
        </Button>
      </div>
    </template>
  </div>
</template>
