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
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Card from '@/components/ui/Card.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
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
    <BrandPageHeader
      role="admin"
      :title="t('classHub.oversightTitle')"
      :meta="t('classHub.oversightSubtitle')"
      class="mb-4"
    />

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
              <StatusBadge
                v-if="c.needsGrading > 0"
                :label="`${c.needsGrading} ${t('classHub.kpiNeedsGrading')}`"
                tone="danger"
              />
              <StatusBadge
                v-if="c.isSilent"
                :label="t('classHub.silent')"
                tone="warning"
              />
            </span>
          </button>
        </div>

        <aside class="order-1 md:order-2">
          <Card :title="t('classHub.needsAttention')">
            <div class="flex flex-col items-start gap-2">
              <StatusBadge
                v-if="allGood"
                :label="t('classHub.allGood')"
                tone="success"
                dot
              />
              <StatusBadge
                v-if="silent.length"
                :label="`${silent.length} ${t('classHub.attnSilent')}`"
                tone="warning"
                dot
              />
              <StatusBadge
                v-if="backlog > 0"
                :label="`${backlog} ${t('classHub.attnGrading')}`"
                tone="danger"
                dot
              />
            </div>
          </Card>
        </aside>
      </div>
    </AsyncView>
  </div>
</template>
