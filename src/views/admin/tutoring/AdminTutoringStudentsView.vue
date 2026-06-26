<!--
  AdminTutoringStudentsView — full rewrite per mockup
  admin_redesign_w1_people frame 1.

  Hero (navy) → search + status pill filter → table with avatar +
  parent + group + tunggakan + 30-day attendance bar + status.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatRupiah } from '@/lib/format';
import type { TutoringStudentRow } from '@/types/tutoring';

import TutorHomeHero from '@/components/feature/tutoring/TutorHomeHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminActionMenu from '@/components/feature/tutoring/AdminActionMenu.vue';
import AdminConfirmDialog from '@/components/feature/tutoring/AdminConfirmDialog.vue';

const router = useRouter();
const toast = useToast();
const { t } = useI18n();

const loading = ref(true);
const rows = ref<TutoringStudentRow[]>([]);
const query = ref('');
const status = ref<'all' | 'active' | 'risk' | 'graduated' | 'leave'>('all');

const cancelTarget = ref<TutoringStudentRow | null>(null);
const cancelBusy = ref(false);

const editTarget = ref<TutoringStudentRow | null>(null);
const editForm = ref({ name: '', guardian_name: '', guardian_phone: '' });
const editBusy = ref(false);

async function load() {
  loading.value = true;
  try { rows.value = await TutoringService.getAdminStudents(); }
  catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

function pickRow(r: TutoringStudentRow, key: string) {
  if (key === 'cancel') cancelTarget.value = r;
  else if (key === 'edit') {
    editTarget.value = r;
    editForm.value = {
      name: r.student_name,
      guardian_name: '',
      guardian_phone: '',
    };
  }
}

async function submitEdit() {
  if (!editTarget.value) return;
  if (editForm.value.name.trim().length < 2) {
    toast.error(t('admin.bimbel.students.name_min'));
    return;
  }
  editBusy.value = true;
  try {
    // Only send fields the admin actually filled in. Empty guardian
    // inputs mean "tidak diubah" — we don't want to clobber an
    // existing parent contact with null just because the field
    // wasn't pre-populated.
    const payload: {
      name: string;
      guardian_name?: string;
      guardian_phone?: string;
    } = { name: editForm.value.name.trim() };
    const gn = editForm.value.guardian_name.trim();
    const gp = editForm.value.guardian_phone.trim();
    if (gn) payload.guardian_name = gn;
    if (gp) payload.guardian_phone = gp;
    await TutoringService.updateStudent(editTarget.value.student_id, payload);
    toast.success(t('admin.bimbel.students.edit_saved'));
    editTarget.value = null;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.students.edit_fail'));
  } finally { editBusy.value = false; }
}

async function confirmCancel() {
  if (!cancelTarget.value) return;
  cancelBusy.value = true;
  try {
    await TutoringService.cancelEnrollment(cancelTarget.value.enrollment_id);
    toast.success(t('admin.bimbel.students.cancel_done'));
    cancelTarget.value = null;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.students.cancel_fail'));
  } finally { cancelBusy.value = false; }
}

function classify(r: TutoringStudentRow): 'active' | 'risk' | 'graduated' | 'leave' {
  if (r.attendance_rate != null && r.attendance_rate < 70) return 'risk';
  return 'active';
}

const filtered = computed(() => {
  let list = rows.value;
  if (status.value !== 'all') list = list.filter((r) => classify(r) === status.value);
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((r) => r.student_name.toLowerCase().includes(q) || r.group_name?.toLowerCase().includes(q));
  return list;
});

const counts = computed(() => ({
  all: rows.value.length,
  active: rows.value.filter((r) => classify(r) === 'active').length,
  risk: rows.value.filter((r) => classify(r) === 'risk').length,
}));

function initial(name: string): string {
  return name.trim()[0]?.toUpperCase() ?? '?';
}

function attendanceBar(rate: number | null): { width: string; color: string } {
  if (rate == null) return { width: '0%', color: 'var(--tutoring-border)' };
  return {
    width: `${rate}%`,
    color: rate >= 90 ? '#1d9e75' : rate >= 75 ? '#efaf07' : '#e24b4a',
  };
}

function goEnroll() { router.push({ name: 'admin.tutoring.enroll-any' }); }

const showCreate = ref(false);
const createForm = ref({ name: '', guardian_name: '', guardian_phone: '' });
const createBusy = ref(false);

function openCreate() {
  createForm.value = { name: '', guardian_name: '', guardian_phone: '' };
  showCreate.value = true;
}

async function submitCreate() {
  if (createForm.value.name.trim().length < 2) {
    toast.error(t('admin.bimbel.students.name_min'));
    return;
  }
  createBusy.value = true;
  try {
    await TutoringService.createStudent({
      name: createForm.value.name.trim(),
      guardian_name: createForm.value.guardian_name.trim() || null,
      guardian_phone: createForm.value.guardian_phone.trim() || null,
    });
    toast.success(t('admin.bimbel.students.create_saved'));
    showCreate.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.students.create_fail'));
  } finally { createBusy.value = false; }
}

function exportCsv() {
  const headers = [
    t('admin.bimbel.students.csv_header_name'),
    t('admin.bimbel.students.csv_header_program'),
    t('admin.bimbel.students.csv_header_package'),
    t('admin.bimbel.students.csv_header_group'),
    t('admin.bimbel.students.csv_header_mode'),
    t('admin.bimbel.students.csv_header_attended'),
    t('admin.bimbel.students.csv_header_unpaid_total'),
    t('admin.bimbel.students.csv_header_unpaid_count'),
  ];
  const csvRows = [
    headers.join(','),
    ...filtered.value.map((r) => [
      JSON.stringify(r.student_name ?? ''),
      JSON.stringify(r.program_name ?? ''),
      JSON.stringify(r.package_name ?? ''),
      JSON.stringify(r.group_name ?? ''),
      r.billing_mode,
      r.attendance_rate ?? '',
      r.unpaid_total ?? 0,
      r.unpaid_count ?? 0,
    ].join(',')),
  ];
  const blob = new Blob([csvRows.join('\n')], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `bimbel-siswa-${new Date().toISOString().slice(0, 10)}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorHomeHero
      :greeting="t('admin.bimbel.students.hero_kicker')"
      :title="t('admin.bimbel.students.hero_title')"
      :subtitle="t('admin.bimbel.students.hero_subtitle', { active: counts.active, risk: counts.risk })"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[14px] font-bold text-white hover:bg-white/25"
          @click="exportCsv"
        >
          <NavIcon name="download" :size="13" class="inline -mt-0.5" /> {{ t('admin.bimbel.students.export') }}
        </button>
        <button
          type="button"
          class="rounded-lg bg-white/15 ring-1 ring-white/20 px-3 py-1.5 text-[14px] font-bold text-white hover:bg-white/25"
          @click="openCreate"
        >
          <NavIcon name="user-plus" :size="13" class="inline -mt-0.5" /> {{ t('admin.bimbel.students.add_student') }}
        </button>
        <button
          type="button"
          class="rounded-lg bg-white text-tutoring-accent px-3 py-1.5 text-[14px] font-bold hover:opacity-90"
          @click="goEnroll"
        >
          <NavIcon name="plus" :size="13" class="inline -mt-0.5" /> {{ t('admin.bimbel.students.enroll_to_program') }}
        </button>
      </template>
    </TutorHomeHero>

    <div class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-3 flex flex-wrap items-center gap-2">
      <div class="relative min-w-[200px] flex-1">
        <NavIcon name="search" :size="14" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-tutoring-text-lo" />
        <input
          v-model="query"
          type="text"
          :placeholder="t('admin.bimbel.students.search_ph')"
          class="w-full rounded-lg border border-tutoring-border bg-tutoring-bg pl-9 pr-3 py-1.5 text-[14px] text-tutoring-text-hi placeholder:text-tutoring-text-lo focus:border-tutoring-accent focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all' as const, label: t('admin.bimbel.students.filter_all', { count: counts.all }) },
            { id: 'active' as const, label: t('admin.bimbel.students.filter_active', { count: counts.active }) },
            { id: 'risk' as const, label: t('admin.bimbel.students.filter_risk', { count: counts.risk }) },
          ]"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
          :class="status === opt.id ? 'border-tutoring-accent bg-tutoring-accent-dim text-tutoring-accent' : 'border-tutoring-border bg-tutoring-panel text-tutoring-text-mid'"
          @click="status = opt.id"
        >{{ opt.label }}</button>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-tutoring-text-mid">{{ t('admin.bimbel.students.loading') }}</div>

    <div v-else-if="filtered.length" class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel overflow-hidden">
      <table class="w-full text-[14px]">
        <thead class="bg-tutoring-bg/40">
          <tr class="text-left text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">
            <th class="px-3 py-2">{{ t('admin.bimbel.students.th_student') }}</th>
            <th class="px-3 py-2 w-[160px]">{{ t('admin.bimbel.students.th_program_pkg') }}</th>
            <th class="px-3 py-2 w-[140px]">{{ t('admin.bimbel.students.th_group') }}</th>
            <th class="px-3 py-2 w-[110px]">{{ t('admin.bimbel.students.th_unpaid') }}</th>
            <th class="px-3 py-2 w-[120px]">{{ t('admin.bimbel.students.th_attendance_30d') }}</th>
            <th class="px-3 py-2 w-[80px]">{{ t('admin.bimbel.students.th_status') }}</th>
            <th class="px-3 py-2 w-[40px]"></th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="r in filtered" :key="r.enrollment_id" class="border-t border-tutoring-border-soft hover:bg-tutoring-border-soft/30">
            <td class="px-3 py-2.5">
              <div class="flex items-center gap-2.5">
                <span class="grid h-7 w-7 place-items-center rounded-full bg-tutoring-accent-dim text-tutoring-accent text-[13px] font-bold">{{ initial(r.student_name) }}</span>
                <div>
                  <p class="font-bold text-tutoring-text-hi">{{ r.student_name }}</p>
                  <p class="text-[13px] text-tutoring-text-mid">{{ r.billing_mode }}</p>
                </div>
              </div>
            </td>
            <td class="px-3 py-2.5">
              <p class="text-tutoring-text-hi">{{ r.program_name ?? '—' }}</p>
              <p v-if="r.package_name" class="text-[13px] text-tutoring-text-mid">{{ r.package_name }}</p>
            </td>
            <td class="px-3 py-2.5 text-tutoring-text-mid">{{ r.group_name ?? '—' }}</td>
            <td class="px-3 py-2.5">
              <p v-if="r.unpaid_count === 0" class="font-bold text-emerald-700 dark:text-emerald-300">{{ t('admin.bimbel.students.status_paid') }}</p>
              <p v-else class="font-bold text-rose-700 dark:text-rose-300">{{ formatRupiah(r.unpaid_total) }}</p>
              <p v-if="r.unpaid_count > 0" class="text-[13px] text-tutoring-text-mid">{{ t('admin.bimbel.students.unpaid_count', { count: r.unpaid_count }) }}</p>
            </td>
            <td class="px-3 py-2.5">
              <div class="flex items-center gap-2">
                <span class="inline-block w-16 h-1.5 rounded-full bg-tutoring-border overflow-hidden">
                  <span class="block h-full" :style="{ width: attendanceBar(r.attendance_rate).width, background: attendanceBar(r.attendance_rate).color }" />
                </span>
                <span>{{ r.attendance_rate ?? '–' }}%</span>
              </div>
            </td>
            <td class="px-3 py-2.5">
              <span
                class="inline-flex rounded-full px-2 py-0.5 text-[13px] font-bold"
                :class="classify(r) === 'risk' ? 'bg-amber-500/15 text-amber-700 dark:text-amber-300' : 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300'"
              >{{ classify(r) === 'risk' ? t('admin.bimbel.students.status_risk') : t('admin.bimbel.students.status_active') }}</span>
            </td>
            <td class="px-3 py-2.5 text-right">
              <AdminActionMenu
                :items="[
                  { key: 'edit', label: t('admin.bimbel.students.action_edit'), icon: 'edit' },
                  { key: 'cancel', label: t('admin.bimbel.students.action_cancel'), icon: 'user-x', danger: true },
                ]"
                :aria-label="t('admin.bimbel.students.action_aria')"
                @pick="(k) => pickRow(r, k)"
              />
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-else class="rounded-2xl border border-tutoring-border-soft bg-tutoring-panel p-8 text-center text-sm text-tutoring-text-mid">
      {{ t('admin.bimbel.students.empty') }}
    </div>

    <div v-if="showCreate" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="showCreate = false">
      <div class="w-full max-w-md rounded-2xl bg-tutoring-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.students.modal_create_title') }}</h3>
        <p class="text-[13px] text-tutoring-text-mid">{{ t('admin.bimbel.students.modal_create_subtitle') }}</p>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.students.field_name') }} <span class="text-rose-500">*</span></span>
          <input v-model="createForm.name" type="text" required :placeholder="t('admin.bimbel.students.name_ph')" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.students.field_guardian') }}</span>
          <input v-model="createForm.guardian_name" type="text" :placeholder="t('admin.bimbel.students.guardian_ph')" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.students.field_guardian_phone') }}</span>
          <input v-model="createForm.guardian_phone" type="tel" :placeholder="t('admin.bimbel.students.guardian_phone_ph')" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft" @click="showCreate = false">{{ t('admin.bimbel.students.cancel') }}</button>
          <button type="button" :disabled="createBusy" class="flex-1 rounded-lg bg-tutoring-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="submitCreate">{{ createBusy ? t('admin.bimbel.students.saving') : t('admin.bimbel.students.save') }}</button>
        </div>
      </div>
    </div>

    <div v-if="editTarget" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="editTarget = null">
      <div class="w-full max-w-md rounded-2xl bg-tutoring-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-tutoring-text-hi">{{ t('admin.bimbel.students.modal_edit_title') }}</h3>
        <p class="text-[13px] text-tutoring-text-mid">{{ editTarget.program_name ?? '—' }}<template v-if="editTarget.group_name"> · {{ editTarget.group_name }}</template></p>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.students.field_name') }} <span class="text-rose-500">*</span></span>
          <input v-model="editForm.name" type="text" required class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.students.field_guardian') }}</span>
          <input v-model="editForm.guardian_name" type="text" :placeholder="t('admin.bimbel.students.guardian_keep_ph')" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-tutoring-text-mid">{{ t('admin.bimbel.students.field_guardian_phone') }}</span>
          <input v-model="editForm.guardian_phone" type="tel" :placeholder="t('admin.bimbel.students.guardian_keep_ph')" class="mt-1 w-full rounded-lg border border-tutoring-border bg-tutoring-bg px-3 py-2 text-[14px] text-tutoring-text-hi focus:border-tutoring-accent focus:outline-none" />
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-tutoring-border bg-tutoring-panel px-3 py-2 text-[14px] font-bold text-tutoring-text-hi hover:bg-tutoring-border-soft" @click="editTarget = null">{{ t('admin.bimbel.students.cancel') }}</button>
          <button type="button" :disabled="editBusy" class="flex-1 rounded-lg bg-tutoring-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="submitEdit">{{ editBusy ? t('admin.bimbel.students.saving') : t('admin.bimbel.students.save') }}</button>
        </div>
      </div>
    </div>

    <AdminConfirmDialog
      :open="!!cancelTarget"
      :title="t('admin.bimbel.students.cancel_dialog_title')"
      :message="t('admin.bimbel.students.cancel_dialog_message', { name: cancelTarget?.student_name ?? '' })"
      :confirm-label="t('admin.bimbel.students.cancel_confirm')"
      danger
      :busy="cancelBusy"
      @cancel="cancelTarget = null"
      @confirm="confirmCancel"
    />
  </div>
</template>
