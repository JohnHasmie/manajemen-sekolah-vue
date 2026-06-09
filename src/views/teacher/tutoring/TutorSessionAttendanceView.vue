<!--
  TutorSessionAttendanceView — record attendance for one bimbel session.
  Merges enrollees + saved roster, one bulk save (idempotent server-
  side, fires PER_SESSION billing). Rebuilt on the tutoring shared
  components.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const toast = useToast();

const sessionId = String(route.params.sessionId ?? '');
const groupId = String(route.query.groupId ?? '');
const title = String(route.query.title ?? t('tutoring.attendance.title'));

const STATUS_KEYS: Record<string, string> = {
  PRESENT: 'tutoring.status.present',
  LATE: 'tutoring.status.late',
  SICK: 'tutoring.status.sick',
  EXCUSED: 'tutoring.status.excused',
  ALPHA: 'tutoring.status.alpha',
};
const statusLabel = (k: string) => (STATUS_KEYS[k] ? t(STATUS_KEYS[k]) : k);

const loading = ref(true);
const saving = ref(false);
const error = ref<string | null>(null);

/** student_id → name */
const names = ref<Record<string, string>>({});
/** student_id → chosen status */
const chosen = ref<Record<string, string>>({});

const statusKeys = Object.keys(STATUS_KEYS);

async function load() {
  loading.value = true;
  error.value = null;
  try {
    const [enrollees, saved] = await Promise.all([
      TutoringService.getGroupEnrollees(groupId),
      TutoringService.getSessionRoster(sessionId),
    ]);
    const savedByStudent: Record<string, string> = {};
    for (const r of saved) savedByStudent[r.student_id] = r.status;

    const n: Record<string, string> = {};
    const c: Record<string, string> = {};
    for (const e of enrollees) {
      n[e.student_id] = e.student?.name ?? '—';
      c[e.student_id] = savedByStudent[e.student_id] ?? 'PRESENT';
    }
    for (const r of saved) {
      if (!(r.student_id in n)) {
        n[r.student_id] = r.student?.name ?? '—';
        c[r.student_id] = r.status;
      }
    }
    names.value = n;
    chosen.value = c;
  } catch (e) {
    error.value =
      e instanceof Error ? e.message : t('tutoring.attendance.loadFailed');
  } finally {
    loading.value = false;
  }
}

async function save() {
  saving.value = true;
  try {
    const items = Object.entries(chosen.value).map(([student_id, status]) => ({
      student_id,
      status,
    }));
    await TutoringService.recordAttendance(sessionId, items);
    toast.success(t('tutoring.attendance.saved'));
    router.back();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('tutoring.attendance.saveFailed'),
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
      role="guru"
      :kicker="'Bimbel · Sesi · ' + title"
      :title="t('tutoring.attendance.title')"
      :meta="`${Object.keys(names).length} siswa`"
    />

    <div v-if="loading" class="py-12 text-center text-slate-500">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="error"
      :text="error"
      icon="alert-circle"
    />
    <TutoringEmpty
      v-else-if="Object.keys(names).length === 0"
      :text="t('tutoring.attendance.noStudents')"
      icon="users"
    />
    <template v-else>
      <div class="space-y-2">
        <div
          v-for="(name, studentId) in names"
          :key="studentId"
          class="flex items-center gap-3 bg-white border border-slate-100 rounded-2xl p-3"
        >
          <span
            class="w-9 h-9 rounded-xl bg-role-teacher-soft text-role-teacher grid place-items-center flex-shrink-0"
          >
            <NavIcon name="user" :size="18" />
          </span>
          <span class="flex-1 text-sm font-semibold text-slate-900">{{ name }}</span>
          <select
            v-model="chosen[studentId]"
            class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-xs font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option v-for="k in statusKeys" :key="k" :value="k">{{ statusLabel(k) }}</option>
          </select>
        </div>
      </div>

      <button
        :disabled="saving"
        class="w-full rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="save"
      >
        {{ saving ? t('tutoring.common.saving') : t('tutoring.attendance.save') }}
      </button>
    </template>
  </div>
</template>
