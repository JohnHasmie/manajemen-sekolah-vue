<!--
  Tutoring2StudentScoresView.vue — the STAFF drill-in from a Peringkat
  row into one student's graded-score history.

  Routes:
    /admin/tutoring2/students/:studentId/scores     (admin)
    /teacher/tutoring2/students/:studentId/scores   (tutor)

  Endpoint: GET /tutoring-v2/students/{id}/progress — ONE call, made by
  <Tutoring2StudentScores>, which is the same body the wali screen
  renders. This file is a thin wrapper: it owns only the header, because
  a staff reader arriving from a board of many students needs to know
  WHOSE marks they are reading.

  ── Why two routes and one view ──

  The rendering is identical for both; only `meta.role` differs, and
  that is read below to tint the header. Splitting it into an admin file
  and a tutor file would be two copies of a wrapper — the exact drift
  this whole change exists to avoid.

  ── Who may open it ──

  Both routes carry `ability: 'tutoring.score.view'`, and the entry
  points on the two boards are gated on the same key. That is a
  convenience, not the boundary: `StudentProgressController::
  authorizeStudentRead` re-checks on every request and narrows a TUTOR
  to students enrolled in the groups they teach (`tutorTeachesStudent`
  in `ResolvesTutoringReadScope`), so a tutor who hand-types another
  tutor's student id gets a 403, not a payload.

  That server-side narrowing is also why the tutor entry point is safe
  to offer at all. The tutor board is group-scoped, and
  `LearningGroupController::index` narrows the group picker to the
  caller's own groups, so every row a tutor can see belongs to a student
  that same tutor teaches — the set the endpoint authorises is exactly
  the set the board can offer. (The programme-wide board, which spans
  other tutors' groups, was removed from the tutor screen in dab8dec1
  for that very reason and is deliberately not reintroduced here.)

  ── Why the name comes off the URL ──

  Because there is no endpoint that would give it to a tutor.
  `GET /tutoring-v2/students/{id}` authorizes `tutoring.student.view`,
  which `PermissionCatalog::tutorTutoringDefaults()` does NOT grant — a
  tutor calling it gets a 403. The boards already render the name the
  moment before the click, so it is handed over in `?name=`, the same
  convention `ParentDashboardView` uses for a child's name.

  A pasted or bookmarked link with no `?name=` therefore cannot resolve
  one. It renders an explicit "Tanpa nama" rather than an empty gradient
  — the SCORES are still correct and still authorised; it is only the
  label that is unknown, and saying so is better than implying the page
  failed.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Tutoring2StudentScores from '@/components/tutoring2/Tutoring2StudentScores.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import type { Role } from '@/types/auth';

const { t } = useI18n();
const route = useRoute();

const studentId = computed(() => String(route.params.studentId ?? ''));

/** The board's own label for this student, or an honest placeholder. */
const studentName = computed(() => {
  const raw = route.query.name;
  const name = (Array.isArray(raw) ? raw[0] : raw) ?? '';
  return String(name).trim() || t('tutoring2.studentScores.titleFallback');
});

/** Tints the header to whichever staff surface we arrived from. */
const role = computed<Role>(() => (route.meta.role as Role) ?? 'admin');
</script>

<template>
  <Tutoring2StudentScores
    :student-id="studentId"
    :legend-subject-label="t('tutoring2.studentScores.legendStudent')"
  >
    <template #header="{ count, loading }">
      <BrandPageHeader
        :role="role"
        :kicker="t('tutoring2.studentScores.kicker')"
        :title="studentName"
        :meta="
          loading
            ? t('tutoring2.common.loading')
            : t('tutoring2.studentScores.meta', { count })
        "
      />
    </template>
  </Tutoring2StudentScores>
</template>
