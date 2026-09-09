<!--
  ParentTutoring2PickChildView.vue — Wali picks a linked child (WEB-5).

  Composition:
    1. BrandPageHeader (role="parent") — no meta line.
    2. AsyncView → rounded-3xl surface with divide-y child rows.

  MVP: no dedicated /parent/children endpoint yet; children are derived
  from unique student_id across TutoringBimbelService.listEnrollments
  (same pattern as ParentTutoring2HomeView). TODO WEB-5+ swap to a real
  /tutoring2/parent/children endpoint once BE ships it.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import { useDataRefresh } from '@/composables/useDataRefresh';
import { bimbelStudentLabel } from '@/lib/bimbel-session-label';
import {
  TutoringBimbelService,
  type BimbelEnrollment,
} from '@/services/tutoring-bimbel.service';

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

/**
 * Where picking a child leads.
 *
 * This view used to hard-code `parent.tutoring2.attendance`, which meant
 * it could only ever serve one nav entry. Every other per-child wali
 * screen is routed as `.../:studentId`, so a param-free menu item (say
 * "Voucher") had nowhere to point — the picker would silently land the
 * wali on Kehadiran instead.
 *
 * `?target=` fixes that. It is validated against an allow-list rather
 * than pushed straight into router.push: `target` arrives from the URL,
 * so an unchecked value would let a crafted link bounce a wali into any
 * named route in the app. Anything unrecognised falls back to the
 * historical destination, which also keeps existing links working.
 */
const TARGETS: Record<string, string> = {
  attendance: 'parent.tutoring2.attendance',
  vouchers: 'parent.tutoring2.vouchers',
  progress: 'parent.tutoring2.progress',
  activities: 'parent.tutoring2.activities',
  assessments: 'parent.tutoring2.assessments',
  sessions: 'parent.tutoring2.sessions',
  // Added with the sidebar repoint: the wali "Peringkat" menu item
  // routes here whenever no child is active, and an absent key would
  // have silently fallen through to `attendance` — landing the wali on
  // Kehadiran after they clicked Peringkat.
  leaderboard: 'parent.tutoring2.leaderboard',
};

const targetRouteName = computed(() => {
  const key = String(route.query.target ?? '');
  return TARGETS[key] ?? TARGETS.attendance;
});

// MVP: derive children from unique student_id in enrollments — parent
// only sees rows whose students they are linked to (backend enforces).
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({ per_page: 100 });
  return items;
});

interface ChildRow {
  student_id: string;
  /**
   * The sibling ParentTutoring2HomeView has copied this off the same
   * `listEnrollments` payload since it shipped; this screen dropped it,
   * so the two parent screens disagreed about the child's own name.
   */
  student_name?: string | null;
  active_count: number;
}

const children = computed<ChildRow[]>(() => {
  const items = (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[];
  const byStudent = new Map<string, ChildRow>();
  for (const e of items) {
    const row = byStudent.get(e.student_id) ?? {
      student_id: e.student_id,
      active_count: 0,
    };
    /**
     * Outside the `??`, so it runs on the EXISTING row too. A child's
     * enrollments are not uniform: `whenLoaded` omits `student_name`
     * per row, so the first enrollment can be nameless while the second
     * carries the name. Copying the name only when the row is created
     * would leave every child with more than one programme showing an
     * id fragment whenever their first row happened to be the unnamed
     * one — a named sibling next to an unnamed one, on the same list.
     *
     * A name already taken is never overwritten (first non-blank wins,
     * matching TutorTutoring2StudentDetailView's `find`), and the trim
     * is what makes `"   "` count as still-unnamed rather than as an
     * answer.
     */
    if (!String(row.student_name ?? '').trim()) row.student_name = e.student_name;
    if (e.status === 'active' || e.status === 'trial') row.active_count += 1;
    byStudent.set(e.student_id, row);
  }
  return [...byStudent.values()];
});

function openChild(studentId: string) {
  router.push({ name: targetRouteName.value, params: { studentId } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.pickChild.title')"
    />

    <AsyncView
      :state="state"
      loading-variant="list"
      :loading-rows="3"
      :empty-title="t('tutoring2.parent.pickChild.emptyTitle')"
      :empty-description="t('tutoring2.parent.pickChild.emptyDesc')"
      @retry="reload"
    >
      <template #default>
        <div class="rounded-3xl border border-slate-100 bg-white shadow-sm">
          <ul class="divide-y divide-slate-100">
            <li
              v-for="c in children"
              :key="c.student_id"
              class="flex cursor-pointer items-center gap-3 px-4 py-3 hover:bg-slate-50"
              @click="openChild(c.student_id)"
            >
              <div class="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-brand-azure/10 text-xs font-bold uppercase text-brand-azure">
                {{ bimbelStudentLabel(c).slice(0, 2).toUpperCase() }}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-sm font-bold text-slate-900">
                  {{ bimbelStudentLabel(c, t('tutoring2.common.studentId')) }}
                </p>
                <p class="truncate text-2xs text-slate-500">
                  {{ t('tutoring2.common.metaActiveEnrolls', { count: c.active_count }) }}
                </p>
              </div>
              <span class="text-slate-300">›</span>
            </li>
          </ul>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
