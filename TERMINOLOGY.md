# KamilEdu Web — Terminology Canon

Indonesian user-facing wording is inconsistent across screens (e.g.
"Kehadiran" vs "Absensi" vs "Presensi"). This doc records the canonical
term per concept so new/edited copy converges. It is a **convention**, not
a migration mandate — do NOT mass-rename existing strings (many are shared
i18n keys; a blind swap risks breaking screens that reuse the same key).
Prefer the canon for new copy and fix only glaring same-screen clashes.

## Attendance

| Concept                                   | Canonical term    | Notes |
|-------------------------------------------|-------------------|-------|
| School attendance (sekolah)               | **Kehadiran**     | Student/teacher daily presence in the school tenant. The dominant existing term (~78 uses). |
| Bimbel session attendance (tutoring)      | **Absensi Sesi**  | Per-session presence in the tutoring/bimbel tenant (peserta hadir/izin/absen per sesi). |
| Bimbel entry-gate presence (QR di pintu)  | **Absensi Gerbang** | Daily QR check-in at the entrance gate. Distinct from per-session attendance. |

### Rationale
- **Kehadiran** is the school-tenant default and already dominates the
  codebase; leave school screens on it.
- **Absensi Sesi** scopes the tutoring flow's per-session presence and
  disambiguates it from the school's "Kehadiran".
- Avoid stacking the two attendance words together ("Absensi Kehadiran"
  reads as "attendance attendance"). One attendance noun per label.

## Actors

| Concept              | School tenant | Bimbel tenant |
|----------------------|---------------|---------------|
| Learner              | Siswa         | Peserta       |
| Instructor           | Guru          | Tutor         |

Bimbel vocabulary is applied through `BIMBEL_LABEL_OVERRIDES` in
`src/components/subscribe/moduleTokens.ts` — extend the override map rather
than hardcoding peserta/tutor wording inline.

## What this wave changed vs documented

- **Documented** (this file): the canon above; no mass string rename.
- **Fixed** (trivially safe, same-file, single-use, no i18n-key impact):
  `attendance_gate.label` in `moduleTokens.ts` went from the redundant
  `'Absensi Kehadiran Peserta'` → `'Absensi Gerbang Peserta'`.

Everything else is left as-is and should converge toward this canon over
time, per screen, when that screen is next touched.
