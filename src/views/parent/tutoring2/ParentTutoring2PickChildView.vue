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
import {
  deriveBimbelChildren,
  type BimbelChildRow,
} from '@/lib/bimbel-parent-children';
import { bimbelStudentLabel } from '@/lib/bimbel-session-label';
import { resolveParentTutoring2Target } from '@/router/parent-tutoring2-targets';
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
 *
 * The table itself moved to `@/router/parent-tutoring2-targets` when the
 * "Ganti anak" link shipped: that link needs the SAME pairs read in
 * reverse (route name → `?target=`) so switching child returns the wali
 * to the screen they were on. Two copies would eventually disagree.
 */
const targetRouteName = computed(() =>
  resolveParentTutoring2Target(route.query.target),
);

// MVP: derive children from unique student_id in enrollments — parent
// only sees rows whose students they are linked to (backend enforces).
const { state, reload } = useDataRefresh(async () => {
  const { items } = await TutoringBimbelService.listEnrollments({ per_page: 100 });
  return items;
});

/**
 * `deriveBimbelChildren` is shared with `useBimbelChildren`, which is
 * what decides whether the "Ganti anak" link appears on the per-child
 * screens. The link must only show when this list has more than one row,
 * so the count and the list have to come from one derivation — a second
 * copy could offer a switcher that opens a one-item picker.
 *
 * It also carries `student_name`, which the sibling
 * ParentTutoring2HomeView has copied off the same `listEnrollments`
 * payload since it shipped; this screen dropped it, so the two parent
 * screens disagreed about the child's own name.
 */
const children = computed<BimbelChildRow[]>(() =>
  deriveBimbelChildren(
    (state.value.status === 'content' ? state.value.data : []) as BimbelEnrollment[],
  ),
);

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
