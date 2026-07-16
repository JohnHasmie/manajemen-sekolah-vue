<!--
  AdminTeacherEngagementView.vue — /admin/prestasi-guru

  Full kepsek-facing engagement page. Left column: 4 KPI + engagement
  table. Right rail: SleepyTeachersCard (sepi filter + kirim
  pengingat batch) + top-3 mini leaderboard for glance.

  Single fetch of /admin/prestasi-guru at mount — the payload already
  bundles kpi + sorotan + rows so the page paints once with everything
  it needs. `kirim-pengingat` fires from the sleepy card without
  refetching the table (bell entries are async; the guru's next
  activity moves them out of the 7+d bucket on the next daily rollup).
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminTeacherEngagementTable from '@/components/feature/prestasi-admin/AdminTeacherEngagementTable.vue';
import SleepyTeachersCard from '@/components/feature/prestasi-admin/SleepyTeachersCard.vue';
import SorotanPrestasiCard from '@/components/feature/prestasi/SorotanPrestasiCard.vue';
import { TeacherProgressService, type AdminIndexPayload, type TeacherRowStatus } from '@/services/teacher-progress.service';
import { useToast } from '@/composables/useToast';
import { useRouter } from 'vue-router';

const toast = useToast();
const router = useRouter();

const payload = ref<AdminIndexPayload | null>(null);
const loadError = ref<string | null>(null);
const sending = ref(false);

const search = ref('');
const statusFilter = ref<TeacherRowStatus | ''>('');

const sepiTeachers = computed(() =>
  (payload.value?.data ?? [])
    .filter((r) => r.status === 'sepi')
    .map((r) => ({
      teacher_id: r.teacher_id,
      nama: r.nama,
      terakhir_aktif: r.terakhir_aktif,
    })),
);

async function load() {
  loadError.value = null;
  try {
    payload.value = await TeacherProgressService.getAdminIndex();
  } catch (e: any) {
    loadError.value = e?.response?.status === 402
      ? 'Modul Prestasi belum aktif untuk sekolah ini.'
      : 'Gagal memuat data engagement guru.';
  }
}

async function onSendReminder(teacherIds: string[]) {
  sending.value = true;
  try {
    const res = await TeacherProgressService.kirimPengingat(teacherIds);
    toast.success(`Pengingat terkirim ke ${res.terkirim} guru.`);
  } catch {
    toast.error('Gagal mengirim pengingat. Coba lagi.');
  } finally {
    sending.value = false;
  }
}

onMounted(() => {
  void load();
});
</script>

