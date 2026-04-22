#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# kamiledu-mobile-flutter — release commit script for 2026-04-22
#
# Run from inside the repo root after cleaning up stale .git/*.lock files.
# Produces 12 feature-area commits on release/teacher-refactor-2026-04-22.
#
#   cd ~/Projects/kamiledu-mobile-flutter
#   rm -f .git/index.lock .git/HEAD.lock .git/ORIG_HEAD.lock
#   bash RELEASE_COMMIT_2026_04_22.sh
#   git push -u origin release/teacher-refactor-2026-04-22
#   # follow the MR URL printed by GitLab
#
# Sensitive / artifact files are explicitly excluded below — they stay
# unstaged and you can clean them up later by hand.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "release/teacher-refactor-2026-04-22" ]]; then
  echo "ERROR: expected to be on release/teacher-refactor-2026-04-22, got $BRANCH"
  echo "Run: git checkout -b release/teacher-refactor-2026-04-22"
  exit 1
fi

# Reset anything that might have been pre-staged
git reset >/dev/null 2>&1 || true

# Hard-exclude these paths from every commit: secrets + planning notes + build
# artifacts + simulator screenshots + this script itself.
EXCLUDES=(
  .env
  .sim_before.png .sim_after.png
  REFACTORING_AUDIT.md REFACTORING_PLAN.md
  android/build
  RELEASE_COMMIT_2026_04_22.sh
)
for p in "${EXCLUDES[@]}"; do
  git reset -- "$p" >/dev/null 2>&1 || true
done

# ─── Commit 1: shared core widgets ───────────────────────────────────────────
git add lib/core/widgets/
git commit -m "feat(core/widgets): introduce shared bottom-sheet, filter, and layout scaffolds

Adds new shared scaffolds to unify dialog/bottom-sheet/filter design:
AppBottomSheet, AppEditBottomSheet, BottomSheetHeader, BottomSheetFooter,
DragHandle, ActionConfirmSheet, AppAlertDialog, FilterBottomSheet,
FilterChipGrid, FilterSectionHeader, ActiveFilterChips, SearchFilterBar,
FormFieldSection, FrozenColumnTable, PaginatedListView, SectionHeader,
StatSummaryCard, StatusBadge, RoleToggle, ViewToggleButton,
TeacherAsyncView, TeacherFilterContent, TeacherPageHeader, AppQuillEditor,
AppRefreshIndicator, AppErrorState. Refreshes confirmation_dialog,
enhanced_search_bar, error_screen, modern_date_picker, and
skeleton_loading to align with the new design system. Removes unused
loading_screen.dart.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 2: core utils + config + mixins ──────────────────────────────────
git add lib/core/utils/ lib/core/config/ lib/core/mixins/
git commit -m "refactor(core/utils): split language/color utils and add academic-year + AI-config helpers

Splits language utils into focused files (common_localizations,
core_localizations, settings_auth_2). Adds academic_year_utils +
color_utils_mappings for the chip-based tahun ajaran flow. Adds
ai_config and tightens pagination_mixin.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 3: FCM decomposition + new core services ─────────────────────────
git add lib/core/services/
git commit -m "refactor(core/services): decompose FCM service and add cache-invalidation + filter-options services

Splits monolithic FcmService into fcm_local_notifications,
fcm_message_handler, fcm_notification_router, fcm_permissions, and
fcm_token_manager. Adds CacheInvalidationService and
FilterOptionsService for cross-feature cache control and filter-option
fetching.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 4: constants, router, iOS, analyzer config ───────────────────────
git add lib/core/constants/ lib/core/router/ analysis_options.yaml ios/Runner.xcodeproj/project.pbxproj
git commit -m "chore(core): refresh api endpoints, grade constants, router, analyzer rules, iOS project

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 5: attendance feature ────────────────────────────────────────────
git add lib/features/attendance/
git add integration_test/attendance_test.dart test/features/attendance/ 2>/dev/null || true
git commit -m "refactor(attendance): mixin-based decomposition and migration to shared scaffolds

Splits teacher attendance screen into focused mixins (ui/body/navigation/
filter/read-tracking). Migrates filter sheet and detail sheets to
BottomSheetHeader/Footer + FilterChipGrid. Adds shared analytics/query/
write helpers in data layer.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 6: grades feature ────────────────────────────────────────────────
git add lib/features/grades/
git add integration_test/grade_test.dart test/features/grades/ 2>/dev/null || true
git commit -m "refactor(grades): decompose grade-recap screens, add ModernGradeEditorSheet, migrate to FrozenColumnTable

