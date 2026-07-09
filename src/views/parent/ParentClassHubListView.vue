<!--
  Parent "Kelas" list (web) — the active child's classes as a flat, read-only
  list, with a child selector when there's more than one child. Mirrors the
  mobile parent list. Tapping a card opens the read-only per-class hub.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';
import { useChildPicker } from '@/composables/useChildPicker';
import { useRoleColor } from '@/composables/useRoleColor';
import { ClassHubService } from '@/services/class-hub.service';
import type { ClassCard } from '@/types/class-hub';

const { t } = useI18n();
const router = useRouter();
const role = useRoleColor(() => 'wali');
const { children, activeChildId, setActive } = useChildPicker();

const loading = ref(true);
const error = ref<string | null>(null);
const classes = ref<ClassCard[]>([]);

async function load() {
  if (!activeChildId.value) {
    classes.value = [];
    loading.value = false;
    return;
  }
  loading.value = true;
  error.value = null;
  try {
    classes.value = await ClassHubService.myClasses(activeChildId.value);
  } catch (e) {
    error.value = e instanceof Error ? e.message : String(e);
  } finally {
    loading.value = false;
  }
}
watch(activeChildId, load, { immediate: true });

const childOptions = computed(() =>
  children.value.map((c) => ({ key: c.student_id, label: c.name })),
);

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
  router.push({ name: 'parent.classes.detail', params: { id: c.id } });
}
</script>

<template>
  <div class="p-4 md:p-6">
    <header
      class="rounded-2xl px-5 py-4 mb-4"
      :style="{ backgroundColor: role.hex + '1A' }"
    >
      <h1 class="text-lg font-medium" :style="{ color: role.hex }">
        {{ t('classHub.title') }}
      </h1>
      <p class="text-sm text-slate-500">{{ t('classHub.listSubtitle') }}</p>
    </header>

    <div v-if="childOptions.length > 1" class="mb-4">
      <SegmentedControl
        :model-value="activeChildId"
        :options="childOptions"
        @update:model-value="setActive(String($event))"
      />
    </div>

    <AsyncView
      :state="state"
      :empty-title="t('classHub.emptyListTitle')"
      :empty-description="t('classHub.emptyListMsg')"
    >
      <div class="space-y-2.5">
        <button
          v-for="c in classes"
          :key="c.id"
          type="button"
          class="w-full text-left bg-white rounded-xl border border-slate-200 p-3 flex items-center gap-3 hover:border-slate-300"
          @click="openClass(c)"
        >
          <span
            class="w-11 h-11 rounded-xl flex items-center justify-center font-medium shrink-0"
            :style="{ backgroundColor: role.hex + '26', color: role.hex }"
          >{{ initials(c.name) }}</span>
          <span class="flex-1 min-w-0">
            <span class="block text-sm font-medium">{{ c.name }}</span>
            <span class="block text-xs text-slate-500">
              {{ c.studentCount }} {{ t('classHub.kpiStudents') }}
            </span>
          </span>
          <span class="text-slate-300">›</span>
        </button>
      </div>
    </AsyncView>
  </div>
</template>
