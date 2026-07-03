<!--
  TenantPickerHero.vue — landing hero + tenant card grid for the
  /subscribe entry surface. Matches mockup 1
  (subscribe_page_tenant_detection).

  Renders each of the user's demo tenants as a rich card with a
  status pill, seat stats, remaining-days meter, and a per-status
  CTA.
-->
<script setup lang="ts">
import { computed } from 'vue';
import type { SubscriptionTenant } from '@/types/subscription-billing';

const props = defineProps<{
  userName: string;
  tenants: SubscriptionTenant[];
  loading?: boolean;
}>();

defineEmits<{
  select: [tenant: SubscriptionTenant];
  newTenant: [];
  exportData: [tenant: SubscriptionTenant];
}>();

interface CardModel {
  tenant: SubscriptionTenant;
  status: 'active' | 'warn' | 'expired';
  statusLabel: string;
  statusIcon: string;
  meterLabel: { left: string; right: string };
  meterClass: 'good' | 'warn' | 'bad';
  ctaLabel: string;
  ctaIcon: string;
  ctaClass: 'primary' | 'warn' | 'danger';
  avatarClass: 'sch' | 'tut' | 'exp';
  avatarInitials: string;
  subtypeLabel: string;
  subtypeIcon: string;
  seatUnit: string;
  staffUnit: string;
}

function daysBetween(iso?: string | null): number | null {
  if (!iso) return null;
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return null;
  const now = Date.now();
  const diffMs = then - now;
  return Math.round(diffMs / (1000 * 60 * 60 * 24));
}

function initials(name: string): string {
  const parts = name.split(/\s+/).filter(Boolean).slice(0, 2);
  return parts.map((p) => p[0]).join('').toUpperCase() || '?';
}

const cards = computed<CardModel[]>(() =>
  props.tenants.map((t) => {
    const isBimbel = t.tenant_type === 'bimbel';
    const days = daysBetween(t.subscription_expires_at);
    const isExpired = t.subscription_status === 'expired';
    const isWarn = !isExpired && days !== null && days <= 2;

    const status = isExpired ? 'expired' : isWarn ? 'warn' : 'active';
    const meterClass = isExpired ? 'bad' : isWarn ? 'warn' : 'good';

    return {
      tenant: t,
      status,
      statusLabel:
        status === 'active'
          ? 'Demo aktif'
          : status === 'warn'
          ? 'Segera habis'
          : 'Kadaluarsa',
      statusIcon:
        status === 'active'
          ? ''
          : status === 'warn'
          ? 'alert-triangle'
          : 'lock',
      meterLabel: {
        left:
          status === 'active'
            ? `${days ?? '—'} hari lagi`
            : status === 'warn'
            ? `${days ?? 1} hari lagi`
            : `Berakhir ${Math.abs(days ?? 0)} hari lalu`,
        right:
          status === 'expired'
            ? 'Data disimpan 30 hari'
            : t.subscription_expires_at
            ? `Demo berakhir ${new Intl.DateTimeFormat('id-ID', {
                day: 'numeric', month: 'long', year: 'numeric',
              }).format(new Date(t.subscription_expires_at))}`
            : '',
      },
      meterClass,
      ctaLabel:
        status === 'active'
          ? 'Lanjutkan berlangganan'
          : status === 'warn'
          ? 'Konversi sebelum habis'
          : 'Aktifkan kembali',
      ctaIcon:
        status === 'active'
          ? 'arrow-right'
          : status === 'warn'
          ? 'clock-play'
          : 'refresh',
      ctaClass: status === 'warn' ? 'warn' : status === 'expired' ? 'danger' : 'primary',
      avatarClass: status === 'expired' ? 'exp' : isBimbel ? 'tut' : 'sch',
      avatarInitials: initials(t.name),
      subtypeLabel: isBimbel ? 'Bimbel' : 'Sekolah',
      subtypeIcon: isBimbel ? 'books' : 'school',
      seatUnit: 'siswa',
      staffUnit: isBimbel ? 'tutor' : 'guru/staf',
    };
  }),
);