<template>
  <div class="pb-10">
    <BrandPageHeader
      role="admin"
      kicker="Retensi Guru"
      title="Prestasi Guru"
      meta="Pantau engagement, apresiasi guru rajin, sapa yang tidur."
    />

    <div class="px-4 sm:px-6 -mt-6 relative z-10 space-y-6 max-w-6xl mx-auto">
      <div
        v-if="loadError"
        class="rounded-2xl p-6 bg-amber-50 border border-amber-200 text-amber-800 flex items-start gap-3"
      >
        <NavIcon name="alert-circle" :size="20" />
        <p class="text-sm font-bold">{{ loadError }}</p>
      </div>

      <template v-else-if="payload">
        <!-- Sorotan admin: guru_bulan_ini always visible, perlu_sapaan optional. -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <SorotanPrestasiCard
            :state="payload.meta.sorotan.guru_bulan_ini.state"
            :eyebrow="payload.meta.sorotan.guru_bulan_ini.eyebrow"
            :title="payload.meta.sorotan.guru_bulan_ini.title"
            :sub="payload.meta.sorotan.guru_bulan_ini.sub"
            :cta-label="payload.meta.sorotan.guru_bulan_ini.cta_label"
            :cta-target="payload.meta.sorotan.guru_bulan_ini.cta_target"
            :meta="null"
            @cta="router.push(payload.meta.sorotan.guru_bulan_ini.cta_target)"
          />
          <SorotanPrestasiCard
            v-if="payload.meta.sorotan.perlu_sapaan.count > 0"
            :state="payload.meta.sorotan.perlu_sapaan.state"
            :eyebrow="payload.meta.sorotan.perlu_sapaan.eyebrow"
            :title="payload.meta.sorotan.perlu_sapaan.title ?? ''"
            :sub="payload.meta.sorotan.perlu_sapaan.sub"
            :cta-label="payload.meta.sorotan.perlu_sapaan.cta_label ?? 'Kirim pengingat'"
            :cta-target="payload.meta.sorotan.perlu_sapaan.cta_target ?? ''"
            :meta="null"
          />
        </div>

        <!-- 4 KPI -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
            <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Total guru</p>
            <p class="text-xl font-black text-slate-900 mt-2">{{ payload.meta.kpi.total_guru }}</p>
          </div>
          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
            <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Aktif minggu ini</p>
            <p class="text-xl font-black text-slate-900 mt-2">{{ payload.meta.kpi.aktif_minggu_ini }}</p>
          </div>
          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
            <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Rata streak</p>
            <p class="text-xl font-black text-slate-900 mt-2">
              {{ payload.meta.kpi.rata_streak }}<span class="text-3xs font-bold text-slate-500 ml-1">hari</span>
            </p>
          </div>
          <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
            <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Perlu perhatian</p>
            <p class="text-xl font-black text-slate-900 mt-2">{{ payload.meta.kpi.perlu_perhatian }}</p>
          </div>
        </div>

        <!-- Table + right rail -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
          <div class="lg:col-span-2 space-y-3">
            <!-- Search + filter row -->
            <div class="flex flex-wrap items-center gap-2">
              <input
                v-model="search"
                type="text"
                placeholder="Cari nama guru…"
                class="flex-1 min-w-40 rounded-xl border border-slate-200 bg-white px-3 py-2 text-2xs"
              />
              <select
                v-model="statusFilter"
                class="rounded-xl border border-slate-200 bg-white px-3 py-2 text-2xs font-bold text-slate-700"
              >
                <option value="">Semua status</option>
                <option value="aktif">Aktif</option>
                <option value="melambat">Melambat</option>
                <option value="sepi">Sepi</option>
                <option value="never">Belum aktif</option>
              </select>
            </div>
            <AdminTeacherEngagementTable
              :rows="payload.data"
              :search="search"
              :status-filter="statusFilter"
            />
          </div>

          <aside class="space-y-4">
            <SleepyTeachersCard
              :sepi-teachers="sepiTeachers"
              :sending="sending"
              @send="onSendReminder"
            />

            <!-- Top 3 mini list -->
            <div class="rounded-2xl bg-white border border-slate-100 shadow-sm p-4">
              <p class="text-3xs font-bold text-slate-500 uppercase tracking-widest">Top minggu ini</p>
              <ul v-if="payload.meta.kpi.top_tiga.length > 0" class="space-y-2 mt-3">
                <li
                  v-for="(t, i) in payload.meta.kpi.top_tiga"
                  :key="t.teacher_id"
                  class="flex items-center gap-3"
                >
                  <span
                    class="w-6 text-sm font-black text-center flex-shrink-0"
                    :class="i === 0
                      ? 'text-amber-500'
                      : i === 1
                        ? 'text-slate-500'
                        : 'text-orange-500'"
                  >
                    #{{ i + 1 }}
                  </span>
                  <p class="flex-1 text-2xs font-bold text-slate-800 truncate">{{ t.nama }}</p>
                  <p class="text-2xs font-black text-slate-800">
                    {{ t.poin }}<span class="text-3xs text-slate-500 font-bold ml-1">XP</span>
                  </p>
                </li>
              </ul>
              <p v-else class="text-2xs text-slate-500 mt-3">Belum ada aktivitas minggu ini.</p>
            </div>
          </aside>
        </div>
      </template>
    </div>
  </div>
</template>