Introduces the unified grade editor bottom sheet with Samsung nav-bar
safe area, migrates GradeRecap overview to the multi-frozen
FrozenColumnTable (Kelas + Mapel frozen), wires
showEditDeskripsiDialog through AppEditBottomSheet, and adds
GradeSelectionDialog safe-area. Adds wali-kelas role toggle + recording
teacher display. Backend-aggregated recap counters stop stale-state
bugs after edits. Fixes Input Nilai POST 404 and student_class_id gap.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 7: class_activity feature ────────────────────────────────────────
git add lib/features/class_activity/
git add integration_test/activity_test.dart test/features/class_activity/ 2>/dev/null || true
git commit -m "refactor(class_activity): migrate dialogs to shared scaffolds and show wali-kelas author

Activity detail dialog now uses BottomSheetHeader. Filter kegiatan
subjects to teacher-taught only. Show activity author for wali-kelas
role. Fixes teacher activity form save flow.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 8: lesson_plans feature (RPP) ────────────────────────────────────
git add lib/features/lesson_plans/
git add integration_test/lesson_plan_test.dart test/features/lesson_plans/ 2>/dev/null || true
git commit -m "feat(lesson_plans): chip-based tahun ajaran, Samsung safe-area, new RPP detail/edit sheets

Converts tahun ajaran to chip options (defaults to current academic
year) on both manual add-RPP and AI generate-RPP dialogs. Fixes
Samsung nav-bar safe-area on add-RPP dialog. Adds new RPP detail and
edit bottom sheets, rewires teacher RPP screen navigation, retires
old detail/edit screens. Fixes AI content empty on sub-bab re-open
and missing lesson_plans.chapter_id on generate.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 9: materials feature ─────────────────────────────────────────────
git add lib/features/materials/
git add integration_test/materials_test.dart test/features/materials/ 2>/dev/null || true
git commit -m "refactor(materials): migrate to shared scaffolds, fix AI generate save, show wali-kelas author

Decouples is_generated from checkbox lock, colorizes badges on
generation, shows author for wali-kelas role. Fixes Referensi tab
overflow and AI material save flow. Migrates material overview to
shared FilterChipGrid/BottomSheetHeader.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 10: recommendations feature ──────────────────────────────────────
git add lib/features/recommendations/
git add integration_test/recommendations_test.dart test/features/recommendations/ 2>/dev/null || true
git commit -m "refactor(recommendations): flat-flow teacher screen, wali-kelas view, diterapkan fix

Flattens recommendation flow to sheet-based navigation. Moves
search/filter/view-toggle into header. Adds wali-kelas role-toggle
view. Strengthens card borders. Fixes 'siswa belum tersedia' on init,
stale class-card studentCount, and diterapkan count showing 0.
Propagates status-change back to class screen.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 11: students + schedule + announcements ──────────────────────────
git add lib/features/students/ lib/features/schedule/ lib/features/announcements/
git add integration_test/student_test.dart integration_test/schedule_test.dart \
        integration_test/announcement_test.dart 2>/dev/null || true
git add test/features/students/ test/features/schedule/ test/features/announcements/ 2>/dev/null || true
git commit -m "refactor(students+schedule+announcements): shared scaffolds and wali-kelas + teacher filters

students: add/edit dialog Samsung safe-area, avatar palette refresh,
mixin-based decomposition of admin management screen.
schedule: wali-kelas session teacher display, day-filter fix, shared
card widgets across admin/teacher roles.
announcements: teacher screen + filter sheet with shared scaffolds,
filter mixins with FilterSectionHeader icons, pengumuman data for
teacher role.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

# ─── Commit 12: remaining features + integration test harness ────────────────
git add lib/features/
git add integration_test/ test/ 2>/dev/null || true
git commit -m "refactor(remaining): dashboard, finance, raport, subjects, teachers, auth, settings, parent, notifications + test harness

dashboard: hero stats, attendance popup, app-bar consolidation.
finance: ClassFinanceTable + verification + generate-bills dialogs on
shared scaffolds, stat cards + status cells.
raport: table_view migration to shared widget, teacher-summary integration.
subjects/teachers: decomposition + filter chip migration.
auth/settings/parent/notifications: refresh to shared scaffolds.
integration_test: login/test helpers, role_navigation, parent_navigation,
ui_test, notification_test updated for new widget tree.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"

echo ""
echo "── done. 12 commits created on release/teacher-refactor-2026-04-22 ──"
git log --oneline -12
echo ""
echo "── final status (should be empty or only excluded artifacts) ──"
git status --short | head -20
echo ""
echo "Next: git push -u origin release/teacher-refactor-2026-04-22"
