<!--
  ParentTutoring2ProgressView.vue — one child's score trend, for the
  wali.

  Route: /parent/tutoring2/progress/:studentId
  Endpoint: GET /tutoring-v2/students/{id}/progress   — ONE call

  ── This view is a thin wrapper, on purpose ──

  The whole body used to live here. When the staff Peringkat boards
  gained a tappable row (Luay, 2026-09 — "Pada website belum menampilkan
  detail nilai siswa"), admins and tutors needed the SAME rendering of
  the same payload for a student who is not the reader's child. Copying
  it would have produced two screens that drift — and what would drift
  first is precisely the delicate part: `kkm_percent` is pre-rescaled by
  the server, `points` arrive oldest-first, and the peer baseline is a
  constant rather than a series. Get any of those wrong in one copy only
  and a wali and an admin read the same child differently.

  So the body moved to <Tutoring2StudentScores> and this file kept the
  two things that are genuinely wali-specific:

    • the SUBJECT — `:studentId` from the route, the same mechanism as
      every other parent/tutoring2 view;
    • the WORDING — a wali reads "Perkembangan nilai" and "Nilai anak"
      about their own child. Staff read that student's NAME and "Nilai
      siswa". Those cannot be shared, so the header is a slot and the
      series legend is a prop.

  The behaviour of this screen is pinned by
  `ParentTutoring2ProgressView.spec.ts`, which was written against the
  pre-extraction component and is unchanged by it.

  Distinct from ParentTutoring2ReportCardView (a rapor scaffold) — this
  page is the per-assessment score history, not a term report.
-->
<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import Tutoring2StudentScores from '@/components/tutoring2/Tutoring2StudentScores.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';

const { t } = useI18n();
const route = useRoute();

const studentId = String(route.params.studentId ?? '');
</script>

<template>
  <Tutoring2StudentScores
    :student-id="studentId"
    :legend-subject-label="t('tutoring2.parent.progress.legendChild')"
  >
    <template #header="{ count, loading }">
      <BrandPageHeader
        role="parent"
        :kicker="t('tutoring2.parent.home.subtitle')"
        :title="t('tutoring2.parent.progress.title')"
        :meta="
          loading
            ? t('tutoring2.common.loading')
            : t('tutoring2.parent.progress.meta', { count })
        "
      />
    </template>
  </Tutoring2StudentScores>
</template>
