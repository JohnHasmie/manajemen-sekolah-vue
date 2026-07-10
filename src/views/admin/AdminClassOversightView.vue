<!--
  Admin "Pemantauan Kelas" (web) — school-wide, read-only oversight of every
  class as gradient-hero cards (a distinct colour per class, so the list is
  scannable) with health signals in the footer + a "Perlu perhatian" summary.
  A card opens the same per-class hub read-only. Mirrors the mobile
  AdminClassOversightScreen. Uses the shared ClassHeroCard.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import AsyncView from '@/components/data/AsyncView.vue';
import ClassHeroCard from '@/components/feature/ClassHeroCard.vue';
import Card from '@/components/ui/Card.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import StatusBadge from '@/components/ui/StatusBadge.vue';
import { ClassHubService } from '@/services/class-hub.service';
import type { ClassCard } from '@/types/class-hub';
import { classHubAccent, classHubGradientCss } from '@/utils/classHubTheme';

const { t } = useI18n();
const router = useRouter();

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

// Oversight is class-level (no subject), so colour each card by the class name
// — deterministic + distinct, matching the Kelas hub gradient system.
function gradientFor(c: ClassCard): string {
  return classHubGradientCss(c.name);
}
function accentFor(c: ClassCard): string {
  return classHubAccent(c.name);
}
function subline(c: ClassCard): string {
  const count = `${c.studentCount} ${t('classHub.kpiStudents')}`;
  return c.homeroomTeacherName ? `${c.homeroomTeacherName} · ${count}` : count;
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
        <div class="order-2 md:order-1 grid gap-3 sm:grid-cols-2">
          <ClassHeroCard
            v-for="c in classes"
            :key="c.id"
            :identity-key="c.id"
            :name="c.name"
            :subline="subline(c)"
            :gradient="gradientFor(c)"
            @click="openClass(c)"
          >
            <template #footer>
              <div class="flex items-center gap-2 bg-white px-4 py-3">
                <span class="flex min-w-0 flex-1 flex-wrap gap-1.5">
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
                <span
                  class="text-sm font-semibold"
                  :style="{ color: accentFor(c) }"
                >
                  {{ t('classHub.open') }}
                </span>
                <span :style="{ color: accentFor(c) }">›</span>
              </div>
            </template>
          </ClassHeroCard>
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
