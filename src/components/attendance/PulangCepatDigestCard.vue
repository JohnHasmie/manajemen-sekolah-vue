<!--
  PulangCepatDigestCard.vue — collapsible "Guru Sering Pulang Cepat"
  section for the admin Rekap tab (Pulang parity FU-1, backend
  !512 GET /teacher-attendance/report/pulang-cepat-summary).

  Renders inside the existing Rekap-per-Pegawai section on
  AdminTeacherAttendanceView, defaulting to COLLAPSED so the digest
  never pushes the primary rekap table below the fold. Expanding lazily
  fetches once and caches; parent-driven filter changes reset the cache
  so the section stays consistent with the surrounding period picker.

  Where it fits in the pulang-parity flow:
    · Admin picks `early_leave_policy = warn` from the config panel and
      wants to know WHO to escalate (or coach) → this list.
    · Also useful on `none` / `block` schools — the section works
      regardless of policy, the eyebrow just changes label. The `warn`
      case is the headline use.
    · Clicking a row opens the existing EmployeeAttendanceDeepDiveDrawer
      via an emit, so the admin can dig into the person's history without
      a page navigation.

  What this component owns:
    · Local expand/collapse state (defaults collapsed).
    · Fetch orchestration for the digest (loading / error / retry).
    · Row rendering with a coloured ratio bar (red ≥50%, amber 20-49%,
      green <20%) — matches the pulang-cepat truth table from the
      Presensi Guru wireframes.
    · Empty-state copy in the caller's active locale.

  What the CALLER owns:
    · Date-range + personnel-type filters (passed as props). Changing
      any of them triggers a re-fetch — the section stays in lock-step
      with the surrounding Rekap tab.
    · The click-through action — this component emits `open-person`
      with the digest row so the parent can open its own drawer without
      the digest knowing about drawer state.

  Not in this MR:
    · avg_minutes_early is null on every row today (backend follow-up).
      The row renders "-" in the number slot and shows a small pending
      tooltip in dev builds; a future backend deploy populates the field
      and the same row lights up with no FE change.
    · Scheduled push/email digest — separate feature decision.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import EntityRow from '@/components/feature/EntityRow.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import type {
  TeacherAttendanceEarlyLeavePolicy,
  TeacherAttendancePersonnelFilter,
  TeacherAttendancePulangCepatRow,
  TeacherAttendancePulangCepatSummary,
} from '@/types/teacher-attendance';

const props = defineProps<{
  /**
   * YYYY-MM-DD date bounds — echoed from the surrounding Rekap tab's
   * date-picker so the digest stays in lock-step with the primary
   * rekap. Both dates are required by the backend but rendered as
   * optional here so a parent that hasn't fetched yet can pass undefined
   * without a runtime crash — the section short-circuits into the
   * "waiting" branch instead.
   */
  startDate?: string;
  endDate?: string;
  /** Same personnel narrowing as the surrounding rekap. */
  personnelType?: TeacherAttendancePersonnelFilter;
  /**
   * Optional: force the section OPEN on mount. The default (false) keeps
   * it collapsed under the Rekap tab so the primary table stays above
   * the fold on typical viewports.
   */
  initiallyOpen?: boolean;
}>();

const emit = defineEmits<{
  /** Row click — parent opens the shared EmployeeAttendanceDeepDiveDrawer. */
  'open-person': [TeacherAttendancePulangCepatRow];
}>();

const { t, locale } = useI18n();

// ─────────────────────────────────────────────────────────────────
// Expand/collapse — defaults collapsed. Once expanded, we lazy-fetch
// on the first expansion and re-fetch on parent filter changes; the
// primary rekap already paid the initial cost, no reason to pre-warm
// the digest until the admin asks for it.
// ─────────────────────────────────────────────────────────────────
const isOpen = ref<boolean>(props.initiallyOpen ?? false);

function toggle() {
  isOpen.value = !isOpen.value;
  if (isOpen.value) load();
}

// ─────────────────────────────────────────────────────────────────
// Fetch
// ─────────────────────────────────────────────────────────────────
const summary = ref<TeacherAttendancePulangCepatSummary | null>(null);
const loading = ref(false);
const err = ref<string | null>(null);

/** True when the parent hasn't finished resolving its date range. */
const missingRange = computed(
  () => !props.startDate || !props.endDate,
);

async function load() {
  // Never fire without both bounds — the backend requires them and would
  // 422. Also cheap-out when the section is collapsed: no wasted request.
  if (missingRange.value) return;
  if (!isOpen.value) return;
  loading.value = true;
  err.value = null;
  try {
    summary.value = await TeacherAttendanceService.getPulangCepatSummary({
      start_date: props.startDate!,
      end_date: props.endDate!,
      personnel_type: props.personnelType ?? 'all',
    });
  } catch (e) {
    err.value = (e as Error).message || t('admin.sekolah.teacher_attendance.pulang_cepat_error_retry');
  } finally {
    loading.value = false;
  }
}

