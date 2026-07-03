<!--
  WizardChrome.vue — top nav + numbered step indicator for the
  subscribe wizard. Matches mockup 1 (subscribe_wizard_module_picker).

  Props drive the step highlight; children render whatever section they
  need via the default slot.
-->
<script setup lang="ts">
import { computed } from 'vue';

interface Step {
  key: string;
  label: string;
}

const props = defineProps<{
  steps: Step[];
  activeIndex: number;
  helpUrl?: string;
}>();

const rows = computed(() =>
  props.steps.map((s, i) => ({
    ...s,
    state:
      i < props.activeIndex ? 'done' : i === props.activeIndex ? 'active' : 'pending',
  })),
);
</script>

<template>
  <div class="wc-root">
    <div class="wc-chrome">
      <div class="wc-logo">K</div>
      <div class="wc-brand">
        <div class="wc-brand-name">KamilEdu</div>
        <div class="wc-brand-tag">Berlangganan · Pilih paket</div>
      </div>
      <a
        v-if="helpUrl"
        :href="helpUrl"
        target="_blank"
        rel="noopener"
        class="wc-help"
      >
        <i class="ti ti-message-circle" aria-hidden="true" />
        Bantuan
      </a>
    </div>

    <div class="wc-steps">
      <template v-for="(s, i) in rows" :key="s.key">
        <div class="wc-step" :class="s.state">
          <div class="wc-step-num">
            <i
              v-if="s.state === 'done'"
              class="ti ti-check"
              aria-hidden="true"
              style="font-size: 12px"
            />
            <template v-else>{{ i + 1 }}</template>
          </div>
          <span class="wc-step-label">{{ s.label }}</span>
        </div>
        <div v-if="i < rows.length - 1" class="wc-step-conn" />
      </template>
    </div>
  </div>
</template>

<style scoped>
.wc-root { background: #FFFFFF; }
.wc-chrome {
  padding: 14px 20px;
  border-bottom: 0.5px solid #E7ECF3;
  display: flex;
  align-items: center;
  gap: 14px;
}
.wc-logo {
  width: 30px; height: 30px; border-radius: 8px;
  background: linear-gradient(135deg, #1B6FB8 0%, #113E75 100%);
  color: #fff;
  display: grid; place-items: center;
  font-weight: 600; font-size: 13px;
  letter-spacing: 0.3px;
}
.wc-brand { display: flex; flex-direction: column; }
.wc-brand-name { font-size: 13.5px; font-weight: 600; letter-spacing: -0.1px; color: #0F172A; }
.wc-brand-tag { font-size: 10.5px; color: #64748B; margin-top: 1px; }
.wc-help {
  margin-left: auto;
  font-size: 12px; color: #64748B;
  display: flex; align-items: center; gap: 6px;
  text-decoration: none;
}
.wc-help:hover { color: #1B6FB8; }

.wc-steps {
  background: #F5F8FC;
  padding: 12px 20px;
  border-bottom: 0.5px solid #E7ECF3;
  display: flex;
  align-items: center;
  gap: 10px;
  overflow: hidden;
}
.wc-step {
  display: flex; align-items: center; gap: 8px;
  font-size: 11.5px; color: #94A3B8; white-space: nowrap;
}
.wc-step-num {
  width: 22px; height: 22px; border-radius: 50%;
  background: #E2E8F0; color: #64748B;
  display: grid; place-items: center;
  font-size: 11px; font-weight: 600;
}
.wc-step.done .wc-step-num { background: #DCFCE7; color: #15803D; }
.wc-step.active { color: #0F172A; }
.wc-step.active .wc-step-num {
  background: #1B6FB8; color: #fff;
  box-shadow: 0 0 0 3px rgba(27, 111, 184, 0.14);
}
.wc-step.active .wc-step-label { font-weight: 500; }
.wc-step-conn {
  flex: 1; height: 1px;
  background: #D6DEE9;
  min-width: 8px; max-width: 20px;
}
</style>
