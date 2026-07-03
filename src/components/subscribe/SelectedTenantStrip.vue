<!--
  SelectedTenantStrip.vue — the sticky top strip in the /subscribe
  conversion state showing which tenant is being converted. Matches
  mockup 2's `.sc-sel` block.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { SubscriptionTenant } from '@/types/subscription-billing';

const props = defineProps<{
  tenant: SubscriptionTenant;
}>();

defineEmits<{ switchTenant: [] }>();

const isBimbel = computed(() => props.tenant.tenant_type === 'bimbel');
const initials = computed(() => {
  const parts = props.tenant.name.split(/\s+/).filter(Boolean).slice(0, 2);
  return parts.map((p) => p[0]).join('').toUpperCase() || '?';
});
</script>

<template>
  <div class="ss-sel">
    <div class="ss-savatar" :class="isBimbel ? 'tut' : 'sch'">
      {{ initials }}
    </div>
    <div class="ss-meta">
      <div class="ss-sname">{{ tenant.name }}</div>
      <div class="ss-smeta">
        <span>
          <i
            :class="`ti ti-${isBimbel ? 'books' : 'school'}`"
            style="font-size:11px"
            aria-hidden="true"
          />
          {{ isBimbel ? 'Bimbel' : 'Sekolah' }}
        </span>
        <span>
          <i class="ti ti-users" style="font-size:11px" aria-hidden="true" />
          {{ tenant.student_count }} siswa · {{ tenant.staff_count }}
          {{ isBimbel ? 'tutor' : 'guru/staf' }}
        </span>
        <span class="ss-highlight">
          <i class="ti ti-check" style="font-size:11px" aria-hidden="true" />
          Data demo terbawa otomatis
        </span>
      </div>
    </div>
    <button
      type="button"
      class="ss-switch"
      @click="$emit('switchTenant')"
    >
      <i class="ti ti-arrows-shuffle" style="font-size:13px" aria-hidden="true" />
      Ganti tenant
    </button>
  </div>
</template>

<style scoped>
.ss-sel {
  margin: 4px 22px 18px;
  padding: 14px 16px;
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  display: flex; align-items: center; gap: 12px;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04);
}
.ss-savatar {
  width: 44px; height: 44px; border-radius: 11px;
  display: grid; place-items: center;
  font-weight: 600; font-size: 14px;
  flex-shrink: 0;
}
.ss-savatar.sch { background: #E6F1FB; color: #113E75; }
.ss-savatar.tut { background: #EAF3DE; color: #27500A; }
.ss-meta { flex: 1; min-width: 0; }
.ss-sname { font-size: 14.5px; font-weight: 500; letter-spacing: -0.1px; color: #0F172A; }
.ss-smeta {
  display: flex; align-items: center; gap: 12px;
  font-size: 11px; color: #64748B;
  margin-top: 3px;
  flex-wrap: wrap;
}
.ss-smeta span {
  display: inline-flex; align-items: center; gap: 4px;
}
.ss-highlight { color: #0F6E56; }

.ss-switch {
  margin-left: auto;
  padding: 7px 12px;
  background: transparent;
  border: 0.5px solid #CBD5E1;
  border-radius: 8px;
  font-size: 11.5px; color: #475569; font-weight: 500;
  cursor: pointer;
  display: flex; align-items: center; gap: 5px;
}
.ss-switch:hover { border-color: #94A3B8; background: #F8FAFC; }
</style>
