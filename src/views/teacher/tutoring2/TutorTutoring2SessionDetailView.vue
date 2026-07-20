<!--
  TutorTutoring2SessionDetailView.vue — single bimbel session detail (WEB-4).

  Composition:
    1. BrandPageHeader     — role="teacher".
    2. AsyncView           — state machine.
       Default slot renders one info panel + button row.
    3. No KPIs, no filter toolbar, no floating CTA.

  Data path: `TutoringBimbelService.listSessions({})` filtered client-
  side to `s.id === route.params.id`. TODO: promote to a dedicated
  `getSession(id)` when the service gains it (matches the pattern the
  other tutoring-v2 endpoints already use).
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import type { StatusBadgeTone } from '@/types/status-badge';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { useToast } from '@/composables/useToast';
import {
  TutoringBimbelService,
  type BimbelSession,
} from '@/services/tutoring-bimbel.service';

const route = useRoute();
const router = useRouter();
const toast = useToast();

const sessionId = computed<string>(() => String(route.params.id));

// TODO: swap for `TutoringBimbelService.getSession(id)` once the
// service exposes a single-fetch endpoint. For now we page through
// `listSessions` and filter client-side — matches the interim
// contract the admin views use.
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listSessions({ per_page: 100 });
  const match = items.find((s) => s.id === sessionId.value);
  return match ?? null;
});
useAcademicYearWatcher(reload);

const session = computed<BimbelSession | null>(() => {
  return state.value.status === 'content' ? (state.value.data as BimbelSession) : null;
});

function sessionTone(status: BimbelSession['status']): StatusBadgeTone {
  switch (status) {
    case 'done':
      return 'success';
    case 'in_progress':
      return 'info';
    case 'scheduled':
      return 'neutral';
    case 'cancelled':
      return 'danger';
  }
}

function formatDateTime(iso: string): string {
  return new Date(iso).toLocaleString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function formatTimeRange(startIso: string, endIso: string): string {
  const opts: Intl.DateTimeFormatOptions = { hour: '2-digit', minute: '2-digit' };
  return `${new Date(startIso).toLocaleTimeString('id-ID', opts)} – ${new Date(endIso).toLocaleTimeString('id-ID', opts)}`;
}

function ambilPresensi() {
  router.push({
    name: 'teacher.tutoring2.attendance',
    params: { sessionId: sessionId.value },
  });
}

function rescheduleAction() {
  toast.info('Reschedule belum tersedia.');
}

async function completeSession() {
  try {
    await TutoringBimbelService.completeSession(sessionId.value);
    toast.success('Sesi ditandai selesai.');
    await reload();
  } catch (e) {
    toast.error((e as Error).message || 'Gagal menandai sesi selesai.');
  }
}

const metaText = computed(() =>
  session.value ? formatDateTime(session.value.starts_at) : 'Memuat…',
);
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="teacher"
      kicker="Tutor Bimbel"
      title="Detail Sesi"
      :meta="metaText"
    />

    <AsyncView
      :state="state"
      loading-variant="cards"
      :loading-rows="1"
      empty-title="Sesi tidak ditemukan"
      empty-description="Sesi ini mungkin sudah dihapus atau bukan milik Anda."
      @retry="reload"
    >
      <template #default>
        <template v-if="session">
          <div class="rounded-3xl border border-slate-100 bg-white shadow-sm p-4 space-y-3">
            <div class="flex items-center justify-between gap-3">
              <div>
                <p class="text-2xs font-bold uppercase tracking-wide text-slate-400">Status</p>
                <div class="mt-1">
                  <StatusBadge
                    :label="session.status_label ?? session.status"
                    :tone="sessionTone(session.status)"
                    uppercase
                  />
                </div>
              </div>
            </div>

            <dl class="divide-y divide-slate-100 border-t border-slate-100 pt-3 text-sm">
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">Waktu</dt>
                <dd class="flex-1 text-slate-900">{{ formatTimeRange(session.starts_at, session.ends_at) }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">Kelompok</dt>
                <dd class="flex-1 truncate text-slate-900">Grup {{ session.learning_group_id.slice(0, 8) }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">Ruang</dt>
                <dd class="flex-1 text-slate-900">{{ session.room ?? '—' }}</dd>
              </div>
              <div class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">Tutor</dt>
                <dd class="flex-1 truncate text-slate-900">{{ session.tutor_id ?? '—' }}</dd>
              </div>
              <div v-if="session.tutor_note" class="flex items-start gap-3 py-2">
                <dt class="w-24 shrink-0 text-2xs font-bold uppercase tracking-wide text-slate-400">Catatan</dt>
                <dd class="flex-1 text-slate-900">{{ session.tutor_note }}</dd>
              </div>
            </dl>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <Button variant="primary" @click="ambilPresensi">Ambil presensi</Button>
            <Button variant="secondary" @click="rescheduleAction">Reschedule</Button>
            <Button
              v-if="session.status === 'in_progress'"
              variant="success"
              @click="completeSession"
            >
              Tandai selesai
            </Button>
          </div>
        </template>
      </template>
    </AsyncView>
  </div>
</template>
