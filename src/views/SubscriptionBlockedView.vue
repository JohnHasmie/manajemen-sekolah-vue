<script setup lang="ts">
/**
 * The block page. Replaces the entire shell — no sidebar, no dashboard
 * behind it — for every role except super-admin when the tenant's
 * subscription has lapsed.
 *
 * Deliberately NOT reassuring. It carries no "data Anda aman" line:
 * the job of this page is to get the subscription renewed today, so it
 * shows what is accumulating, how many people are shut out with them,
 * and the price with the payment methods on the same screen.
 *
 * Two shapes, decided by whether the reader can actually pay:
 *   admin      → the price and "Aktifkan sekarang"
 *   everyone   → one tap that sends the admin a pre-written nudge,
 *   else         carrying the same day count. Fifteen teachers doing
 *                that on one morning outperforms any banner.
 */
import { computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';

import { useAuthStore } from '@/stores/auth';
import { useMeStore } from '@/stores/me';

const me = useMeStore();
const auth = useAuthStore();
const router = useRouter();

/** Carve-out #4: the block belongs to the TENANT, not the account. */
const otherSchools = computed(() =>
  (auth.user?.schools ?? []).filter((s: any) => String(s.id ?? s.school_id) !== auth.schoolId),
);

const schoolName = computed(() => auth.user?.school_name ?? 'Sekolah Anda');

onMounted(() => {
  // Populates `user.schools` so a multi-school user can leave. Cheap and
  // idempotent; ProfileMenu does the same on mount.
  void auth.hydrateSchoolsRoles?.();
});

async function switchSchool(id: string) {
  await auth.selectSchool(id);
  await router.replace('/');
}

const sub = computed(() => me.subscription);
const ctx = computed(() => sub.value?.blockedContext ?? null);

/** Day 0 still reads as a real number to a reader; floor at 1. */
const days = computed(() => Math.max(1, sub.value?.daysExpired ?? 1));

const canPay = computed(
  () => auth.activeRole === 'admin' || me.can('billing.subscription.manage'),
);

const isParent = computed(() => auth.activeRole === 'parent');

const accounts = computed(() => ctx.value?.accounts ?? 0);

const adminName = computed(() => ctx.value?.admin?.name ?? null);

const expiredLabel = computed(() => {
  const raw = sub.value?.expiredAt;
  if (!raw) return null;
  // Parse as a local date — `new Date('2026-08-12')` is UTC midnight and
  // renders as the 11th anywhere west of Greenwich, and as the wrong day
  // in WIB before 07:00. Build it from parts instead.
  const [y, m, d] = raw.split('-').map(Number);
  if (!y || !m || !d) return null;
  return new Date(y, m - 1, d).toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
});

const price = computed(() => {
  const amount = sub.value?.amount;
  if (typeof amount !== 'number' || amount <= 0) return null;
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(amount);
});

/**
 * The nudge. Pre-written so the sender doesn't have to compose one, and
 * carrying the day count so every message the admin receives repeats
 * the same number — a number that is larger tomorrow.
 */
const nudgeHref = computed(() => {
  const phone = ctx.value?.admin?.phone?.replace(/[^0-9]/g, '') ?? '';
  const text = isParent.value
    ? `Mohon info, aplikasi sekolah tidak bisa dibuka sejak ${expiredLabel.value ?? 'beberapa hari lalu'}.`
    : `Halo${adminName.value ? ' ' + adminName.value : ''}, KamilEdu terkunci ${days.value} hari. ` +
      `Saya belum bisa memakainya untuk mengajar.`;

  if (phone) {
    const wa = phone.startsWith('0') ? '62' + phone.slice(1) : phone;
    return `https://wa.me/${wa}?text=${encodeURIComponent(text)}`;
  }
  const email = ctx.value?.admin?.email;
  if (email) {
    return `mailto:${email}?subject=${encodeURIComponent('KamilEdu terkunci')}&body=${encodeURIComponent(text)}`;
  }
  return null;
});

/** Everything a role can still reach — see the four carve-outs. */
async function logout() {
  await auth.logout();
  await router.replace('/login');
}
</script>

<template>
  <main class="blocked" data-testid="subscription-blocked">
    <div class="inner">
      <!-- who is looking at this, so a multi-school user knows WHICH tenant -->
      <header class="tenant">
        <span class="mark">{{ schoolName.charAt(0).toUpperCase() }}</span>
        <span class="who">
          <b>{{ schoolName }}</b>
          <span>{{ me.snapshot?.user.name }}</span>
        </span>
      </header>

      <!-- the hook: the only number that moves on its own -->
      <section class="counter" data-testid="blocked-counter">
        <p class="days"><b>{{ days }}</b><span>hari terkunci</span></p>
        <p class="since" v-if="expiredLabel">
          sejak {{ expiredLabel }} · bertambah tiap hari
        </p>
        <p class="others" v-if="accounts > 0" data-testid="blocked-accounts">
          <b>{{ accounts }}</b> akun ikut terkunci
          <span v-if="ctx">— {{ ctx.teachers }} guru · {{ ctx.staff }} staf</span>
        </p>
      </section>

      <h1 v-if="canPay">Sekolah Anda tidak bisa dipakai sampai langganan diaktifkan</h1>
      <h1 v-else-if="isParent">Anda tidak bisa memantau perkembangan anak</h1>
      <h1 v-else>Langganan sekolah belum diperpanjang</h1>

      <!-- what the delay costs, restated every day it continues -->
      <section class="piles">
        <p class="label">Yang menumpuk setiap hari tertunda</p>
        <ul>
          <template v-if="canPay">
            <li>Presensi hari ini tidak tercatat — dan tidak bisa dimundurkan</li>
            <li v-if="ctx">{{ ctx.teachers }} guru tidak bisa input nilai; pekerjaannya menumpuk</li>
            <li>Tagihan SPP bulan ini tidak terbit</li>
          </template>
          <template v-else-if="isParent">
            <li>Presensi harian tidak terlihat</li>
            <li>Nilai &amp; rapor tidak terbuka</li>
            <li>Tagihan dan pengumuman tidak masuk</li>
          </template>
          <template v-else>
            <li>Presensi dan nilai tidak bisa diinput</li>
            <li>Materi dan RPP tidak bisa dibuka</li>
            <li>Pekerjaan menumpuk sampai langganan aktif</li>
          </template>
        </ul>
      </section>

      <!-- admin: the price, the method, and the promise, on this screen -->
      <section v-if="canPay" class="pay" data-testid="blocked-pay">
        <p class="plan">Paket berlangganan · bulanan</p>
        <p class="amount" v-if="price"><b>{{ price }}</b><span>/ bulan</span></p>
        <RouterLink class="cta" to="/subscribe" data-testid="blocked-renew">
          Aktifkan sekarang
        </RouterLink>
        <p class="fine">Transfer bank · QRIS · Virtual Account — aktif kembali beberapa menit setelah bayar</p>
      </section>

      <!-- everyone else: one tap that puts pressure where it can act -->
      <section v-else class="nudge" data-testid="blocked-nudge">
        <div v-if="adminName" class="admin">
          <span class="av">{{ adminName.charAt(0) }}</span>
          <span>
            <b>{{ adminName }}</b>
            <small>Admin sekolah</small>
          </span>
        </div>
        <a v-if="nudgeHref" class="cta" :href="nudgeHref" target="_blank" rel="noopener">
          {{ isParent ? 'Tanyakan ke sekolah' : 'Ingatkan admin sekarang' }}
        </a>
        <p v-else class="fine">
          Hubungi admin sekolah Anda untuk mengaktifkan kembali langganan.
        </p>
      </section>

      <!-- carve-outs #3 and #4: always reachable -->
      <footer class="escape">
        <button
          v-for="s in otherSchools"
          :key="String(s.id ?? s.school_id)"
          type="button"
          data-testid="blocked-switch-school"
          @click="switchSchool(String(s.id ?? s.school_id))"
        >
          Pindah ke {{ s.name ?? s.school_name }}
        </button>
        <button type="button" data-testid="blocked-logout" @click="logout">Keluar</button>
      </footer>
    </div>
  </main>
</template>

<style scoped>
.blocked {
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 40px 20px 64px;
  background: #f7f8fb;
}
.inner { width: 100%; max-width: 560px; }

.tenant { display: flex; gap: 10px; align-items: center; padding-bottom: 16px; border-bottom: 1px solid #e2e8f0; }
.tenant .mark {
  width: 34px; height: 34px; border-radius: 9px; background: #143068; color: #fff;
  display: grid; place-items: center; font-weight: 800; flex: none;
}
.tenant .who b { display: block; font-size: 14.5px; color: #0f172a; }
.tenant .who span { font-size: 12.5px; color: #7c8aa0; }

.counter {
  margin: 24px 0 0; padding: 16px 18px; border-radius: 12px;
  background: #fdf2f5; border: 1.5px solid #f0c4d2;
}
.counter .days { margin: 0; display: flex; align-items: baseline; gap: 10px; }
.counter .days b { font-size: 46px; font-weight: 820; color: #9f1239; line-height: 1; font-variant-numeric: tabular-nums; }
.counter .days span { font-size: 16px; font-weight: 700; color: #9f1239; }
.counter .since { margin: 6px 0 0; font-size: 13px; color: #475569; }
.counter .others { margin: 10px 0 0; font-size: 13px; color: #9f1239; }
.counter .others b { font-variant-numeric: tabular-nums; }
.counter .others span { color: #475569; }

h1 { font-size: 27px; line-height: 1.18; letter-spacing: -0.02em; font-weight: 780; margin: 22px 0 0; color: #0f172a; }

.piles { margin-top: 20px; }
.piles .label {
  font-size: 10.5px; letter-spacing: 0.09em; text-transform: uppercase;
  color: #9f1239; margin: 0 0 8px; font-weight: 600;
}
.piles ul { margin: 0; padding-left: 18px; }
.piles li { font-size: 13.5px; color: #0f172a; margin-bottom: 5px; }

.pay, .nudge {
  margin-top: 24px; padding: 18px; border-radius: 12px;
  background: #fff; border: 1px solid #e2e8f0;
}
.pay .plan { margin: 0; font-size: 12.5px; color: #7c8aa0; }
.pay .amount { margin: 6px 0 14px; display: flex; align-items: baseline; gap: 8px; }
.pay .amount b { font-size: 30px; font-weight: 820; letter-spacing: -0.02em; color: #0f172a; font-variant-numeric: tabular-nums; }
.pay .amount span { font-size: 13px; color: #7c8aa0; }
.pay .fine, .nudge .fine { margin: 12px 0 0; font-size: 12px; color: #7c8aa0; }

.cta {
  display: block; text-align: center; text-decoration: none;
  background: #9f1239; color: #fff; font-weight: 700; font-size: 15px;
  padding: 13px 18px; border-radius: 10px;
}
.cta:focus-visible { outline: 3px solid #143068; outline-offset: 2px; }

.nudge .admin { display: flex; gap: 11px; align-items: center; margin-bottom: 14px; }
.nudge .av {
  width: 34px; height: 34px; border-radius: 50%; background: #f1f5f9; color: #475569;
  display: grid; place-items: center; font-weight: 700; flex: none;
}
.nudge .admin b { display: block; font-size: 13.5px; color: #0f172a; }
.nudge .admin small { font-size: 11.5px; color: #7c8aa0; }

.escape {
  margin-top: 22px; padding-top: 16px; border-top: 1px solid #e2e8f0;
  display: flex; gap: 18px; font-size: 12.5px;
}
.escape a, .escape button {
  color: #7c8aa0; background: none; border: none; padding: 0;
  font: inherit; cursor: pointer; text-decoration: underline;
}
</style>
