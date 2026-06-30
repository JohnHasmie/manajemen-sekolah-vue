<!--
  PersonnelCardManagerView.vue — admin batch-issue + revoke + PDF export
  for personnel QR cards. The source of truth for who's a personnel is
  the existing teacher list (`TeacherService.list`); students are out of
  scope by default (toggled via the settings page's "Cetak kartu siswa"
  flag, which the issue endpoint enforces server-side). This page only
  needs the teacher list — the cards table itself lives on the row, not
  on a separate listing endpoint (the backend exposes issue/revoke and
  the row's status comes back inline).

  TODO(future MR): when a dedicated `/attendance/personnel-cards/list`
  endpoint lands, fetch it alongside the teacher list so we can show
  "card issued at" / "qr_token preview" / "revoked_at" columns. For now
  the page surfaces the action verbs and trusts the toast feedback on
  each call to report status.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TeacherService } from '@/services/teachers.service';
import { AttendanceQrService } from '@/services/attendance-qr.service';
import { useToast } from '@/composables/useToast';
import type { Teacher } from '@/types/entities';
import type { PersonnelCardIssueResult } from '@/types/attendance-qr';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import EmptyState from '@/components/data/EmptyState.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

const loading = ref(true);
const teachers = ref<Teacher[]>([]);
/** Set of selected user_id values (NOT teacher_id — the backend keys by user). */
const selected = ref<Set<string>>(new Set());
/** Free-text search box over name + employee number. */
const searchQuery = ref('');
/** Role filter — Teacher.role is the FE role string (guru / wali_kelas). */
const roleFilter = ref<'all' | 'guru' | 'wali_kelas'>('all');
const issuing = ref(false);
const exporting = ref(false);
/** Per-row revoke spinner state, keyed by user_id. */
const revoking = ref<Set<string>>(new Set());

async function load() {
  loading.value = true;
  try {
    // The Teacher list endpoint also doubles as the personnel listing
    // (students aren't issued cards by default — see the settings
    // `issue_student_cards` flag). show_all=true bypasses pagination so
    // the user can batch-select across the full roster.
    const res = await TeacherService.list({ show_all: true, per_page: 500 });
    teachers.value = res.items;
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.loadFail'),
    );
  } finally {
    loading.value = false;
  }
}

/** Roster filtered by the search box + role filter. */
const filteredTeachers = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  return teachers.value.filter((tt) => {
    if (roleFilter.value !== 'all' && tt.role !== roleFilter.value) {
      return false;
    }
    if (q === '') return true;
    return (
      tt.name.toLowerCase().includes(q) ||
      (tt.employee_number ?? '').toLowerCase().includes(q) ||
      tt.email.toLowerCase().includes(q)
    );
  });
});

/** Effective user-id picker — falls back to teacher id when user_id is null. */
function userIdOf(tt: Teacher): string {
  return tt.user_id ?? tt.id;
}

function toggleRow(tt: Teacher) {
  const uid = userIdOf(tt);
  const next = new Set(selected.value);
  if (next.has(uid)) next.delete(uid);
  else next.add(uid);
  selected.value = next;
}

function toggleAllFiltered() {
  const next = new Set(selected.value);
  const allSelected = filteredTeachers.value.every((tt) =>
    next.has(userIdOf(tt)),
  );
  for (const tt of filteredTeachers.value) {
    const uid = userIdOf(tt);
    if (allSelected) next.delete(uid);
    else next.add(uid);
  }
  selected.value = next;
}

const selectedCount = computed(() => selected.value.size);
const allFilteredSelected = computed(
  () =>
    filteredTeachers.value.length > 0 &&
    filteredTeachers.value.every((tt) => selected.value.has(userIdOf(tt))),
);

/**
 * Build a human summary of an issue-response so the toast tells the
 * admin how many cards landed vs were skipped. The backend may return
 * `reason` strings; we surface up to two so a small batch doesn't lose
 * its feedback in an ellipsis.
 */