const activeCount = computed(
  () => cards.value.filter((c) => c.status === 'active').length,
);
const expiredCount = computed(
  () => cards.value.filter((c) => c.status === 'expired').length,
);
</script>

<template>
  <div class="tp-root">
    <div class="tp-hero">
      <div class="tp-hero-kicker">
        Selamat datang kembali, {{ userName }}
      </div>
      <h1 class="tp-hero-h1">
        <span class="n">{{ tenants.length }} tenant demo</span>
        terdeteksi di akun Anda
      </h1>
      <p class="tp-hero-sub">
        Pilih tenant yang ingin dilanjutkan ke langganan berbayar. Data
        siswa, guru, dan riwayat yang sudah ada akan otomatis terbawa —
        Anda tinggal pilih modul yang dipakai dan cara bayar.
      </p>
    </div>

    <div class="tp-tenants">
      <div class="tp-tsec-head">
        <span class="tp-tsec-lbl">Demo Anda</span>
        <span class="tp-tsec-count">
          {{ tenants.length }} tenant · {{ activeCount }} aktif ·
          {{ expiredCount }} kadaluarsa
        </span>
      </div>

      <div class="tp-tcards">
        <div
          v-for="c in cards"
          :key="c.tenant.id"
          class="tp-tcard"
          :class="{ 'is-expired': c.status === 'expired' }"
        >
          <div class="tp-tcard-head">
            <div class="tp-tavatar" :class="c.avatarClass">
              {{ c.avatarInitials }}
            </div>
            <div>
              <div class="tp-tname">{{ c.tenant.name }}</div>
              <div class="tp-tsub">
                <i
                  :class="`ti ti-${c.subtypeIcon}`"
                  style="font-size: 12px"
                  aria-hidden="true"
                />
                {{ c.subtypeLabel }}
              </div>
            </div>
            <span class="tp-tpill" :class="c.status">
              <span
                v-if="c.status === 'active'"
                class="tp-pill-dot"
              />
              <i
                v-else
                :class="`ti ti-${c.statusIcon}`"
                style="font-size: 11px"
                aria-hidden="true"
              />
              {{ c.statusLabel }}
            </span>
          </div>

          <div class="tp-tstats">
            <div class="tp-tstat">
              <i
                class="ti ti-users tp-tstat-i"
                aria-hidden="true"
              />
              <span class="tp-tstat-n">{{ c.tenant.student_count }}</span>
              {{ c.seatUnit }}
            </div>
            <div class="tp-tstat">
              <i
                class="ti ti-user-square tp-tstat-i"
                aria-hidden="true"
              />
              <span class="tp-tstat-n">{{ c.tenant.staff_count }}</span>
              {{ c.staffUnit }}
            </div>
          </div>

          <div class="tp-tmeter">
            <div class="tp-tmeter-lbl">
              <span :class="{
                'warn-text': c.status === 'warn',
                'bad-text': c.status === 'expired',
              }">{{ c.meterLabel.left }}</span>
              <span>{{ c.meterLabel.right }}</span>
            </div>
            <div class="tp-tmeter-bar">
              <div class="tp-tmeter-fill" :class="c.meterClass" />
            </div>
          </div>

          <div class="tp-tcta">
            <button
              type="button"
              class="tp-tbtn"
              :class="c.ctaClass"
              @click="$emit('select', c.tenant)"
            >
              <i
                :class="`ti ti-${c.ctaIcon}`"
                style="font-size: 13px"
                aria-hidden="true"
              />
              {{ c.ctaLabel }}
            </button>
            <button
              v-if="c.status === 'expired'"
              type="button"
              class="tp-tbtn ghost"
              aria-label="Ekspor data"
              @click="$emit('exportData', c.tenant)"
            >
              <i
                class="ti ti-download"
                style="font-size: 14px"
                aria-hidden="true"
              />
            </button>
          </div>
        </div>
      </div>

      <button type="button" class="tp-newstrip" @click="$emit('newTenant')">
        <div class="tp-newstrip-icon">
          <i class="ti ti-plus" aria-hidden="true" />
        </div>
        <div>
          <div class="tp-newstrip-title">
            Atau daftarkan sekolah / bimbel baru
          </div>
          <div class="tp-newstrip-desc">
            Belum punya tenant demo di sini? Bikin akun berbayar langsung
            tanpa periode uji coba.
          </div>
        </div>
        <div class="tp-newstrip-cta">
          Bikin tenant baru
          <i
            class="ti ti-arrow-right"
            style="font-size: 13px"
            aria-hidden="true"
          />
        </div>
      </button>
    </div>
  </div>
