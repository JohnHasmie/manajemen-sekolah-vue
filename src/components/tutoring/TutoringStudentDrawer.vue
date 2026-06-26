<script setup lang="ts">
import NavIcon from '@/components/feature/NavIcon.vue';

defineProps<{
  open: boolean;
  student: any; // Ideally typed, using any for now to be flexible
}>();

defineEmits<{
  (e: 'close'): void;
}>();
</script>

<template>
  <div>
    <!-- Backdrop -->
    <Transition
      enter-active-class="transition-opacity duration-300"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-opacity duration-300"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div v-if="open" class="fixed inset-0 bg-slate-900/60 z-40 backdrop-blur-sm" @click="$emit('close')"></div>
    </Transition>

    <!-- Drawer -->
    <Transition
      enter-active-class="transition-transform duration-300 ease-out"
      enter-from-class="translate-x-full"
      enter-to-class="translate-x-0"
      leave-active-class="transition-transform duration-300 ease-in"
      leave-from-class="translate-x-0"
      leave-to-class="translate-x-full"
    >
      <div v-if="open" class="fixed inset-y-0 right-0 w-full md:w-[400px] bg-tutoring-panel border-l border-tutoring-border z-50 flex flex-col shadow-2xl">
        <!-- Header -->
        <div class="px-6 py-5 border-b border-tutoring-border flex items-center justify-between bg-tutoring-panel/50 backdrop-blur-md">
          <h2 class="text-lg font-bold text-tutoring-text-hi">Detail Siswa</h2>
          <button type="button" class="p-2 rounded-full hover:bg-white/10 text-tutoring-text-mid transition-colors" @click="$emit('close')">
            <NavIcon name="x" :size="20" />
          </button>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6" v-if="student">
          <!-- Profile Header -->
          <div class="flex items-center gap-4 mb-8">
            <div class="w-16 h-16 rounded-2xl bg-tutoring-accent/20 flex items-center justify-center text-tutoring-accent font-black text-2xl shadow-inner border border-tutoring-accent/30">
              {{ student.name.charAt(0).toUpperCase() }}
            </div>
            <div>
              <h3 class="text-xl font-black text-tutoring-text-hi">{{ student.name }}</h3>
              <div class="flex items-center gap-2 mt-1">
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20" v-if="student.status === 'Aktif'">Aktif</span>
                <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20" v-else-if="student.status === 'Trial'">Trial</span>
                <span class="text-sm font-semibold text-tutoring-text-mid">{{ student.schoolGrade }}</span>
              </div>
            </div>
          </div>

          <!-- Info List -->
          <div class="space-y-6">
            <div>
              <h4 class="text-[11px] font-black uppercase tracking-widest text-tutoring-text-lo mb-3">Kontak</h4>
              <div class="space-y-3">
                <div class="flex items-center gap-3">
                  <div class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-tutoring-text-mid">
                    <NavIcon name="phone" :size="14" />
                  </div>
                  <div class="text-sm font-medium text-tutoring-text-hi">{{ student.phone || '-' }}</div>
                </div>
                <div class="flex items-center gap-3">
                  <div class="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-tutoring-text-mid">
                    <NavIcon name="mail" :size="14" />
                  </div>
                  <div class="text-sm font-medium text-tutoring-text-hi">{{ student.email || '-' }}</div>
                </div>
              </div>
            </div>

            <div class="h-px bg-tutoring-border/50"></div>

            <div>
              <h4 class="text-[11px] font-black uppercase tracking-widest text-tutoring-text-lo mb-3">Program</h4>
              <div class="bg-white/5 rounded-xl p-4 border border-tutoring-border/50">
                <div class="text-sm font-bold text-tutoring-text-hi">{{ student.program }}</div>
                <div class="text-xs text-tutoring-text-mid mt-1">Terdaftar sejak {{ student.enrollDate }}</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Footer Actions -->
        <div class="p-6 border-t border-tutoring-border bg-tutoring-panel/50 backdrop-blur-md flex gap-3">
          <button type="button" class="flex-1 py-2.5 rounded-xl border border-tutoring-border text-tutoring-text-hi font-bold text-sm hover:bg-white/5 transition-colors">Edit</button>
          <button type="button" class="flex-1 py-2.5 rounded-xl bg-tutoring-accent text-white font-bold text-sm hover:bg-tutoring-accent-soft transition-colors shadow-lg shadow-tutoring-accent/20">Lihat Raport</button>
        </div>
      </div>
    </Transition>
  </div>
</template>