function summariseResults(rows: PersonnelCardIssueResult[]): string {
  const ok = rows.filter((r) => r.status === 'ok').length;
  const skipped = rows.filter((r) => r.status === 'skipped');
  const errored = rows.filter((r) => r.status === 'error');
  const parts: string[] = [t('admin.attendance.cards.issued', { count: ok })];
  if (skipped.length > 0) {
    parts.push(t('admin.attendance.cards.skipped', { count: skipped.length }));
  }
  if (errored.length > 0) {
    parts.push(t('admin.attendance.cards.errored', { count: errored.length }));
  }
  return parts.join(' · ');
}

async function issueSelected() {
  if (selected.value.size === 0) return;
  issuing.value = true;
  try {
    const ids = Array.from(selected.value);
    const rows = await AttendanceQrService.issuePersonnelCards(ids);
    toast.success(summariseResults(rows));
    selected.value = new Set();
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.issueFail'),
    );
  } finally {
    issuing.value = false;
  }
}

async function exportSelectedPdf() {
  if (selected.value.size === 0) return;
  exporting.value = true;
  try {
    const ids = Array.from(selected.value);
    const ts = new Date().toISOString().slice(0, 10);
    await AttendanceQrService.exportPersonnelCardsPdf(
      ids,
      `kartu-qr-personel-${ts}.pdf`,
    );
    toast.success(t('admin.attendance.cards.exported'));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.exportFail'),
    );
  } finally {
    exporting.value = false;
  }
}

/**
 * Single-row revoke. Because the listing API surfaces *teachers*, not
 * card rows, we pass the teacher's id through as the `cardId` — the
 * backend resolves to the active card for the user. If a more granular
 * cardId is needed later (e.g. revoke a specific historical card), this
 * is the place to swap in the dedicated card list lookup.
 *
 * TODO(future MR): once the cards-list endpoint lands, key revoke by
 * the card row's id instead of the user id; show "Belum diterbitkan"
 * pill for users without a current card.
 */
async function revokeRow(tt: Teacher) {
  const uid = userIdOf(tt);
  if (revoking.value.has(uid)) return;
  const next = new Set(revoking.value);
  next.add(uid);
  revoking.value = next;
  try {
    await AttendanceQrService.revokePersonnelCard(uid);
    toast.success(t('admin.attendance.cards.revoked', { name: tt.name }));
  } catch (e) {
    toast.error(
      e instanceof Error ? e.message : t('admin.attendance.cards.revokeFail'),
    );
  } finally {
    const after = new Set(revoking.value);
    after.delete(uid);
    revoking.value = after;
  }
}

