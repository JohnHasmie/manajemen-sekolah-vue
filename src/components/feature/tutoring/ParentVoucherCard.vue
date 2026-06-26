<!--
  ParentVoucherCard — voucher "ticket" card on the parent Voucher page.
  Faux perforated edges via two absolute pseudo-circles cut into the
  left + right sides. Goes dim + struck-through when `used`.
-->
<script setup lang="ts">
defineProps<{
  code: string;
  amount: string;
  description?: string | null;
  /** "Berlaku sampai 30 Jun 2026" when active, "Dipakai 5 Mei" when used. */
  validityLabel: string;
  used?: boolean;
}>();
</script>

<template>
  <div
    class="relative overflow-hidden rounded-2xl border p-3.5 transition"
    :class="
      used
        ? 'border-bimbel-border-soft bg-bimbel-panel opacity-60'
        : 'border-emerald-500/50 bg-bimbel-panel hover:border-emerald-500'
    "
  >
    <span
      class="absolute left-[-7px] top-1/2 h-3.5 w-3.5 -translate-y-1/2 rounded-full bg-bimbel-bg"
    />
    <span
      class="absolute right-[-7px] top-1/2 h-3.5 w-3.5 -translate-y-1/2 rounded-full bg-bimbel-bg"
    />
    <span
      class="inline-block rounded-md bg-bimbel-border-soft px-2 py-0.5 font-mono text-[13px] tracking-wider text-bimbel-text-hi"
    >
      {{ code }}
    </span>
    <p
      class="mt-2 text-xl font-extrabold tracking-tight text-bimbel-text-hi"
      :class="{ 'line-through': used }"
    >
      {{ amount }}
    </p>
    <p v-if="description" class="mt-0.5 text-[13px] text-bimbel-text-mid">
      {{ description }}
    </p>
    <p
      class="mt-2.5 inline-block rounded-full px-2.5 py-0.5 text-[13px] font-semibold"
      :class="
        used
          ? 'text-bimbel-text-lo'
          : 'bg-amber-500/15 text-amber-700 dark:text-amber-300'
      "
    >
      {{ validityLabel }}
    </p>
  </div>
</template>
