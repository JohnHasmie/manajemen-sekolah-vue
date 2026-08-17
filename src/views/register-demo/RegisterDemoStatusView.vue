<script setup lang="ts">
/**
 * Where the demo wizard actually ends.
 *
 * Pressing "Kirim" does not activate anything: it records a PENDING
 * `demo_requests` row that the KamilEdu team verifies by hand before
 * notifying the requester. So there is no dashboard to go to — the
 * school does not exist yet.
 *
 * This replaces the old ending, which had two contradictory surfaces:
 * a modal whose only button just closed itself, and a panel that sent a
 * brand-new user to /login (after `handleSend` had already logged them
 * out) or an existing user to a DIFFERENT school's dashboard. Both read
 * as "your registration failed".
 *
 * A route rather than a modal on purpose: verification takes hours, a
 * modal dies on refresh, and the WhatsApp/email notification needs
 * somewhere to link to.
 *
 * Reads `GET /demo/my-registrations`, which already existed for the
 * tenant-choice screen — no new endpoint.
 */
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';

import { DemoService } from '@/services/demo.service';
import { useAuthStore } from '@/stores/auth';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import type { ActiveSchoolItem, DemoRegistrationItem } from '@/types/demo';

const router = useRouter();
const auth = useAuthStore();
const wizard = useDemoWizardStore();

const loading = ref(true);
const requests = ref<DemoRegistrationItem[]>([]);
const activeSchools = ref<ActiveSchoolItem[]>([]);

/**
 * The request this page is about: the newest one. A user who registers a
 * second institution while the first is still pending sees the newest,
 * which is the one they just finished.
 */
const request = computed<DemoRegistrationItem | null>(() => requests.value[0] ?? null);

const status = computed(() => request.value?.status ?? 'pending');
const schoolName = computed(() => request.value?.school_name || 'Institusi Anda');

