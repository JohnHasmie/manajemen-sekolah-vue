# KamilEdu Web — Vue 3 port of the Flutter mobile app

Vue 3 + Vite + TypeScript + Tailwind CSS + Pinia web app that mirrors the
KamilEdu school-management Flutter app.

## Tech stack

| Concern          | Choice                                |
| ---------------- | ------------------------------------- |
| Framework        | Vue 3 (Composition API, `<script setup>`) |
| Build tool       | Vite                                  |
| Language         | TypeScript (strict)                   |
| Styling          | Tailwind CSS 3 + custom design tokens |
| State            | Pinia + pinia-plugin-persistedstate   |
| Routing          | Vue Router 4                          |
| HTTP             | axios (with Sanctum + X-School-ID interceptors) |
| i18n             | vue-i18n (id default, en fallback)    |
| Font             | Poppins (`@fontsource/poppins`)       |

## Getting started

```bash
# 1. Install
npm install

# 2. Configure
cp .env.example .env.local
# edit VITE_API_URL and VITE_AI_API_URL to point at your Laravel backends

# 3. Run dev server
npm run dev      # → http://localhost:5173

# 4. Build for production
npm run build    # → dist/
npm run preview  # serve dist locally for smoke test
```

## What's in this app

The Flutter codebase organizes screens by feature, with admin / teacher /
parent / staff variants of each feature. This Vue port follows the same
rule — **satu implementasi, tiga role** (one implementation, three role
consumers). Shared components live in `src/components/`; views are
grouped by role under `src/views/`.

Current state: **foundation + login flow complete**. The login screen
(Frame A from the Flutter design) supports:

- Email + password
- OTP verification step
- Multi-school picker step
- Multi-role picker step
- Forgot password modal
- Help request modal
- Google Sign-In stub (wiring pending in task #12)
- 401 auto-logout + reason-on-redirect

Dashboards for admin / teacher / parent / staff are currently stubbed by
`RoleHomeStub.vue`. Real implementations land per the task list — see
`CLAUDE.md` for the working contract.

## Directory layout

```
web-vue/
├── index.html
├── package.json
├── tailwind.config.ts        # role colors, slate, AppSpacing tokens
├── tsconfig.app.json         # @/ alias → ./src
├── vite.config.ts
├── env.d.ts
├── .env.example
├── CLAUDE.md                 # working contract (read this first)
└── src/
    ├── main.ts               # bootstrap (Pinia + Router + Poppins + Tailwind)
    ├── App.vue               # rehydrates auth on mount
    ├── style.css             # Tailwind imports + global resets
    ├── router/
    │   └── index.ts          # role-aware guard + redirects
    ├── stores/
    │   └── auth.ts           # Pinia store mirroring Flutter AuthState
    ├── services/
    │   └── auth.service.ts   # /auth/* endpoint wrappers
    ├── lib/
    │   ├── http.ts           # axios instances + interceptors
    │   └── storage.ts        # localStorage wrapper
    ├── types/
    │   ├── api.ts            # Laravel envelope types
    │   └── auth.ts           # AuthStep, User, Role, School
    ├── composables/
    │   └── useRoleColor.ts   # ColorUtils.getRoleColor equivalent
    ├── components/
    │   └── ui/
    │       ├── Modal.vue
    │       └── Toast.vue
    └── views/
        ├── RoleHomeStub.vue  # placeholder dashboard
        └── auth/
            ├── LoginView.vue
            └── components/
                ├── BrandBand.vue
                ├── FormCard.vue
                ├── LoginForm.vue
                ├── OtpForm.vue
                ├── SchoolPicker.vue
                ├── RolePicker.vue
                ├── ForgotPasswordModal.vue
                └── HelpRequestModal.vue
```

## Design tokens — role colors

Mirrors `lib/core/utils/color_utils.dart`:

| Token              | Hex       | Role       |
| ------------------ | --------- | ---------- |
| `bg-role-admin`    | `#1E3A8A` | Admin (navy)   |
| `bg-role-teacher`  | `#0D9488` | Guru / Wali Kelas (teal) |
| `bg-role-parent`   | `#7C3AED` | Wali Murid (violet) |
| `bg-role-staff`    | `#B45309` | Staf (amber)   |
| `bg-brand`         | `#4F46E5` | Brand primary (indigo) |

Soft variants (`bg-role-*-soft`) are used for chip/badge backgrounds.
Use the `useRoleColor(role)` composable instead of hard-coding.

## API contract

The app talks to two backends from the Flutter README:

- **Main API** (Laravel) — `VITE_API_URL`. All requests carry
  `Authorization: Bearer <token>` and `X-School-ID: <id>`.
- **AI API** (Laravel) — `VITE_AI_API_URL`. Same auth, separate base URL.

Both are wired in `src/lib/http.ts` via `api` and `aiApi` instances.
Response envelope:

```json
{ "success": true, "data": ..., "message": "..." }
```

`extractData()` unwraps the envelope; errors throw with the Indonesian
message from the backend.

## Status vocab

Backend uses `Pending / Approved / Rejected`; UI shows
`Menunggu / Disetujui / Ditolak`. Use `mapStatus()` from
`useRoleColor.ts` at the display boundary.

## Layout & port from Flutter

| Flutter (Dart)                                 | Vue equivalent                          |
| ---------------------------------------------- | --------------------------------------- |
| `lib/features/auth/.../login_screen.dart`      | `src/views/auth/LoginView.vue`          |
| `AuthController` + `AuthState`                 | `src/stores/auth.ts` (Pinia)            |
| `auth_service.dart`                            | `src/services/auth.service.ts`          |
| `dio_client.dart`                              | `src/lib/http.ts`                       |
| `color_utils.dart` → `getRoleColor`            | `src/composables/useRoleColor.ts`       |
| `snackbar_utils.dart` → showError/showSuccess  | `src/components/ui/Toast.vue`           |
| `AppBottomSheet` / `AppEditBottomSheet`        | `src/components/ui/Modal.vue` (sheet on mobile breakpoint) |
| `AppNavigator.push / pop`                      | `useRouter()` from vue-router           |

See `CLAUDE.md` for the full working contract.
