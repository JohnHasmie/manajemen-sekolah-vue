<!--
  ModuleCatalogGrid.vue — module catalog grouped by category with
  ModuleCard grid inside each group. Matches mockup 1's `.sw-modules`
  arrangement including the little dependency note "Raport butuh Nilai".
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { ModuleCatalog, ModuleCatalogItem } from '@/types/subscription-billing';
import { CATEGORY_TINTS, GROUP_ORDER, moduleLabel } from './moduleTokens';
import ModuleCard from './ModuleCard.vue';

const props = defineProps<{
  catalog: ModuleCatalog;
  selectedKeys: Set<string>;
  autoIncluded: Map<string, string[]>;
  tenantType?: 'sekolah' | 'bimbel' | null;
}>();

defineEmits<{ toggle: [key: string] }>();

interface Group {
  name: string;
  tint: { bg: string; fg: string };
  items: ModuleCatalogItem[];
  note?: string;
}

const groupedModules = computed<Group[]>(() => {
  const groups: Record<string, ModuleCatalogItem[]> = {};
  Object.values(props.catalog.optional).forEach((item) => {
    (groups[item.group] ??= []).push(item);
  });

  const orderedNames = [
    ...GROUP_ORDER.filter((g) => g in groups),
    ...Object.keys(groups).filter((g) => !GROUP_ORDER.includes(g)),
  ];

  return orderedNames.map<Group>((name) => {
    const items = groups[name];
    const noteBits: string[] = [];
    items.forEach((it) => {
      if (it.requires.length) {
        const reqLabels = it.requires
          .map((r) => {
            const dep = props.catalog.optional[r];
            return dep ? moduleLabel(dep, props.tenantType) : null;
          })
          .filter(Boolean) as string[];
        if (reqLabels.length) {
          noteBits.push(
            `${moduleLabel(it, props.tenantType)} butuh ${reqLabels.join(', ')}`,
          );
        }
      }
    });
    return {
      name,
      tint: CATEGORY_TINTS[name] ?? CATEGORY_TINTS.Default,
      items,
      note: noteBits[0],
    };
  });
});

const groupIcon: Record<string, string> = {
  Absensi: 'clipboard-check',
  Akademik: 'school',
  Guru: 'chalkboard',
  Keuangan: 'cash',
  Komunikasi: 'speakerphone',
  Bimbel: 'books',
  AI: 'sparkles',
};
</script>

<template>
  <div class="cg-root">
    <div v-for="g in groupedModules" :key="g.name" class="cg-group">
      <div class="cg-head">
        <div
          class="cg-h-icon"
          :style="{ background: g.tint.bg, color: g.tint.fg }"
        >
          <i
            :class="`ti ti-${groupIcon[g.name] ?? 'category'}`"
            aria-hidden="true"
          />
        </div>
        <div class="cg-h-label">{{ g.name }}</div>
        <div v-if="g.note" class="cg-h-note">{{ g.note }}</div>
      </div>

      <div class="cg-grid">
        <ModuleCard
          v-for="item in g.items"
          :key="item.key"
          :item="item"
          :selected="selectedKeys.has(item.key)"
          :auto-include="autoIncluded.get(item.key)"
          :tenant-type="tenantType"
          @toggle="$emit('toggle', item.key)"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.cg-root { display: flex; flex-direction: column; gap: 6px; }
.cg-group { }

.cg-head {
  display: flex; align-items: center; gap: 8px;
  margin: 18px 0 8px;
}
.cg-h-icon {
  width: 22px; height: 22px; border-radius: 6px;
  display: grid; place-items: center;
  font-size: 13px;
}
.cg-h-label {
  font-size: 10.5px; font-weight: 600;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: #64748B;
}
.cg-h-note {
  font-size: 10.5px; color: #94A3B8;
  margin-left: auto;
}

.cg-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
</style>
