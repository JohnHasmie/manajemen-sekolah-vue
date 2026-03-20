# KamilEdu - School Management Mobile App

A comprehensive Flutter mobile application for school management (Manajemen Sekolah) built for the KamilEdu platform. Supports 4 user roles with distinct dashboards and features.

## Table of Contents
- [Overview](#overview)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Features by Role](#features-by-role)
- [API Connections](#api-connections)
- [State Management](#state-management)
- [Navigation & Routing](#navigation--routing)
- [Services Layer](#services-layer)
- [Models](#models)
- [Components & Widgets](#components--widgets)
- [Utilities](#utilities)
- [Firebase Integration](#firebase-integration)
- [Authentication Flow](#authentication-flow)
- [Caching Strategy](#caching-strategy)
- [Localization](#localization)
- [Testing](#testing)
- [Setup & Running](#setup--running)

---

## Overview

KamilEdu is a school management platform that provides:
- **Admin**: Full school management (students, teachers, classes, finance, reports, settings)
- **Teacher (Guru)**: Attendance, grading, class activities, materials, lesson plans (RPP), AI recommendations
- **Staff**: Administration, student data, inventory, correspondence
- **Parent (Wali Murid)**: View child's attendance, grades, billing, announcements, report cards

The app connects to two backend services:
1. **Main API** (Laravel) - Core CRUD operations, authentication, school management
2. **AI API** (Laravel) - AI-powered features: learning recommendations, material generation, lesson plan generation

## Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Flutter 3.x (Dart SDK ^3.9.0) |
| State Management | Provider (ChangeNotifier) |
| HTTP Client | `http` package |
| Local Storage | SharedPreferences |
| Authentication | Laravel Sanctum tokens + Google Sign-In |
| Push Notifications | Firebase Cloud Messaging (FCM) |
| Analytics | Firebase Analytics |
| Performance | Firebase Performance Monitoring |
| PDF Generation | Syncfusion Flutter PDF |
| Excel Export | Syncfusion Flutter XlsIO |
| Rich Text Editor | Flutter Quill |
| Font | Poppins (Regular + Bold) |
| Environment | flutter_dotenv (.env file) |

## Architecture

### Current Pattern
The app uses a **feature-by-role** organization with a service-based data layer:

```
UI Layer (Screens)  →  Services Layer (API calls)  →  Backend APIs
     ↕                       ↕
  Provider              SharedPreferences
(State Management)      (Local Cache)
```

### How it maps to Laravel concepts:
- **Screens** = Laravel Blade views / Vue components (UI rendering + some logic)
- **Services** = Laravel Service classes (API communication)
- **Models** = Laravel Eloquent Models (data structures, but simpler - just PODOs)
- **Providers** = Similar to Vue's Vuex store (global reactive state)
- **Components** = Vue reusable components (shared UI elements)
- **Utils** = Laravel Helper functions

### Key architectural notes:
- Screens are **StatefulWidgets** that manage their own state via `setState()`
- API calls are made directly from screens through service classes
- Only 2 global providers exist (AcademicYearProvider, TeacherProvider)
- Most state is local to each screen (not shared)
- Token management uses a Singleton pattern (TokenService)

## Project Structure

```
lib/
├── main.dart                    # App entry point, initialization, routing
│
├── components/                  # Reusable UI components (like Vue components)
│   ├── class_form_dialog.dart       # Dialog for creating/editing classes
│   ├── class_list_item.dart         # List tile for class display
│   ├── confirmation_dialog.dart     # Generic confirmation dialog
│   ├── conflict_resolution_dialog.dart  # Conflict handling dialog
│   ├── dashboard_card.dart          # Card widget for dashboard stats
│   ├── empty_state.dart             # Empty state placeholder widget
│   ├── enhanced_search_bar.dart     # Search bar with filters
│   ├── error_handler.dart           # Global error stream handler
│   ├── error_screen.dart            # Error display screen
│   ├── filter_section.dart          # Filter controls section
│   ├── filter_sheet.dart            # Bottom sheet with filters
│   ├── gradient_page_header.dart    # Gradient header for pages
│   ├── loading_screen.dart          # Loading spinner screen
│   ├── new_enhanced_search_bar.dart # Updated search bar
│   ├── schedule_card.dart           # Schedule display card
│   ├── schedule_form_dialog.dart    # Schedule create/edit dialog
│   ├── schedule_list.dart           # Schedule list view
│   ├── search_bar.dart              # Basic search bar
│   ├── separated_search_filter.dart # Search + filter combo
│   ├── separated_search_filter_examples.dart  # Usage examples
│   ├── skeleton_loading.dart        # Skeleton loading animation
│   ├── student_list_item.dart       # Student list tile
│   ├── subject_list_item.dart       # Subject list tile
│   ├── tab_switcher.dart            # Tab switching widget
│   ├── teacher_list_item.dart       # Teacher list tile
│   └── token_service.dart           # JWT token management (Singleton)
│
├── data/
│   └── data_dummy.dart              # Dummy/mock data for development
│
├── models/                      # Data models (like Laravel Models, but simpler)
│   ├── absensi.dart                 # Attendance record model
│   ├── absensi_summary.dart         # Attendance summary model
│   ├── guru.dart                    # Teacher model
│   ├── kegiatan.dart                # Activity model
│   ├── kelas.dart                   # Class/classroom model
│   ├── nilai.dart                   # Grade/score model
│   ├── pagination_model.dart        # Pagination metadata model
│   ├── pengumuman.dart              # Announcement model
│   ├── siswa.dart                   # Student model
│   └── user.dart                    # User model
│
├── providers/                   # State management (like Vuex stores)
│   ├── academic_year_provider.dart  # Global academic year state
│   └── teacher_provider.dart        # Global teacher data cache
│
├── screen/                      # Feature screens organized by role
│   ├── login_screen.dart            # Login page (email/OTP + Google)
│   ├── dashboard.dart               # Main dashboard (role-based routing hub)
│   │
│   ├── admin/                   # Admin role screens
│   │   ├── admin_announcement.dart          # Announcement management
│   │   ├── admin_class_activity.dart        # View class activities
│   │   ├── admin_class_management.dart      # Class CRUD
│   │   ├── admin_data_management.dart       # Data management hub
│   │   ├── admin_presence_report.dart       # Attendance reports
│   │   ├── admin_raport_screen.dart         # Report card management
│   │   ├── admin_rpp_screen.dart            # Lesson plan approval
│   │   ├── class_finance_report_screen.dart # Finance reports by class
│   │   ├── class_promotion_wizard.dart      # Year-end class promotion
│   │   ├── finance.dart                     # Finance management (billing, payments)
│   │   ├── laporan.dart                     # Reports hub
│   │   ├── school_level_settings_screen.dart # School level config
│   │   ├── school_settings_screen.dart      # School settings
│   │   ├── settings_screen.dart             # App settings
│   │   ├── student_detail_screen.dart       # Student detail view
│   │   ├── student_management.dart          # Student CRUD
│   │   ├── subject_management.dart          # Subject CRUD
│   │   ├── teacher_admin.dart               # Teacher CRUD
│   │   ├── teacher_detail_screen.dart       # Teacher detail view
│   │   ├── teaching_schedule_management.dart # Schedule management
│   │   ├── time_settings_screen.dart        # Time/period settings
│   │   └── components/
│   │       └── promotion_step_indicator.dart # Step indicator widget
│   │
│   ├── guru/                    # Teacher role screens
│   │   ├── absensi_detail_page.dart         # Attendance detail view
│   │   ├── class_activity.dart              # Class activity management
│   │   ├── input_grade_teacher.dart         # Grade input interface
│   │   ├── learning_recommendation_class_screen.dart    # AI: class recommendations
│   │   ├── learning_recommendation_edit_screen.dart     # AI: edit recommendation
│   │   ├── learning_recommendation_result_screen.dart   # AI: recommendation results
│   │   ├── learning_recommendation_student_screen.dart  # AI: student recommendations
│   │   ├── materi_ai_result_screen.dart     # AI: generated material view
│   │   ├── materi_screen.dart               # Teaching materials management
│   │   ├── presence_teacher.dart            # Attendance input/management
│   │   ├── raport_detail_screen.dart        # Report card detail
│   │   ├── raport_print_screen.dart         # Report card print/export
│   │   ├── raport_screen.dart               # Report card list
│   │   ├── rekap_nilai_screen.dart          # Grade recap/summary
│   │   ├── rpp_ai_result_screen.dart        # AI: generated lesson plan view
│   │   ├── rpp_detail_screen.dart           # Lesson plan detail
│   │   ├── rpp_export_service.dart          # Lesson plan PDF/DOCX export
│   │   ├── rpp_generate_screen.dart         # AI: lesson plan generation form
│   │   ├── rpp_screen.dart                  # Lesson plan list
│   │   └── teaching_schedule.dart           # View teaching schedule
│   │
│   ├── staff/                   # Staff role screens
│   │   ├── administrasi.dart                # Administration management
│   │   ├── data_siswa.dart                  # Student data view
│   │   ├── inventaris.dart                  # Inventory management
│   │   └── surat.dart                       # Correspondence management
│   │
│   ├── walimurid/               # Parent role screens
│   │   ├── announcement_screen.dart         # View announcements
│   │   ├── parent_billing.dart              # View/pay bills
│   │   ├── parent_class_activity.dart       # View class activities
│   │   ├── parent_grade_screen.dart         # View child's grades
│   │   ├── parent_raport_detail_screen.dart # View report card detail
│   │   ├── parent_raport_screen.dart        # View report cards
│   │   └── presence_parent.dart             # View child's attendance
│   │
│   └── common/                  # Shared screens (all roles)
│       └── notification_list.dart           # Notification list
│
├── services/                    # API & business services (like Laravel Services)
│   ├── api_services.dart            # Core HTTP client (base class for all API calls)
│   ├── api_academic_services.dart   # Academic year & semester API
│   ├── api_announcement_services.dart # Announcement API
│   ├── api_class_activity_services.dart # Class activity API
│   ├── api_class_services.dart      # Class CRUD API
│   ├── api_grade_recap_services.dart # Grade recap API
│   ├── api_notification_service.dart # Notification API
│   ├── api_raport_services.dart     # Report card API
│   ├── api_recommendation_services.dart # AI recommendation API
│   ├── api_schedule_services.dart   # Teaching schedule API
│   ├── api_settings_services.dart   # School settings API
│   ├── api_student_services.dart    # Student CRUD API
│   ├── api_subject_services.dart    # Subject CRUD API
│   ├── api_teacher_services.dart    # Teacher CRUD API
│   ├── api_tour_services.dart       # Onboarding tour API
│   ├── analytics_service.dart       # Firebase Analytics wrapper
│   ├── excel_class_activity_service.dart  # Export class activities to Excel
│   ├── excel_class_service.dart     # Export classes to Excel
│   ├── excel_nilai_service.dart     # Export grades to Excel
│   ├── excel_presence_service.dart  # Export attendance to Excel
│   ├── excel_raport_service.dart    # Export report cards to Excel
│   ├── excel_rekap_nilai_service.dart # Export grade recaps to Excel
│   ├── excel_rpp_service.dart       # Export lesson plans to Excel
│   ├── excel_schedule_service.dart  # Export schedules to Excel
│   ├── excel_student_service.dart   # Export students to Excel
│   ├── excel_subject_service.dart   # Export subjects to Excel
│   ├── excel_teacher_service.dart   # Export teachers to Excel
│   ├── fcm_service.dart             # Firebase Cloud Messaging
│   ├── local_cache_service.dart     # Local cache with TTL
│   ├── log_service.dart             # Error logging service
│   ├── performance_service.dart     # Firebase Performance wrapper
│   └── rpp_service.dart             # Lesson plan business logic
│
├── utils/                       # Utility/helper functions
│   ├── color_utils.dart             # Color palette & theme colors
│   ├── currency_formatter.dart      # Indonesian Rupiah formatting
│   ├── dashboard_typography.dart    # Dashboard text styles
│   ├── date_utils.dart              # Date formatting helpers
│   ├── error_utils.dart             # Error message translation
│   └── language_utils.dart          # Multi-language support provider
│
└── widgets/                     # Dashboard-specific widgets
    ├── pagination_widget.dart       # Pagination controls
    └── dashboard/
        ├── attendance_bar_chart_card.dart  # Attendance bar chart
        ├── attendance_overview_card.dart   # Attendance overview stats
        ├── category_section.dart          # Dashboard category section
        ├── enhanced_stat_card.dart        # Enhanced statistics card
        ├── finance_bar_chart_card.dart    # Finance bar chart
        ├── lesson_plan_status_card.dart   # RPP status card
        ├── material_slider_card.dart      # Material progress slider
        ├── menu_item_card.dart            # Dashboard menu item
        ├── mini_bar_chart.dart            # Mini bar chart widget
        ├── mini_sparkline.dart            # Mini sparkline chart
        ├── overview_card.dart             # Overview statistics card
        ├── progress_ring.dart             # Circular progress indicator
        ├── quick_action_button.dart       # Quick action button
        └── schedule_slider_card.dart      # Schedule slider card
```

## Features by Role

### Admin
| Feature | Screen File | Description |
|---------|------------|-------------|
| Dashboard | `dashboard.dart` | Statistics overview, quick actions, charts |
| Student Management | `student_management.dart` | CRUD students, import/export CSV/Excel |
| Teacher Management | `teacher_admin.dart` | CRUD teachers, import/export |
| Class Management | `admin_class_management.dart` | CRUD classes, assign homeroom teachers |
| Subject Management | `subject_management.dart` | CRUD subjects |
| Schedule Management | `teaching_schedule_management.dart` | Create/manage teaching schedules |
| Finance | `finance.dart` | Billing, payments, financial reports |
| Attendance Reports | `admin_presence_report.dart` | View/export attendance reports |
| Announcements | `admin_announcement.dart` | Create/manage announcements |
| Report Cards | `admin_raport_screen.dart` | View/approve report cards |
| Lesson Plan Approval | `admin_rpp_screen.dart` | Approve/revision teacher lesson plans |
| Class Promotion | `class_promotion_wizard.dart` | Year-end student class promotion |
| Settings | `settings_screen.dart` | School settings, time periods, levels |

### Teacher (Guru)
| Feature | Screen File | Description |
|---------|------------|-------------|
| Dashboard | `dashboard.dart` | Teaching stats, schedule, quick actions |
| Attendance | `presence_teacher.dart` | Input/view daily attendance |
| Grade Input | `input_grade_teacher.dart` | Input student grades by subject |
| Grade Recap | `rekap_nilai_screen.dart` | View grade summaries |
| Class Activity | `class_activity.dart` | Log daily teaching activities |
| Materials | `materi_screen.dart` | Manage teaching materials (chapters, sub-chapters) |
| Lesson Plans (RPP) | `rpp_screen.dart` | Create/manage lesson plans |
| Report Cards | `raport_screen.dart` | Generate/view student report cards |
| AI Recommendations | `learning_recommendation_*.dart` | AI-powered student learning recommendations |
| AI Materials | `materi_ai_result_screen.dart` | AI-generated teaching materials |
| AI Lesson Plans | `rpp_generate_screen.dart` | AI-generated lesson plans |
| Schedule | `teaching_schedule.dart` | View personal teaching schedule |

### Parent (Wali Murid)
| Feature | Screen File | Description |
|---------|------------|-------------|
| Dashboard | `dashboard.dart` | Child's overview stats |
| Attendance | `presence_parent.dart` | View child's attendance records |
| Grades | `parent_grade_screen.dart` | View child's grades |
| Billing | `parent_billing.dart` | View/manage payment bills |
| Report Cards | `parent_raport_screen.dart` | View child's report cards |
| Announcements | `announcement_screen.dart` | View school announcements |
| Class Activity | `parent_class_activity.dart` | View class activities |

### Staff
| Feature | Screen File | Description |
|---------|------------|-------------|
| Administration | `administrasi.dart` | General admin tasks |
| Student Data | `data_siswa.dart` | View student records |
| Inventory | `inventaris.dart` | Manage school inventory |
| Correspondence | `surat.dart` | Manage school letters |

## API Connections

### Main Backend API (Laravel)
- **Base URL**: Configured via `.env` file (`API_URL`)
- **Authentication**: Laravel Sanctum (Bearer token)
- **School Context**: `X-School-ID` header on every request
- **Rate Limiting**: Auth endpoints throttled at 5 requests/minute

#### Key Endpoints:
```
Auth:
  POST /api/auth/login              # Email + password → OTP
  POST /api/auth/verify-otp         # OTP verification → token
  POST /api/auth/google-login       # Google OAuth login
  POST /api/auth/logout             # Invalidate token
  POST /api/auth/switch-school      # Switch active school

Resources (all require auth + X-School-ID):
  GET/POST/PUT/DELETE /api/students
  GET/POST/PUT/DELETE /api/teachers
  GET/POST/PUT/DELETE /api/classes
  GET/POST/PUT/DELETE /api/subjects
  GET/POST/PUT/DELETE /api/grades
  GET/POST/PUT/DELETE /api/attendances
  GET/POST/PUT/DELETE /api/materials
  GET/POST/PUT/DELETE /api/lesson-plans
  GET/POST/PUT/DELETE /api/teaching-schedules
  GET/POST/PUT/DELETE /api/announcements
  GET/POST/PUT/DELETE /api/notifications
  GET/POST/PUT/DELETE /api/class-activities
  GET/POST/PUT/DELETE /api/payment-types

Special:
  GET    /api/academic-years
  GET    /api/academic-year/active
  GET    /api/finance/dashboard
  GET    /api/finance/report
  POST   /api/generate-bill
  POST   /api/students/import          # CSV import
  POST   /api/fcm/token                # Register push notification token
```

#### API Response Format:
```json
// Success
{
  "success": true,
  "data": { ... },
  "message": "Operation successful"
}

// Success with pagination
{
  "success": true,
  "data": [ ... ],
  "pagination": {
    "total_items": 100,
    "total_pages": 10,
    "current_page": 1,
    "per_page": 10,
    "has_next_page": true,
    "has_prev_page": false
  }
}

// Error
{
  "success": false,
  "message": "Error description",
  "errors": { "field_name": ["Error detail"] }
}
```

### AI API (Laravel)
- **Base URL**: Separate from main API (configured in services)
- **Authentication**: Same Sanctum token
- **Access**: Teacher role only
- **Pattern**: Async job-based (submit → poll status → get result)

#### Key Endpoints:
```
AI Jobs:
  GET /api/ai-jobs                   # List all AI jobs
  GET /api/ai-jobs/{id}              # Check job status

Recommendations:
  POST /api/recommendations/generate          # Generate for class
  POST /api/recommendations/generate-student  # Generate for student
  GET  /api/recommendations                   # List recommendations

Generated Materials:
  POST /api/generated-materials/generate      # Generate material
  GET  /api/generated-materials/check-cache   # Check if cached
  GET  /api/generated-materials               # List materials

Lesson Plans (AI):
  POST /api/lesson-plans/generate             # Generate lesson plan
  POST /api/lesson-plans/{id}/regen/{field}   # Regenerate specific field
  GET  /api/lesson-plans/{id}/export          # Export to DOCX
  POST /api/lesson-plans/{id}/submit          # Submit for approval
```

## State Management

### Provider (ChangeNotifier)
The app uses the `provider` package with 3 global providers:

1. **LanguageProvider** (`utils/language_utils.dart`)
   - Manages app language (English/Indonesian)
   - Persists language choice to SharedPreferences
   - Used via `languageProvider.getTranslatedText({'en': '...', 'id': '...'})`

2. **AcademicYearProvider** (`providers/academic_year_provider.dart`)
   - Stores current active academic year
   - Used across screens that need academic year context

3. **TeacherProvider** (`providers/teacher_provider.dart`)
   - Caches teacher-specific data (classes, schedules)
   - Reduces redundant API calls for teacher screens

### Local State (setState)
Most screens use `StatefulWidget` with `setState()` for local state management. This includes:
- Loading flags (`_isLoading`, `_isSubmitting`)
- Form data (`_selectedClass`, `_selectedSubject`)
- List data (`_students`, `_grades`)
- Pagination state (`_currentPage`, `_totalPages`)
- Filter state (`_searchQuery`, `_filterDate`)

## Navigation & Routing

### Route Setup (main.dart)
```dart
routes: {
  '/admin': (context) => Dashboard(role: 'admin'),
  '/guru': (context) => Dashboard(role: 'guru'),
  '/teacher': (context) => Dashboard(role: 'guru'),  // alias
  '/staff': (context) => Dashboard(role: 'staff'),
  '/wali': (context) => Dashboard(role: 'wali'),
  '/parent': (context) => Dashboard(role: 'wali'),   // alias
  '/login': (context) => LoginScreen(),
}
```

### Navigation Patterns Used:
- `Navigator.push(MaterialPageRoute(...))` - Push to new screen
- `Navigator.pushReplacement(...)` - Replace current screen (used after login)
- `Navigator.pushAndRemoveUntil(...)` - Clear stack (used for logout)
- `Navigator.pop()` - Go back
- Global `navigatorKey` for navigation without BuildContext (error handling)

### Dashboard as Hub
The `Dashboard` widget receives a `role` parameter and displays different menus, stats, and quick actions based on the role. It acts as the central navigation hub after login.

## Services Layer

### Core API Service (`api_services.dart`)
The base HTTP client that all other services use:
- Static methods for GET, POST, PUT, DELETE
- Auto-injects Bearer token via `_getHeaders()`
- Auto-injects `X-School-ID` header
- Centralized response handling via `_handleResponse()`
- Firebase Performance tracking on each request
- 30-second timeout

### Domain-Specific API Services
Each service handles API calls for a specific domain:
- `api_student_services.dart` → `/api/students`
- `api_teacher_services.dart` → `/api/teachers`
- `api_class_services.dart` → `/api/classes`
- etc.

### Excel Export Services
Dedicated services for generating Excel files:
- `excel_student_service.dart` - Export student lists
- `excel_presence_service.dart` - Export attendance records
- `excel_nilai_service.dart` - Export grades
- etc.

Uses Syncfusion Flutter XlsIO for Excel generation.

### Other Services
- **FCMService** - Firebase Cloud Messaging setup & token management
- **AnalyticsService** - Firebase Analytics event tracking
- **PerformanceService** - Firebase Performance monitoring
- **LocalCacheService** - SharedPreferences-based cache with TTL (24h default)
- **LogService** - Error logging
- **TokenService** - JWT token storage, validation, and user data management

## Models

Simple Dart classes (PODOs) with `fromJson` factory constructors and `toJson` methods:

| Model | File | Purpose |
|-------|------|---------|
| Siswa | `siswa.dart` | Student data (id, name, class, NIS, address, parent info) |
| Guru | `guru.dart` | Teacher data |
| Kelas | `kelas.dart` | Class/classroom data |
| Nilai | `nilai.dart` | Grade/score data |
| Absensi | `absensi.dart` | Attendance record |
| AbsensiSummary | `absensi_summary.dart` | Attendance summary statistics |
| Pengumuman | `pengumuman.dart` | Announcement data |
| Kegiatan | `kegiatan.dart` | Activity data |
| User | `user.dart` | User profile data |
| PaginationModel | `pagination_model.dart` | Pagination metadata |

**Note**: Many screens work directly with `Map<String, dynamic>` and `List<dynamic>` rather than using typed models. This is an area for improvement.

## Components & Widgets

### Reusable Components (`lib/components/`)
UI components shared across multiple screens:
- **Dialogs**: `class_form_dialog`, `confirmation_dialog`, `conflict_resolution_dialog`, `schedule_form_dialog`
- **List Items**: `class_list_item`, `student_list_item`, `subject_list_item`, `teacher_list_item`
- **Search/Filter**: `enhanced_search_bar`, `filter_sheet`, `filter_section`, `separated_search_filter`
- **Loading/Error**: `loading_screen`, `skeleton_loading`, `error_screen`, `empty_state`
- **Layout**: `gradient_page_header`, `dashboard_card`, `tab_switcher`

### Dashboard Widgets (`lib/widgets/dashboard/`)
Specialized widgets for the dashboard:
- **Charts**: `attendance_bar_chart_card`, `finance_bar_chart_card`, `mini_bar_chart`, `mini_sparkline`
- **Stats**: `enhanced_stat_card`, `overview_card`, `progress_ring`
- **Cards**: `lesson_plan_status_card`, `material_slider_card`, `schedule_slider_card`
- **Navigation**: `menu_item_card`, `quick_action_button`, `category_section`

## Utilities

| File | Purpose |
|------|---------|
| `color_utils.dart` | App color palette (Indigo-based), day-of-week colors, grade colors, status colors |
| `currency_formatter.dart` | Format numbers as Indonesian Rupiah (Rp 1.000.000) |
| `dashboard_typography.dart` | Text style definitions for dashboard |
| `date_utils.dart` | Date formatting helpers (Indonesian locale) |
| `error_utils.dart` | Map API/network errors to user-friendly Indonesian messages |
| `language_utils.dart` | Multi-language ChangeNotifier provider |

## Firebase Integration

### Firebase Core
Initialized in `main.dart` with platform-specific options from `firebase_options.dart`.

### Firebase Cloud Messaging (FCM)
- **Service**: `fcm_service.dart`
- Handles push notification setup, token management, and notification display
- Registers FCM token with backend via `POST /api/fcm/token`
- Uses `flutter_local_notifications` for foreground notifications

### Firebase Analytics
- **Service**: `analytics_service.dart`
- Tracks screen views, user events
- Sets user properties on login
- Navigator observer for automatic screen tracking

### Firebase Performance
- **Service**: `performance_service.dart`
- Tracks HTTP request metrics (URL, method, response time, status)
- Integrated into `ApiService._getHeaders()` flow

## Authentication Flow

```
1. User opens app
   → main.dart checks token validity via TokenService.isLoggedIn()
   → If valid token exists → Dashboard(role: savedRole)
   → If no valid token → LoginScreen

2. Login (Email/Password)
   → POST /api/auth/login
   → If demo account → returns token immediately
   → If normal account → sends OTP to email
   → User enters OTP → POST /api/auth/verify-otp
   → Returns: token + user data + school info
   → Token saved to SharedPreferences
   → Navigate to Dashboard

3. Login (Google)
   → Google Sign-In SDK
   → POST /api/auth/google-login with ID token
   → Returns: token + user data
   → Same flow as above

4. Multi-school handling
   → If user has multiple schools → school selection screen
   → POST /api/auth/switch-school to change active school
   → X-School-ID header updated for all subsequent requests

5. Token expiry
   → Global error handler detects 401/token expired
   → Auto-logout via TokenService.logout()
   → Navigate to LoginScreen
```

## Caching Strategy

### LocalCacheService
- **Storage**: SharedPreferences
- **Default TTL**: 24 hours
- **Key format**: `api_cache_{endpoint_hash}`
- **Usage**: Services check cache before making API calls
- **Invalidation**: Manual (on data mutation) or TTL expiry

### Token Storage
- **Storage**: SharedPreferences (plain text)
- **Keys**: `token`, `user` (JSON string)
- **Note**: Not encrypted - improvement area

## Localization

### Current Implementation
Uses a custom `LanguageProvider` with inline translations:
```dart
languageProvider.getTranslatedText({
  'en': 'Hello',
  'id': 'Halo',
})
```

### Supported Languages
- English (en)
- Indonesian (id) - default

## Testing

### Integration Tests
Located in `integration_test/` using the Patrol framework:
- `login_test.dart` - Login flow
- `logout_test.dart` - Logout flow
- `school_selection_test.dart` - School switching
- `admin_dashboard_test.dart` - Admin dashboard
- `admin_navigation_test.dart` - Admin navigation
- `admin_data_management_test.dart` - Admin data management
- `teacher_flow_test.dart` - Teacher workflow
- `parent_flow_test.dart` - Parent workflow

### Unit Tests
No unit tests currently exist.

## Setup & Running

### Prerequisites
- Flutter SDK ^3.9.0
- Dart SDK ^3.9.0
- Android Studio / Xcode (for emulators)
- Firebase project configured

### Environment Setup
1. Create `.env` file in project root:
```
API_URL=https://your-api-url.com/api
AI_API_URL=https://your-ai-api-url.com/api
```

2. Configure Firebase:
```bash
flutterfire configure
```

### Running
```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build APK
flutter build apk

# Build iOS
flutter build ios

# Run integration tests
flutter test integration_test
```

### Dependencies
Run `flutter pub get` to install all dependencies listed in `pubspec.yaml`.

---

## Known Areas for Improvement

1. **Large screen files**: 5 files exceed 5,000 lines (presence_teacher, input_grade_teacher, finance, dashboard, class_activity)
2. **Mixed concerns**: Business logic embedded in UI StatefulWidgets
3. **Weak typing**: Heavy use of `Map<String, dynamic>` instead of typed models
4. **setState prevalence**: 920+ setState calls instead of proper state management
5. **No dependency injection**: Services instantiated directly in screens
6. **Inconsistent error handling**: 411 try-catch blocks with varying patterns
7. **No unit tests**: Only integration tests exist
8. **Plain text token storage**: Should use encrypted storage
9. **Indonesian naming in code**: Variable/file names use Indonesian (guru, siswa, kelas, etc.)
10. **Duplicated API patterns**: Each of the 32 service files duplicates header/response handling
