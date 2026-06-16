<!--
  AdminTutoringLeaderboardView — ranking siswa per kelompok.
  Composite score = attendance% × 0.5 + avg_assessment% × 0.5.

  Group selector in the filter row; row-1 is highlighted gold.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type {
  TutoringGroup,
  TutoringLeaderboardRow,
} from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import PageFilterToolbar from '@/components/filters/PageFilterToolbar.vue';
import AppFilterChip from '@/components/filters/AppFilterChip.vue';
import Modal from '@/components/ui/Modal.vue';
import TutoringEmpty from '@/components/feature/tutoring/TutoringEmpty.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const toast = useToast();

const groups = ref<TutoringGroup[]>([]);
const groupId = ref<string>('');
const rows = ref<TutoringLeaderboardRow[]>([]);
const loading = ref(true);
const showGroupPicker = ref(false);

const activeGroupLabel = computed(() => {
  if (!groupId.value) return t('admin.bimbel.leaderboard.pick_group');
  return groups.value.find((g) => g.id === groupId.value)?.name ?? '—';
});

async function loadGroups() {
  try {
    groups.value = await TutoringService.getAllGroups();
    if (!groupId.value && groups.value[0]) {
      groupId.value = groups.value[0].id;
    }
  } catch {/* non-fatal */}
}

async function loadRanks() {
  if (!groupId.value) return;
  loading.value = true;
  try {
    rows.value = await TutoringService.getGroupLeaderboard(groupId.value);
  } catch (e) {
    toast.error(e instanceof Error ? e.message : t('admin.bimbel.leaderboard.load_fail'));
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  await loadGroups();
  await loadRanks();
});

function pickGroup(id: string) {
  groupId.value = id;
  showGroupPicker.value = false;
  loadRanks();
}

function rankClass(rank: number): string {
  if (rank === 1) return 'bg-amber-100 text-amber-700 border-amber-300';
  if (rank === 2) return 'bg-slate-200 text-bimbel-text-mid border-slate-300';
  if (rank === 3) return 'bg-orange-100 text-orange-700 border-orange-300';
  return 'bg-bimbel-grey-dim text-bimbel-text-mid border-bimbel-border';
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Bimbel · Leaderboard"
      :title="t('admin.bimbel.leaderboard.title')"
      :meta="rows.length > 0 ? t('admin.bimbel.leaderboard.students_meta', { count: rows.length }) : ''"
    />

    <PageFilterToolbar :hide-default-search="true">
      <template #chips>
        <AppFilterChip
          :label="t('admin.bimbel.leaderboard.filter_group')"
          :value="activeGroupLabel"
          icon-name="users"
          tone="violet"
          @click="showGroupPicker = true"
        />
      </template>
    </PageFilterToolbar>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">
      {{ t('tutoring.common.loading') }}
    </div>
    <TutoringEmpty
      v-else-if="!groupId"
      :text="t('admin.bimbel.leaderboard.pick_group_first')"
      icon="users"
    />
    <TutoringEmpty
      v-else-if="rows.length === 0"
      :text="t('admin.bimbel.leaderboard.empty')"
      icon="users"
    />
    <div v-else class="bg-bimbel-panel border border-bimbel-border-soft rounded-2xl overflow-hidden">
      <table class="w-full text-sm">
        <thead class="text-[10.5px] uppercase tracking-wider text-bimbel-text-mid">
          <tr class="border-b border-bimbel-border">
            <th class="text-center font-bold px-3 py-2.5 w-12">#</th>
            <th class="text-left font-bold px-3 py-2.5">{{ t('admin.bimbel.leaderboard.th_student') }}</th>
            <th class="text-right font-bold px-3 py-2.5">{{ t('admin.bimbel.leaderboard.th_attendance') }}</th>
            <th class="text-right font-bold px-3 py-2.5">{{ t('admin.bimbel.leaderboard.th_avg_score') }}</th>
            <th class="text-right font-bold px-3 py-2.5">{{ t('admin.bimbel.leaderboard.th_score') }}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="r in rows"
            :key="r.student_id"
            class="border-b border-bimbel-border-soft last:border-0 hover:bg-bimbel-bg"
          >
            <td class="px-3 py-3 text-center">
              <span
                class="inline-flex items-center justify-center w-7 h-7 rounded-full text-[11.5px] font-extrabold border"
                :class="rankClass(r.rank)"
              >
                {{ r.rank }}
              </span>
            </td>
            <td class="px-3 py-3 font-semibold text-bimbel-text-hi">{{ r.name }}</td>
            <td class="px-3 py-3 text-right text-bimbel-text-mid">
              {{ r.attendance_rate == null ? '—' : r.attendance_rate + '%' }}
            </td>
            <td class="px-3 py-3 text-right text-bimbel-text-mid">
              {{ r.avg_score == null ? '—' : r.avg_score }}
            </td>
            <td class="px-3 py-3 text-right font-bold text-bimbel-accent">
              {{ r.composite }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <Modal v-if="showGroupPicker" :title="t('admin.bimbel.leaderboard.modal_title')" @close="showGroupPicker = false">
      <ul class="space-y-1">
        <li v-for="g in groups" :key="g.id">
          <button
            type="button"
            class="w-full text-left px-3 py-2.5 rounded-lg hover:bg-bimbel-bg"
            :class="{ 'bg-bimbel-accent/5 text-bimbel-accent font-bold': groupId === g.id }"
            @click="pickGroup(g.id)"
          >
            {{ g.name }}
          </button>
        </li>
      </ul>
    </Modal>

    <p v-if="groupId" class="text-[12px] text-bimbel-text-mid italic px-1">
      <NavIcon name="info" :size="11" class="inline-block align-text-bottom" />
      {{ t('admin.bimbel.leaderboard.formula_hint') }}
    </p>
  </div>
</template>
