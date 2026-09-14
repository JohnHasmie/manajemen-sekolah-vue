<!--
  ParentSwitchChildLink.vue — "‹nama anak› · Ganti anak" under the title
  of a per-child wali bimbel screen.

  ── The gap this closes ──

  A wali with two children read Kehadiran, saw one child, read another
  screen, saw a different one, and concluded the DATA was wrong. It is
  not: every `parent/tutoring2/*` screen with `:studentId` in its path is
  scoped to exactly one child by design. The real defect was that once
  you were on one of those screens there was NO WAY BACK to the child
  list — the picker is reachable from the sidebar only when no child is
  active — so "this page is about one child" never read as a choice.

  This is the lighter of the two affordances that were on the table. The
  heavier one, `ParentChildPickerChip` (an avatar chip with an inline
  dropdown, which the school parent surface uses), is deliberately NOT
  wired up here.

  ── Three conditions, all load-bearing ──

  1. `:studentId` must be on the route. This is what keeps the link off
     screens that are not per-child, and it is a property of the ROUTE
     rather than a list of view names, so it cannot fall out of date.
     It is also what keeps the link off `/student/tutoring2/leaderboard`
     — the siswa half of a view the wali shares — without that view
     needing to know this component exists.

  2. The wali must have MORE THAN ONE child. A single-child wali would
     otherwise get a control whose destination is a one-item list. See
     `useBimbelChildren`.

  3. The child's name is read from the SAME children list, not from the
     host page. Most of these headers render a count in their meta line
     ("214 kehadiran tercatat"), not a name, so asking each page for one
     would have meant either eight new props or a name on only two
     screens. Reading it here is what makes the pairing read as
     "Egi Cahyani Hidayat · Ganti anak" on every one of them.

  ── Coming back to the same page ──

  The picker accepts `?target=`, validated against an allow-list, and
  routes the chosen child to that screen. `parentTutoring2TargetKey`
  turns the CURRENT route name back into its key, so switching child on
  Nilai returns to Nilai for the new child rather than dumping the wali
  on Kehadiran. When the route is not in the allow-list the query is
  omitted rather than guessed — see the docblock on that helper.
-->
<script setup lang="ts">
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { useBimbelChildren } from '@/composables/useBimbelChildren';
import { bimbelStudentLabel } from '@/lib/bimbel-session-label';
import { parentTutoring2TargetKey } from '@/router/parent-tutoring2-targets';

const { t } = useI18n();
const route = useRoute();
const { children, hasMultipleChildren, ensureLoaded } = useBimbelChildren();

const studentId = computed(() => String(route.params.studentId ?? ''));

onMounted(() => {
  // Condition 1 gates the REQUEST too, not just the render: without it
  // the siswa leaderboard would fire a wali-scoped enrollment index on
  // every mount and swallow the 403.
  if (studentId.value) void ensureLoaded();
});

const visible = computed(
  () => Boolean(studentId.value) && hasMultipleChildren.value,
);

const childLabel = computed(() => {
  const row = children.value.find((c) => c.student_id === studentId.value);
  // No row means the id in the URL is not one of this wali's children —
  // show the link without a name rather than an id fragment for a child
  // we cannot identify.
  return row ? bimbelStudentLabel(row) : '';
});

const pickerTo = computed(() => {
  const target = parentTutoring2TargetKey(String(route.name ?? ''));
  return {
    name: 'parent.tutoring2.pick-child',
    ...(target ? { query: { target } } : {}),
  };
});
</script>

<template>
  <!--
    Sits inside BrandPageHeader's gradient, so the palette is white-on-
    tint like the kicker and meta line rather than the slate used on the
    body surfaces below.
  -->
  <p
    v-if="visible"
    class="mt-1 flex flex-wrap items-baseline gap-x-1.5 text-[12px] text-white/85"
    data-testid="parent-switch-child"
  >
    <span v-if="childLabel" class="font-semibold text-white">
      {{ childLabel }}
    </span>
    <span v-if="childLabel" aria-hidden="true">·</span>
    <router-link
      :to="pickerTo"
      class="rounded-sm underline decoration-white/40 underline-offset-2 transition-colors hover:text-white hover:decoration-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/70"
    >
      {{ t('tutoring2.parent.switchChild.action') }}
    </router-link>
  </p>
</template>
