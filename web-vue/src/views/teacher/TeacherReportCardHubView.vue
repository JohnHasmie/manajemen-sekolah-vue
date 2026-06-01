<!--
  TeacherReportCardHubView.vue — Rapor hub (Frame A).

  Web port of `teacher_report_card_overview.dart`. Lands the wali
  kelas on a per-class grid:

    1. BrandPageHeader (guru) — kicker "Akademik · Rapor", title
       "Wali Kelas", meta `N kelas · M siswa`
    2. KpiStripCards — Siswa total / Terbit / Diperiksa / Draft
    3. PageFilterToolbar — search input (filter class name)
    4. List of <ReportCardClassCard> — drill into per-class roster

  Endpoints:
    GET /raports/teacher-summary?teacher_id=  — per-class stats
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { ReportCardService } from '@/services/report-card.service';
import type { RaportClassSummary } from '@/types/report-card';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import KpiStripCards, {
  type KpiCard,
} from '@/components/feature/KpiStripCards.vue';
import ReportCardClassCard from '@/components/feature/ReportCardClassCard.vue';
import Toast from '@/components/ui/Toast.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const auth = useAuthStore();
const router = useRouter();

// ── Data state ──
const classes = ref<RaportClassSummary[]>([]);
const isLoading = ref(true);
const loadError = ref<string | null>(null);
const searchQuery = ref<string>('');
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const teacherId = computed(() => auth.teacherId ?? auth.user?.id ?? '');

// ── Loader ──
async function reload() {
  if (!teacherId.value) {
    loadError.value = 'Profil guru belum termuat.';
    isLoading.value = false;
    return;
  }
  isLoading.value = true;
  loadError.value = null;
  try {
    classes.value = await ReportCardService.getTeacherClassSummary({
      teacher_id: teacherId.value,
    });
  } catch (e) {
    loadError.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(reload);
useAcademicYearWatcher(reload);

// ── Derived ──
const visibleClasses = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return classes.value;
  return classes.value.filter((c) =>
    c.class_name.toLowerCase().includes(q),
  );
});

const kpiCards = computed<KpiCard[]>(() => {
  let students = 0;
  let terbit = 0;
  let diperiksa = 0;
  let draf = 0;
  for (const c of classes.value) {
    students += c.student_count;
    terbit += c.published_count;
    diperiksa += c.final_count;
    draf += c.draft_count;
  }
  return [
    {
      icon: 'users',
      label: 'Total Siswa',
      value: students,
      tone: 'brand',
    },
    {
      icon: 'check-circle',
      label: 'Terbit',
      value: terbit,
      tone: 'green',
    },
    {
      icon: 'edit',
      label: 'Diperiksa',
      value: diperiksa,
      tone: diperiksa > 0 ? 'amber' : 'slate',
      accented: diperiksa > 0,
    },
    {
      icon: 'file-text',
      label: 'Draf',
      value: draf,
      tone: 'slate',
    },
  ];
});

const listState = computed<AsyncState<RaportClassSummary[]>>(() => {
  if (isLoading.value && classes.value.length === 0) return { status: 'loading' };
  if (loadError.value) return { status: 'error', error: loadError.value };
  if (visibleClasses.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: visibleClasses.value };
});

// ── Actions ──
function openClass(cls: RaportClassSummary) {
  // Phase 3 will register `teacher.report-cards.class` for the per-
  // class roster. Until then, surface a friendly placeholder so the
  // tap doesn't 404.
  const target = router.resolve({
    name: 'teacher.report-cards.class',
    params: { classId: cls.class_id },
  });
  if (target.matched.length === 0) {
    toast.value = {
      message: `Daftar siswa ${cls.class_name} — tersedia di pembaruan berikutnya.`,
      tone: 'success',
    };
    return;
  }
  router.push(target);
}

// Avoid lint warning while `auth` is only consumed via teacherId.
void auth;
</script>

<template>
  <div class="space-y-4 pb-12">
    <!-- HEADER -->
    <BrandPageHeader
      role="guru"
      kicker="Akademik · Rapor"
      title="Wali Kelas"
      :meta="
        classes.length > 0
          ? `${classes.length} kelas · ${classes.reduce((a, c) => a + c.student_count, 0)} siswa`
          : 'Memuat ringkasan kelas perwalian…'
      "
      :live-dot="false"
    />

    <!-- KPI -->
    <KpiStripCards :cards="kpiCards" />

    <!-- FILTER TOOLBAR -->
    <PageFilterToolbar
      v-model:search="searchQuery"
      search-placeholder="Cari nama kelas…"
    >
      <template #chips>
        <span class="text-[11px] font-bold text-slate-500 px-1">
          {{ visibleClasses.length }} kelas
        </span>
      </template>
    </PageFilterToolbar>

    <!-- CLASS LIST -->
    <AsyncView
      :state="listState"
      :empty-title="
        searchQuery
          ? 'Tidak ada kelas cocok'
          : 'Belum ada kelas perwalian'
      "
      empty-description="Pilih kelas untuk melihat daftar rapor siswa atau mulai mengisi."
      empty-icon="users"
      @retry="reload"
    >
      <div class="space-y-2.5">
        <ReportCardClassCard
          v-for="cls in visibleClasses"
          :key="cls.class_id"
          :cls="cls"
          @click="openClass"
        />
      </div>
    </AsyncView>

    <Toast
      v-if="toast"
      :message="toast.message"
      :tone="toast.tone"
      @close="toast = null"
    />
  </div>
</template>
