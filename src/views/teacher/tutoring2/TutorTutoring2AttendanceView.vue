<!--
  TutorTutoring2AttendanceView.vue — Presensi per sesi (WEB-4 exemplar).

  Wraps the WEB-2 `TutoringAttendanceRoster` component end-to-end.
-->
<script setup lang="ts">
import { ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import TutoringAttendanceRoster from '@/components/tutoring/TutoringAttendanceRoster.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';
import type { AttendanceStatus } from '@/types/attendance';
import type { TutoringAttendanceRow } from '@/types/tutoring-bimbel';

const route = useRoute();
const router = useRouter();
const toast = useToast();

const sessionId = ref<string>((route.params.sessionId as string) ?? '');
if (!sessionId.value) {
  router.replace({ name: 'teacher.tutoring2.sessions' });
}

const rows = ref<TutoringAttendanceRow[]>([]);
const search = ref('');
const filterMode = ref<'all' | 'unmarked'>('all');
const saving = ref(false);

const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessionAttendance(sessionId.value);
  return items;
});

watch(state, (s) => {
  if (s.status === 'content' || s.status === 'empty') {
    rows.value = (s as { status: string; data?: TutoringAttendanceRow[] }).data ?? [];
  }
});

function onUpdateRow(payload: { enrollment_id: string; status: AttendanceStatus; notes?: string }) {
  const idx = rows.value.findIndex((r) => r.enrollment_id === payload.enrollment_id);
  if (idx >= 0) {
    rows.value[idx] = { ...rows.value[idx], status: payload.status, notes: payload.notes };
  }
}

async function onSave() {
  if (saving.value) return;
  saving.value = true;
  try {
    const marked = rows.value
      .filter((r) => r.status !== null)
      .map((r) => ({
        enrollment_id: r.enrollment_id,
        status: r.status as string,
        notes: r.notes,
      }));
    await TutoringBimbelService.markSessionAttendance(sessionId.value, marked);
    toast.success(`Presensi tersimpan (${marked.length} siswa)`);
    reload();
  } catch (e) {
    toast.error(`Gagal menyimpan presensi: ${(e as Error).message}`);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      kicker="Tutor Bimbel"
      title="Presensi sesi"
      :meta="`${rows.length} siswa terdaftar`"
    />

    <AsyncView :state="state" loading-variant="list" :loading-rows="6" empty-title="Sesi belum punya siswa" @retry="reload">
      <template #default>
        <TutoringAttendanceRoster
          :rows="rows"
          :session-id="sessionId"
          :loading="state.status === 'loading'"
          :saving="saving"
          :search="search"
          :filter-mode="filterMode"
          @update:row="onUpdateRow"
          @save="onSave"
          @update:search="(v) => (search = v)"
          @update:filter-mode="(v) => (filterMode = v)"
        />
      </template>
    </AsyncView>
  </div>
</template>