/** Built from parts — `new Date('2026-08-14')` is UTC and can render as the 13th in WIB. */
function formatDate(iso: string | null): string | null {
  if (!iso) return null;
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return null;
  return d.toLocaleDateString('id-ID', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

const submittedAt = computed(() => formatDate(request.value?.created_at ?? null));
const expiresAt = computed(() => formatDate(request.value?.demo_expires_at ?? null));

const daysLeft = computed(() => {
  const raw = request.value?.demo_expires_at;
  if (!raw) return null;
  const ms = new Date(raw).getTime() - Date.now();
  if (Number.isNaN(ms)) return null;
  return Math.max(0, Math.ceil(ms / 86_400_000));
});

/** Schools this account can already open — never the pending demo. */
const otherSchools = computed(() => activeSchools.value);

/**
 * The one contact we can state without inventing a field: the account
 * the request was filed from. `my-registrations` carries no phone.
 */
const contactEmail = computed(() => auth.user?.email ?? null);

async function load() {
  loading.value = true;
  try {
    const res = await DemoService.getMyRegistrations();
    requests.value = res.demo_requests ?? [];
    activeSchools.value = res.active_schools ?? [];
  } finally {
    loading.value = false;
  }
}

onMounted(load);

function enterDemo() {
  // Only reachable once the request is approved, i.e. the school is real.
  wizard.clearLocalProgress();
  router.replace('/');
}

function openSchool() {
  router.replace('/');
}

function fixAndResend() {
  const t = request.value?.tenant_type;
  router.push(
    t === 'tutoring' || t === 'bimbel'
      ? '/register-demo/conversational'
      : '/register-demo',
  );
}

async function logout() {
  wizard.clearLocalProgress();
  await auth.logout();
  await router.replace('/login');
}
</script>

<template>
  <main class="status-page" data-testid="demo-request-status">
    <div class="inner">
      <p v-if="loading" class="loading">Memuat status permintaan…</p>

      <template v-else-if="request">
        <!-- ── state chip ── -->
        <span class="chip" :class="status" data-testid="demo-status-chip">
          <template v-if="status === 'pending'">Menunggu verifikasi</template>
          <template v-else-if="status === 'approved'">Sudah aktif</template>
          <template v-else-if="status === 'rejected'">Perlu diperbaiki</template>
          <template v-else>Masa demo berakhir</template>
        </span>

        <!-- ── headline ── -->
        <h1 v-if="status === 'pending'">Permintaan demo Anda sudah kami terima</h1>
        <h1 v-else-if="status === 'approved'">{{ schoolName }} siap dipakai</h1>
        <h1 v-else-if="status === 'rejected'">Kami belum bisa memverifikasi data Anda</h1>
        <h1 v-else>Masa demo {{ schoolName }} sudah berakhir</h1>

        <p class="sub">
          {{ schoolName }}
          <template v-if="submittedAt"> · dikirim {{ submittedAt }}</template>
        </p>

        <!-- ── pending: the timeline ── -->
        <ol v-if="status === 'pending'" class="timeline" data-testid="demo-status-timeline">
          <li class="done">
            <b>Permintaan terkirim</b>
            <span v-if="submittedAt">{{ submittedAt }}</span>
          </li>
          <li class="now">
            <b>Diverifikasi tim KamilEdu</b>
            <span>Kami menghubungi Anda lewat WhatsApp atau email begitu selesai.</span>
          </li>
          <li>
            <b>Sekolah demo diaktifkan</b>
            <span>Aktif 7 hari sejak diaktifkan.</span>
          </li>
        </ol>

        <p v-if="status === 'pending' && contactEmail" class="contact">
          Kabar dikirim ke <b>{{ contactEmail }}</b> dan nomor WhatsApp yang Anda isi.
        </p>

        <!-- ── approved ── -->
        <p v-if="status === 'approved'" class="sub">
          <template v-if="expiresAt">Aktif sampai {{ expiresAt }}</template>
          <template v-if="daysLeft !== null"> · sisa {{ daysLeft }} hari</template>
        </p>

        <!-- ── rejected ── -->
        <p v-if="status === 'rejected'" class="sub">
          Perbaiki data Anda lalu kirim ulang — jawaban wizard masih tersimpan.
        </p>

        <!-- ── actions ── -->
        <div class="actions">
          <button
            v-if="status === 'approved'"
            type="button"
            class="cta"
            data-testid="demo-status-enter"
            @click="enterDemo"
          >
            Masuk ke sekolah demo
          </button>

          <button
            v-else-if="status === 'rejected'"
            type="button"
            class="cta"
            data-testid="demo-status-fix"
            @click="fixAndResend"
          >
            Perbaiki &amp; kirim ulang
          </button>

          <button
            v-else-if="status === 'pending'"
            type="button"
            class="cta"
            data-testid="demo-status-refresh"
            @click="load"
          >
            Cek status
          </button>

          <!-- Only for an account that already has a school. Named, so it
               never reads as "open the demo I just registered". -->
          <button
            v-for="s in otherSchools"
            :key="String(s.id)"
            type="button"
            class="ghost"
            data-testid="demo-status-other-school"
            @click="openSchool"
          >
            Ke {{ s.name }} (sekolah lain)
          </button>
        </div>

        <p class="foot">
          Anda tetap masuk. Halaman ini bisa dibuka lagi kapan saja.
          <button type="button" class="link" data-testid="demo-status-logout" @click="logout">
            Keluar
          </button>
        </p>
      </template>

      <!-- No request at all — someone opened the URL directly. -->
      <template v-else>
        <h1>Belum ada permintaan demo</h1>
        <p class="sub">Mulai dari awal untuk mendaftarkan institusi Anda.</p>
        <div class="actions">
          <button type="button" class="cta" @click="router.replace('/register-demo')">
            Daftar demo
          </button>
        </div>
      </template>
    </div>
  </main>
</template>

<style scoped>
.status-page {
  min-height: 100vh;
  display: flex;
  justify-content: center;
  padding: 48px 20px 64px;
  background: #f7f8fb;
}
.inner { width: 100%; max-width: 560px; }
.loading { color: #7c8aa0; font-size: 14px; }

.chip {
  display: inline-flex;
  align-items: center;
  font-size: 11px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  font-weight: 700;
  padding: 5px 12px;
  border-radius: 20px;
  border: 1px solid;
}
.chip.pending { color: #b45309; background: #fef6e7; border-color: #f0d6a8; }
.chip.approved { color: #0f766e; background: #e6f4f1; border-color: #0f766e; }
.chip.rejected { color: #9f1239; background: #fdf2f5; border-color: #f0c4d2; }
.chip.expired { color: #475569; background: #f1f5f9; border-color: #e2e8f0; }

h1 {
  font-size: 27px;
  line-height: 1.18;
  letter-spacing: -0.02em;
  font-weight: 780;
  margin: 18px 0 8px;
  color: #0f172a;
}
.sub { margin: 0 0 4px; font-size: 14px; color: #475569; }
.contact { margin: 14px 0 0; font-size: 13px; color: #475569; }
.contact b { color: #0f172a; }

.timeline { list-style: none; margin: 24px 0 0; padding: 0; }
.timeline li {
  position: relative;
  padding: 0 0 20px 28px;
  border-left: 2px solid #e2e8f0;
}
.timeline li:last-child { border-left-color: transparent; padding-bottom: 0; }
.timeline li::before {
  content: '';
  position: absolute;
  left: -8px;
  top: 2px;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: #fff;
  border: 2px solid #e2e8f0;
}
.timeline li.done { border-left-color: #0f766e; }
.timeline li.done::before { background: #0f766e; border-color: #0f766e; }
.timeline li.now::before { border-color: #b45309; background: #fef6e7; }
.timeline b { display: block; font-size: 13.5px; color: #0f172a; }
.timeline span { display: block; font-size: 12.5px; color: #7c8aa0; margin-top: 2px; }
.timeline li.now span { color: #b45309; }

.actions { display: flex; flex-direction: column; gap: 10px; margin-top: 26px; }
.cta, .ghost {
  font: inherit;
  font-size: 14px;
  font-weight: 650;
  padding: 12px 18px;
  border-radius: 10px;
  cursor: pointer;
  border: 1px solid transparent;
}
.cta { background: #143068; color: #fff; }
.ghost { background: #fff; color: #475569; border-color: #e2e8f0; }
.cta:focus-visible, .ghost:focus-visible { outline: 3px solid #143068; outline-offset: 2px; }

.foot { margin-top: 22px; font-size: 12.5px; color: #7c8aa0; }
.link {
  font: inherit;
  background: none;
  border: none;
  padding: 0;
  color: #7c8aa0;
  text-decoration: underline;
  cursor: pointer;
}
</style>