// Re-fetch when the filters shift under us — only when the section is
// open. When closed we clear the cache so the next expand hits a fresh
// backend response for the (possibly-new) filter combination.
watch(
  () => [props.startDate, props.endDate, props.personnelType],
  () => {
    if (!isOpen.value) {
      summary.value = null;
      return;
    }
    load();
  },
);

// ─────────────────────────────────────────────────────────────────
// Derived: rows + state for AsyncView
// ─────────────────────────────────────────────────────────────────
const rows = computed<TeacherAttendancePulangCepatRow[]>(
  () => summary.value?.data ?? [],
);
const meta = computed(() => summary.value?.meta ?? null);

const state = computed<AsyncState<TeacherAttendancePulangCepatRow[]>>(() => {
  if (missingRange.value) return { status: 'empty' };
  if (loading.value && rows.value.length === 0) return { status: 'loading' };
  if (err.value) return { status: 'error', error: err.value };
  if (rows.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: rows.value };
});

// ─────────────────────────────────────────────────────────────────
// Labels — all locale-aware via useI18n so the switch to en.json /
// id.json is instant. Period label uses the same locale-aware date
// helpers as the surrounding view.
// ─────────────────────────────────────────────────────────────────
const periodLabel = computed(() => {
  if (!props.startDate || !props.endDate) return '';
  return `${fmtDate(props.startDate)} – ${fmtDate(props.endDate)}`;
});

/** Localised label for the current school policy — powers the eyebrow. */
function policyLabel(policy: TeacherAttendanceEarlyLeavePolicy): string {
  if (policy === 'warn')
    return t('admin.sekolah.teacher_attendance.pulang_cepat_policy_warn');
  if (policy === 'block')
    return t('admin.sekolah.teacher_attendance.pulang_cepat_policy_block');
  return t('admin.sekolah.teacher_attendance.pulang_cepat_policy_none');
}

const eyebrowText = computed(() => {
  if (!meta.value) return '';
  return t('admin.sekolah.teacher_attendance.pulang_cepat_policy_eyebrow', {
    policy: policyLabel(meta.value.school_policy),
  });
});

const headerSubtitle = computed(() => {
  if (rows.value.length === 0 || !periodLabel.value) return '';
  return t('admin.sekolah.teacher_attendance.pulang_cepat_section_subtitle', {
    count: rows.value.length,
    period: periodLabel.value,
  });
});

/** Tone-colour tag for the ratio pill — matches the wireframe legend. */
function ratioTone(ratio: number): 'hi' | 'mid' | 'lo' {
  if (ratio >= 0.5) return 'hi';
  if (ratio >= 0.2) return 'mid';
  return 'lo';
}
function ratioBarClass(ratio: number): string {
  const tone = ratioTone(ratio);
  if (tone === 'hi') return 'bg-red-500';
  if (tone === 'mid') return 'bg-amber-500';
  return 'bg-emerald-500';
}
function ratioChipClass(ratio: number): string {
  const tone = ratioTone(ratio);
  if (tone === 'hi') return 'bg-red-100 text-red-700';
  if (tone === 'mid') return 'bg-amber-100 text-amber-700';
  return 'bg-emerald-100 text-emerald-700';
}
function ratioLabel(ratio: number): string {
  const tone = ratioTone(ratio);
  if (tone === 'hi')
    return t('admin.sekolah.teacher_attendance.pulang_cepat_ratio_hi');
  if (tone === 'mid')
    return t('admin.sekolah.teacher_attendance.pulang_cepat_ratio_mid');
  return t('admin.sekolah.teacher_attendance.pulang_cepat_ratio_lo');
}
function ratioPct(ratio: number): number {
  return Math.round(Math.max(0, Math.min(1, ratio)) * 100);
}

/** YYYY-MM-DD → localised long-form date. Falls back to the raw string. */
function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '-';
  try {
    const d = new Date(iso);
    if (!Number.isFinite(d.getTime())) return iso;
    // Locale-aware — id.json uses id-ID, en.json uses en-US. Falls back to
    // the current i18n locale for anything else in the future.
    const bcp47 = locale.value === 'en' ? 'en-US' : 'id-ID';
    return d.toLocaleDateString(bcp47, {
      day: 'numeric',
      month: 'short',
      year: 'numeric',
    });
  } catch {
    return iso;
  }
}

function subtitleFor(row: TeacherAttendancePulangCepatRow): string {
  // Prefer subject/role (contextual to the person); fall back to the NIP
  // (teachers) or a generic personnel-type label so the row never renders
  // with a blank subtitle line.
  if (row.subject_or_role) return row.subject_or_role;
  if (row.employee_number) return `NIP ${row.employee_number}`;
  return row.personnel_type === 'staff' ? 'Staf' : 'Guru';
}

// Refresh once on mount only if we opened straight into expanded state
// (initiallyOpen). Otherwise wait for the user to click.
if (isOpen.value) load();
</script>

