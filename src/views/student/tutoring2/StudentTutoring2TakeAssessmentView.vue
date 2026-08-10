<!--
  StudentTutoring2TakeAssessmentView.vue — the online assessment runner.

  Route: /student/tutoring2/assessments/:id/take

  ── Why this screen no longer runs an assessment ──

  It used to serve TEN FABRICATED QUESTIONS from a local
  `sampleQuestions` array, collect the student's answers into a
  `Record<index, option>` map, and on "Kumpulkan" do this:

      function submit() {
        toast...
        router.push({ name: 'student.tutoring2.result', ... });
      }

  Nothing was ever sent. A student could sit what looked like a real
  exam, submit it, and land on a results page — with their answers
  discarded and the questions not belonging to their assessment in the
  first place.

  This was not a wiring oversight. There is NO question or attempt
  endpoint anywhere in `Route::prefix('tutoring-v2')` — checked against
  the group's real bounds, not by grepping a path that also exists in the
  legacy group. Online assessments are an unbuilt feature, not a
  disconnected one, so there was nothing to wire it to.

  Bimbel assessments are sat on paper today. Marks reach the app through
  the tutor's score entry, which is why the siswa can see a real result
  for an assessment the app could never have collected.

  The route is kept rather than deleted so an existing link, bookmark or
  push notification lands on an explanation instead of a 404. The entry
  point in StudentTutoring2AssessmentsView is gone.

  TO REVIVE THIS SCREEN you need, at minimum: question storage, an
  attempt/answer endpoint, and a submission that is idempotent under a
  double-tap on a flaky phone connection. Bring back the runner in the
  same MR as that backend — a half-wired version of this screen is worse
  than none, because it looks like it works.
-->
<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const assessmentId = String(route.params.id ?? '');

function backToList() {
  router.push({ name: 'student.tutoring2.assessments' });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="student"
      :kicker="t('tutoring2.common.roleStudent')"
      :title="t('tutoring2.student.takeAssessment.title')"
    />

    <section class="rounded-3xl border border-amber-100 bg-amber-50/60 p-md">
      <h2 class="text-sm font-bold text-amber-900">
        {{ t('tutoring2.student.takeAssessment.unavailableTitle') }}
      </h2>
      <p class="mt-1.5 text-2xs leading-relaxed text-amber-800">
        {{ t('tutoring2.student.takeAssessment.unavailableBody') }}
      </p>
      <p v-if="assessmentId" class="mt-2 text-2xs text-amber-700/80">
        {{ t('tutoring2.student.takeAssessment.reference', { id: assessmentId.slice(0, 8) }) }}
      </p>

      <div class="mt-4">
        <Button variant="secondary" size="sm" @click="backToList">
          {{ t('tutoring2.student.takeAssessment.backToList') }}
        </Button>
      </div>
    </section>
  </div>
</template>