</template>

<style scoped>
.tp-root { }

.tp-hero {
  padding: 28px 22px 20px;
  background: linear-gradient(180deg, #FBFDFF 0%, #FBFCFE 100%);
}
.tp-hero-kicker {
  font-size: 10.5px; font-weight: 600;
  letter-spacing: 0.8px; text-transform: uppercase;
  color: #1B6FB8;
}
.tp-hero-h1 {
  font-size: 24px; font-weight: 500;
  letter-spacing: -0.4px;
  margin: 6px 0;
  color: #0F172A;
}
.tp-hero-h1 .n {
  background: linear-gradient(135deg, #1B6FB8 0%, #113E75 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  font-weight: 600;
}
.tp-hero-sub {
  font-size: 12.5px; color: #64748B;
  line-height: 1.55; max-width: 520px;
}

.tp-tenants { padding: 8px 22px 22px; }
.tp-tsec-head {
  display: flex; align-items: center;
  margin: 12px 0 10px; gap: 8px;
}
.tp-tsec-lbl {
  font-size: 10.5px; font-weight: 600;
  letter-spacing: 0.6px; text-transform: uppercase;
  color: #64748B;
}
.tp-tsec-count {
  font-size: 10.5px; color: #94A3B8;
  margin-left: auto;
}

.tp-tcards {
  display: grid; grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.tp-tcard {
  background: #FFFFFF;
  border: 0.5px solid #E2E8F0;
  border-radius: 12px;
  padding: 14px;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04);
  transition: box-shadow 0.15s;
  position: relative; overflow: hidden;
}
.tp-tcard:hover {
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.06),
              0 8px 24px rgba(15, 23, 42, 0.04);
}
.tp-tcard.is-expired {
  background: #FDFAFA;
  border-color: #F5B5B5;
}

.tp-tcard-head { display: flex; align-items: flex-start; gap: 10px; }
.tp-tavatar {
  width: 42px; height: 42px; border-radius: 10px;
  display: grid; place-items: center;
  font-weight: 600; font-size: 14px;
  letter-spacing: 0.3px;
  flex-shrink: 0;
}
.tp-tavatar.sch { background: #E6F1FB; color: #113E75; }
.tp-tavatar.tut { background: #EAF3DE; color: #27500A; }
.tp-tavatar.exp { background: #FEE2E2; color: #7F1D1D; }
.tp-tname { font-size: 14px; font-weight: 500; color: #0F172A; letter-spacing: -0.1px; }
.tp-tsub {
  font-size: 11px; color: #64748B;
  margin-top: 2px;
  display: flex; align-items: center; gap: 5px;
}

.tp-tpill {
  font-size: 10px; font-weight: 500;
  padding: 3px 8px; border-radius: 999px;
  margin-left: auto;
  letter-spacing: 0.2px;
  display: inline-flex; align-items: center; gap: 4px;
  flex-shrink: 0;
}
.tp-tpill.active { background: #DCFCE7; color: #085041; }
.tp-tpill.warn { background: #FEF3C7; color: #78350F; }
.tp-tpill.expired { background: #FEE2E2; color: #7F1D1D; }
.tp-pill-dot {
  width: 6px; height: 6px; border-radius: 50%;
  background: #1D9E75;
}

.tp-tstats {
  display: flex; align-items: center; gap: 14px;
  margin-top: 12px; padding-top: 12px;
  border-top: 0.5px solid #F1F5F9;
}
.tp-tstat {
  display: flex; align-items: center; gap: 6px;
  font-size: 11.5px; color: #475569;
}
.tp-tstat-n { font-weight: 500; color: #0F172A; }
.tp-tstat-i { color: #94A3B8; font-size: 14px; }

.tp-tmeter { margin-top: 10px; }
.tp-tmeter-lbl {
  display: flex; justify-content: space-between;
  font-size: 10.5px; color: #64748B; margin-bottom: 4px;
}
.tp-tmeter-lbl .warn-text { color: #B45309; }
.tp-tmeter-lbl .bad-text { color: #991B1B; }
.tp-tmeter-bar {
  height: 5px; background: #F1F5F9;
  border-radius: 3px;
  position: relative; overflow: hidden;
}
.tp-tmeter-fill {
  position: absolute; left: 0; top: 0; bottom: 0;
  border-radius: 3px;
}
.tp-tmeter-fill.good {
  background: linear-gradient(90deg, #1D9E75 0%, #5DCAA5 100%);
  width: 71%;
}
.tp-tmeter-fill.warn {
  background: linear-gradient(90deg, #BA7517 0%, #EF9F27 100%);
  width: 22%;
}
.tp-tmeter-fill.bad {
  background: linear-gradient(90deg, #A32D2D 0%, #E24B4A 100%);
  width: 100%;
}

.tp-tcta { margin-top: 12px; display: flex; align-items: center; gap: 8px; }
.tp-tbtn {
  flex: 1;
  padding: 8px 12px;
  border-radius: 8px;
  font-size: 11.5px; font-weight: 500;
  border: none;
  cursor: pointer;
  display: flex; align-items: center; justify-content: center; gap: 5px;
}
.tp-tbtn.primary { background: #1B6FB8; color: #fff; }
.tp-tbtn.primary:hover { background: #185FA5; }
.tp-tbtn.warn { background: #B45309; color: #fff; }
.tp-tbtn.warn:hover { background: #92400E; }
.tp-tbtn.danger { background: #DC2626; color: #fff; }
.tp-tbtn.danger:hover { background: #B91C1C; }
.tp-tbtn.ghost {
  background: #FFFFFF; color: #475569;
  border: 0.5px solid #CBD5E1;
  max-width: 36px; padding: 8px;
}

.tp-newstrip {
  margin: 18px 0 0;
  padding: 14px 16px;
  background: #FFFFFF;
  border: 0.5px dashed #C7D2E1;
  border-radius: 12px;
  display: flex; align-items: center; gap: 12px;
  width: 100%;
  cursor: pointer; text-align: left;
}
.tp-newstrip:hover { border-color: #94A3B8; background: #FBFDFF; }
.tp-newstrip-icon {
  width: 36px; height: 36px; border-radius: 10px;
  background: #F5F8FC; color: #64748B;
  display: grid; place-items: center;
  font-size: 18px;
  flex-shrink: 0;
}
.tp-newstrip-title { font-size: 12.5px; font-weight: 500; color: #0F172A; }
.tp-newstrip-desc { font-size: 11px; color: #64748B; margin-top: 1px; }
.tp-newstrip-cta {
  margin-left: auto;
  padding: 7px 12px;
  background: transparent;
  border: 0.5px solid #CBD5E1;
  border-radius: 8px;
  font-size: 11.5px; color: #475569;
  font-weight: 500;
  display: flex; align-items: center; gap: 5px;
}
</style>