<template>
  <section
    class="bg-white border border-slate-200 rounded-2xl overflow-hidden"
    data-testid="pulang-cepat-digest-card"
  >
    <!-- Header — click to toggle. Aria-expanded reflects the state so
         screen readers announce the collapse correctly. -->
    <button
      type="button"
      class="w-full flex items-center gap-3 px-4 py-3 text-left hover:bg-slate-50 transition-colors"
      :aria-expanded="isOpen"
      aria-controls="pulang-cepat-digest-body"
      @click="toggle"
    >
      <div
        class="w-8 h-8 rounded-lg bg-red-50 text-red-600 flex items-center justify-center flex-shrink-0"
        aria-hidden="true"
      >
        <NavIcon name="clock" :size="16" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-baseline gap-2 flex-wrap">
          <span class="text-[13px] font-bold text-slate-800">
            {{ t('admin.sekolah.teacher_attendance.pulang_cepat_section_title') }}
          </span>
          <span
            v-if="meta"
            class="text-3xs uppercase tracking-widest font-bold text-slate-400"
          >
            {{ eyebrowText }}
          </span>
        </div>
        <div v-if="headerSubtitle" class="text-2xs text-slate-500 mt-0.5">
          {{ headerSubtitle }}
        </div>
      </div>
      <span class="text-slate-400" aria-hidden="true">
        <NavIcon
          :name="isOpen ? 'chevron-up' : 'chevron-down'"
          :size="14"
        />
      </span>
      <span class="sr-only">
        {{
          isOpen
            ? t('admin.sekolah.teacher_attendance.pulang_cepat_section_collapse')
            : t('admin.sekolah.teacher_attendance.pulang_cepat_section_expand')
        }}
      </span>
    </button>

    <!-- Body — mount only while expanded to keep the DOM light on tenants
         with no early-leavers who never expand the section. -->
    <div
      v-if="isOpen"
      id="pulang-cepat-digest-body"
      class="border-t border-slate-100"
    >
      <AsyncView
        :state="state"
        :empty-title="t('admin.sekolah.teacher_attendance.pulang_cepat_section_title')"
        :empty-description="t('admin.sekolah.teacher_attendance.pulang_cepat_empty')"
        @retry="load"
      >
        <template #default>
          <ul class="divide-y divide-slate-100">
            <li v-for="row in rows" :key="row.person_id">
              <EntityRow
                :avatar="{ name: row.display_name, size: 40 }"
                :title="row.display_name"
                :subtitle="subtitleFor(row)"
                chevron
                @click="emit('open-person', row)"
              >
                <template #trailing>
                  <div class="flex items-center gap-3 min-w-0">
                    <!-- Ratio bar — width mirrors ratio 0..1, tone follows
                         the wire threshold (red ≥50%, amber 20-49%, green
                         <20%). Numeric strip on the right stays legible on
                         narrow rows because the bar shrinks first. -->
                    <div
                      class="hidden md:flex items-center gap-2 w-44"
                      :aria-label="`${ratioLabel(row.ratio)} — ${row.early_leave_count} / ${row.workday_count}`"
                    >
                      <div class="flex-1 h-1.5 rounded-full bg-slate-100 overflow-hidden">
                        <div
                          class="h-full rounded-full"
                          :class="ratioBarClass(row.ratio)"
                          :style="{ width: `${ratioPct(row.ratio)}%` }"
                        />
                      </div>
                      <span
                        class="text-2xs font-bold px-1.5 py-0.5 rounded-full tabular-nums"
                        :class="ratioChipClass(row.ratio)"
                      >
                        {{ ratioPct(row.ratio) }}%
                      </span>
                    </div>
                    <!-- Numeric strip — count + avg minutes early + last date -->
                    <div class="flex flex-col items-end gap-0.5 text-2xs tabular-nums min-w-0">
                      <span class="text-slate-700 font-bold">
                        {{
                          t(
                            'admin.sekolah.teacher_attendance.pulang_cepat_count_line',
                            {
                              count: row.early_leave_count,
                              total: row.workday_count,
                            },
                          )
                        }}
                      </span>
                      <span
                        v-if="row.avg_minutes_early !== null"
                        class="text-slate-500"
                      >
                        {{
                          t(
                            'admin.sekolah.teacher_attendance.pulang_cepat_avg_line',
                            { min: row.avg_minutes_early },
                          )
                        }}
                      </span>
                      <span
                        v-else
                        class="text-slate-400 italic"
                        :title="t('admin.sekolah.teacher_attendance.pulang_cepat_avg_pending')"
                      >
                        -
                      </span>
                      <span class="text-3xs text-slate-400">
                        {{
                          t(
                            'admin.sekolah.teacher_attendance.pulang_cepat_last_line',
                            { date: fmtDate(row.last_early_leave_date) },
                          )
                        }}
                      </span>
                    </div>
                  </div>
                </template>
              </EntityRow>
            </li>
          </ul>
        </template>
      </AsyncView>
    </div>
  </section>
</template>