onMounted(load);
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      :kicker="t('admin.attendance.cards.kicker')"
      :title="t('admin.attendance.cards.title')"
      :meta="t('admin.attendance.cards.meta')"
    >
      <div class="flex flex-wrap items-center gap-2">
        <Button
          variant="secondary"
          size="md"
          :disabled="selectedCount === 0 || exporting"
          :loading="exporting"
          @click="exportSelectedPdf"
        >
          <NavIcon name="download" :size="16" />
          {{ t('admin.attendance.cards.exportPdf') }}
        </Button>
        <Button
          variant="primary"
          size="md"
          :disabled="selectedCount === 0 || issuing"
          :loading="issuing"
          @click="issueSelected"
        >
          <NavIcon name="id-card" :size="16" />
          {{ t('admin.attendance.cards.issue', { count: selectedCount }) }}
        </Button>
      </div>
    </BrandPageHeader>

    <!-- Filter row: search + role dropdown.  Sits above the table so
         the user filters before bulk-selecting; the master checkbox
         operates on the filtered slice. -->
    <div class="flex flex-wrap items-center gap-2">
      <div class="relative flex-1 min-w-[220px]">
        <input
          v-model="searchQuery"
          type="search"
          :placeholder="t('admin.attendance.cards.searchPh')"
          class="w-full rounded-xl border border-slate-200 bg-white pl-9 pr-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/30 focus:border-role-admin"
        />
        <NavIcon
          name="search"
          :size="14"
          class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400"
        />
      </div>
      <select
        v-model="roleFilter"
        class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-admin/30 focus:border-role-admin"
      >
        <option value="all">{{ t('admin.attendance.cards.roleAll') }}</option>
        <option value="guru">{{ t('admin.attendance.cards.roleGuru') }}</option>
        <option value="wali_kelas">{{
          t('admin.attendance.cards.roleWaliKelas')
        }}</option>
      </select>
    </div>

    <!-- Loading shell. -->
    <div
      v-if="loading"
      class="flex items-center justify-center py-16 text-slate-500"
    >
      <Spinner size="md" />
      <span class="ml-2 text-sm">{{ t('common.loading') }}</span>
    </div>

    <EmptyState
      v-else-if="filteredTeachers.length === 0"
      :title="t('admin.attendance.cards.empty')"
      :description="t('admin.attendance.cards.emptyHint')"
    />

    <div
      v-else
      class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
    >
      <table class="w-full text-sm">
        <thead class="bg-slate-50 text-xs uppercase tracking-wider text-slate-500">
          <tr>
            <th class="px-3 py-2.5 text-left w-10">
              <input
                type="checkbox"
                :checked="allFilteredSelected"
                class="h-4 w-4 rounded text-role-admin accent-role-admin"
                :aria-label="t('admin.attendance.cards.selectAll')"
                @change="toggleAllFiltered"
              />
            </th>
            <th class="px-3 py-2.5 text-left font-semibold">
              {{ t('admin.attendance.cards.colName') }}
            </th>
            <th class="px-3 py-2.5 text-left font-semibold">
              {{ t('admin.attendance.cards.colRole') }}
            </th>
            <th class="px-3 py-2.5 text-left font-semibold">
              {{ t('admin.attendance.cards.colEmployeeNumber') }}
            </th>
            <th class="px-3 py-2.5 text-right font-semibold w-32">
              {{ t('admin.attendance.cards.colActions') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="tt in filteredTeachers"
            :key="tt.id"
            class="border-t border-slate-100 hover:bg-slate-50 cursor-pointer"
            @click="toggleRow(tt)"
          >
            <td class="px-3 py-2.5" @click.stop>
              <input
                type="checkbox"
                :checked="selected.has(userIdOf(tt))"
                class="h-4 w-4 rounded text-role-admin accent-role-admin"
                :aria-label="t('admin.attendance.cards.selectRow')"
                @change="toggleRow(tt)"
              />
            </td>
            <td class="px-3 py-2.5">
              <div class="font-semibold text-slate-900">{{ tt.name }}</div>
              <div class="text-xs text-slate-500">{{ tt.email }}</div>
            </td>
            <td class="px-3 py-2.5 text-slate-600">
              {{
                tt.role === 'wali_kelas'
                  ? t('admin.attendance.cards.roleWaliKelas')
                  : t('admin.attendance.cards.roleGuru')
              }}
            </td>
            <td class="px-3 py-2.5 text-slate-600">
              {{ tt.employee_number ?? '–' }}
            </td>
            <td class="px-3 py-2.5 text-right" @click.stop>
              <button
                type="button"
                class="text-xs font-semibold text-status-danger hover:underline disabled:opacity-50"
                :disabled="revoking.has(userIdOf(tt))"
                @click="revokeRow(tt)"
              >
                <span v-if="revoking.has(userIdOf(tt))" class="inline-flex items-center gap-1">
                  <Spinner size="sm" />
                  {{ t('admin.attendance.cards.revoking') }}
                </span>
                <span v-else>{{ t('admin.attendance.cards.revoke') }}</span>
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
