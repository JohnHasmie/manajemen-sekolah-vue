<!--
  Admin "Pemantauan Kelas" (web) — school-wide, read-only oversight of every
  class with health signals (grading backlog, "silent"/silent flag) + a
  "Perlu perhatian" summary. A card opens the same per-class hub read-only.
  Mirrors the mobile AdminClassOversightScreen.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import { useRoleColor } from '@/composables/useRoleColor';
import { ClassHubService } from '@/services/class-hub.service';
import type { ClassCard } from '@/types/class-hub';

const { t } = useI18n();
const router = useRouter();
const role = useRoleColor(() => 'admin');

const loading = ref(true);
const error = ref<string | null>(null);
const classes = ref<ClassCard[]>([]);

async function load() {
  loading.value = true;
  error.value = null;
  try {
    classes.value = await ClassHubService.oversight();
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e);
  } finally {
    loading.value = false;
  }
}
onMounted(load);

const silent = computed(() => classes.value.filter((c) => c.isSilent));
const backlog = computed(() =>
  classes.value.reduce((sum, c) => sum + c.needsGrading, 0),
);
const allGood = computed(() => silent.value.length === 0 && backlog.value === 0);

const state = computed(() => {
  if (loading.value) return { status: 'loading' as const };
  if (error.value) return { status: 'error' as const, error: error.value };
  if (classes.value.length === 0) return { status: 'empty' as const };
  return { status: 'content' as const };
});

function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

function openClass(c: ClassCard) {
  router.push({ name: 'admin.class-oversight.detail', params: { id: c.id } });
}
</script>

<template>
  <div class="p-4 md:p-6">
    <header
      class="rounded-2xl px-5 py-4 mb-4"
      :style="{ backgroundColor: role.hex + '1A' }"
    >
      <h1 class="text-lg font-medium" :style="{ color: role.hex }">
        {{ t('classHub.oversightTitle') }}
      </h1>
      <p class="text-sm text-slate-500">{{ t('classHub.oversightSubtitle') }}</p>
    </header>

    <AsyncView :state="state" :empty-title="t('classHub.emptyListTitle')">
      <div class="grid gap-4 md:grid-cols-[minmax(0,1fr)_260px]">
        <div class="space-y-2.5 order-2 md:order-1">
          <button
            v-for="c in classes"
            :key="c.id"
            type="button"
            class="w-full text-left bg-white rounded-xl border p-3 flex items-center gap-3 hover:border-slate-300"
            :class="c.isSilent ? 'border-orange-200' : 'border-slate-200'"
            @click="openClass(c)"
          >
            <span
              class="w-10 h-10 rounded-xl flex items-center justify-center font-medium shrink-0"
              :style="{ backgroundColor: role.hex + '26', color: role.hex }"
            >{{ initials(c.name) }}</span>
            <span class="flex-1 min-w-0">
              <span class="block text-sm font-medium truncate">{{ c.name }}</span>
              <span class="block text-xs text-slate-500 truncate">
                <template v-if="c.homeroomTeacherName">
                  {{ c.homeroomTeacherName }} ·
                </template>
                {{ c.studentCount }} {{ t('classHub.kpiStudents') }}
              </span>
            </span>
            <span class="flex gap-1.5 shrink-0">
              <span
                v-if="c.needsGrading > 0"
                class="text-[11px] font-medium px-2 py-0.5 rounded-full"
                style="background:#FCEBEB;color:#791F1F"
              >{{ c.needsGrading }} {{ t('classHub.kpiNeedsGrading') }}</span>
              <span
                v-if="c.isSilent"
                class="text-[11px] font-medium px-2 py-0.5 rounded-full"
                style="background:#FAECE7;color:#993C1D"
              >{{ t('classHub.silent') }}</span>
            </span>
          </button>
        </div>

        <aside class="order-1 md:order-2">
          <div class="bg-white rounded-xl border border-slate-200 p-3">
            <div class="text-sm font-medium mb-2.5">
              {{ t('classHub.needsAttention') }}
            </div>
            <div v-if="allGood" class="flex items-center gap-2 text-xs text-slate-500">
              <span style="color:#16A34A">✓</span>
              {{ t('classHub.allGood') }}
            </div>
            <div
              v-if="silent.length"
              class="flex items-start gap-2 text-xs text-slate-600 mb-2.5"
            >
              <span style="color:#993C1D">⚠</span>
              <span>{{ silent.length }} {{ t('classHub.attnSilent') }}</span>
            </div>
            <div
              v-if="backlog > 0"
              class="flex items-start gap-2 text-xs text-slate-600"
            >
              <span style="color:#A32D2D">●</span>
              <span>{{ backlog }} {{ t('classHub.attnGrading') }}</span>
            </div>
          </div>
        </aside>
      </div>
    </AsyncView>
  </div>
</template>
