// Brand-aligned school + role switcher bottom sheets.
//
// Phase-5 redesign — replaces the legacy `AlertDialog`s. Both sheets
// follow the "Hero Saat ini + Ganti ke" pattern from the v3 mockup,
// implemented as thin wrappers over the shared
//   • BrandHeroSheet     — sheet chrome (handle, header, hero, tiles)
//   • SelectionHeroCard  — gradient "Saat ini" card
//   • SelectionTile      — compact alternatives row
//   • InitialsAvatar     — circular initials disc
//   • role_labels.dart   — pure Bahasa label / icon / shell-key helpers
//
// Public API kept identical — `showDashboardSchoolSelectionDialog` and
// `showDashboardRolePickerDialog` are still the only entry points,
// so call sites in dialog_mixin.dart and dashboard_account_sheet
// don't need to change.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/providers/school_epoch_provider.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/shell/shell_controller.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/role_labels.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_hero_sheet.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';
import 'package:manajemensekolah/core/widgets/selection_hero_card.dart';
import 'package:manajemensekolah/core/widgets/selection_tile.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';

// ════════════════════════════════════════════════════════════════
// PUBLIC ENTRY POINTS
// ════════════════════════════════════════════════════════════════

/// Show the school-switcher bottom sheet. Signature preserved from the
/// legacy AlertDialog version so existing call sites compile unchanged.
void showDashboardSchoolSelectionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required DashboardState state,
  required String currentRole,
  required Color primaryColor,
  required void Function(
    BuildContext ctx,
    String schoolId,
    List<String> roleList,
  )
  onNeedsRoleSelection,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _SchoolSwitcherSheet(
      parentContext: context,
      sheetContext: sheetCtx,
      ref: ref,
      state: state,
      currentRole: currentRole,
      onNeedsRoleSelection: onNeedsRoleSelection,
    ),
  );
}

/// Show the role-picker bottom sheet for a school that exposes multiple
/// roles. Signature preserved from the legacy AlertDialog version.
void showDashboardRolePickerDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String schoolId,
  required List<String> roleList,
  required String currentRole,
  required Color primaryColor,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetCtx) => _RoleSwitcherSheet(
      parentContext: context,
      sheetContext: sheetCtx,
      ref: ref,
      schoolId: schoolId,
      roleList: roleList,
      currentRole: currentRole,
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// SCHOOL SWITCHER SHEET
// ════════════════════════════════════════════════════════════════

class _SchoolSwitcherSheet extends StatelessWidget {
  final BuildContext parentContext;
  final BuildContext sheetContext;
  final WidgetRef ref;
  final DashboardState state;
  final String currentRole;
  final void Function(BuildContext ctx, String schoolId, List<String> roleList)
  onNeedsRoleSelection;

  const _SchoolSwitcherSheet({
    required this.parentContext,
    required this.sheetContext,
    required this.ref,
    required this.state,
    required this.currentRole,
    required this.onNeedsRoleSelection,
  });

  /// Role-aware gradient for the "Saat ini" school hero card.
  LinearGradient get _schoolGradient =>
      ColorUtils.brandGradient(currentRole);

  String _schoolName(Map<dynamic, dynamic> school) =>
      (school['school_name'] ?? school['name'] ?? 'Sekolah').toString();

  String _schoolAddress(Map<dynamic, dynamic> school) =>
      (school['address'] ?? '').toString();

  String? _schoolLogo(Map<dynamic, dynamic> school) {
    final raw = school['logo_url'] ?? school['logo'];
    final s = raw?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    final currentId = state.userData['school_id']?.toString();
    final schools = state.accessibleSchools;

    // Split into current vs others — current rendered as the hero card,
    // the rest as the "Ganti ke" list.
    Map<dynamic, dynamic>? currentSchool;
    final others = <Map<dynamic, dynamic>>[];
    for (final s in schools) {
      final sid = (s['school_id'] ?? s['id'])?.toString();
      if (sid == currentId && currentSchool == null) {
        currentSchool = s;
      } else {
        others.add(s);
      }
    }

    return BrandHeroSheet(
      icon: Icons.school_rounded,
      title: 'Pilih Sekolah',
      subtitle: 'Akun terhubung ke ${schools.length} sekolah',
      hero: currentSchool == null
          ? null
          : SelectionHeroCard(
              gradient: _schoolGradient,
              avatar: InitialsAvatar.onDark(
                name: _schoolName(currentSchool),
                size: 50,
                logoUrl: _schoolLogo(currentSchool),
                borderRadius: 16,
              ),
              title: _schoolName(currentSchool),
              subtitle: _schoolAddress(currentSchool).isEmpty
                  ? null
                  : _schoolAddress(currentSchool),
              onTap: () => AppNavigator.pop(context),
            ),
      tiles: [
        for (final s in others)
          SelectionTile(
            avatar: InitialsAvatar(
              name: _schoolName(s),
              size: 36,
              color: ColorUtils.slate400,
              logoUrl: _schoolLogo(s),
              borderRadius: 12,
            ),
            title: _schoolName(s),
            subtitle: _schoolAddress(s).isEmpty ? null : _schoolAddress(s),
            onTap: () => _onSchoolTap(s),
          ),
      ],
      emptyMessage: others.isEmpty
          ? 'Tidak ada sekolah lain yang terhubung dengan akun Anda'
          : null,
    );
  }

  Future<void> _onSchoolTap(Map<dynamic, dynamic> school) async {
    AppNavigator.pop(sheetContext);
    final router = GoRouter.of(parentContext);

    try {
      final schoolId = (school['school_id'] ?? school['id'] ?? '').toString();
      if (schoolId.isEmpty) {
        throw Exception('School ID is missing');
      }
      final result = await ref
          .read(dashboardProvider.notifier)
          .switchSchool(schoolId);

      if (!ref.context.mounted) return;

      if (result['needsRoleSelection'] == true) {
        final roleList = List<String>.from(result['role_list'] ?? []);
        if (roleList.isEmpty) return;
        // ignore: use_build_context_synchronously
        onNeedsRoleSelection(parentContext, schoolId, roleList);
        return;
      }

      final newRole = result['user']?['role']?.toString() ?? currentRole;
      await LocalCacheService.clearAll();
      if (ref.context.mounted) {
        // Compare via the shell-family key — see role_labels.dart.
        final newKey = shellRoleKey(newRole);
        final currentKey = shellRoleKey(currentRole);
        if (newKey == currentKey) {
          ref.read(shellProvider(newKey).notifier).resetNavigatorStacks();
          bumpSchoolEpoch(ref);
          await ref.read(dashboardProvider.notifier).reinitialize(newRole);
        } else {
          ref.read(dashboardProvider.notifier).resetForSchoolSwitch();
          bumpSchoolEpoch(ref);
          router.go('/$newRole');
        }
      }
    } catch (e) {
      AppLogger.error('dashboard', 'Switch school error: $e');
      if (ref.context.mounted) {
        // ignore: use_build_context_synchronously
        SnackBarUtils.showError(
          parentContext,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════
// ROLE SWITCHER SHEET
// ════════════════════════════════════════════════════════════════

class _RoleSwitcherSheet extends StatelessWidget {
  final BuildContext parentContext;
  final BuildContext sheetContext;
  final WidgetRef ref;
  final String schoolId;
  final List<String> roleList;
  final String currentRole;

  const _RoleSwitcherSheet({
    required this.parentContext,
    required this.sheetContext,
    required this.ref,
    required this.schoolId,
    required this.roleList,
    required this.currentRole,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve current vs others. Compare via the shell-role key so the
    // 'wali' alias matches against a backend 'parent' result.
    final state = ref.read(dashboardProvider).value;
    final currentSchoolId = state?.userData['school_id']?.toString() ?? '';
    final isSameSchool = currentSchoolId == schoolId;

    String? targetSchoolName;
    if (state != null) {
      for (final s in state.accessibleSchools) {
        if ((s['school_id'] ?? s['id'])?.toString() == schoolId) {
          targetSchoolName =
              s['nama_sekolah']?.toString() ??
              s['name']?.toString() ??
              s['school_name']?.toString();
          break;
        }
      }
    }

    final currentKey = shellRoleKey(currentRole);
    String? activeRole;
    final others = <String>[];
    for (final r in roleList) {
      if (isSameSchool && shellRoleKey(r) == currentKey && activeRole == null) {
        activeRole = r;
      } else {
        others.add(r);
      }
    }

    final title = targetSchoolName != null
        ? 'Pilih Peran di $targetSchoolName'
        : 'Pilih Peran';

    return BrandHeroSheet(
      icon: Icons.swap_horiz_rounded,
      title: title,
      subtitle: 'Akun terdaftar di ${roleList.length} peran',
      hero: activeRole == null
          ? null
          : SelectionHeroCard(
              gradient: ColorUtils.brandGradient(activeRole),
              avatar: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  roleIconData(activeRole),
                  color: Colors.white,
                  size: 22,
                ),
              ),
              title: roleDisplayName(activeRole),
              subtitle: roleDescription(activeRole),
              onTap: () => AppNavigator.pop(context),
            ),
      sectionLabel: others.isEmpty
          ? null
          : (activeRole == null ? 'PILIH PERAN' : 'GANTI KE'),
      tiles: [
        for (final r in others)
          SelectionTile(
            avatar: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: ColorUtils.brandGradient(r),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(roleIconData(r), size: 18, color: Colors.white),
            ),
            title: roleDisplayName(r),
            subtitle: roleDescription(r),
            onTap: () => _onRoleTap(r),
          ),
      ],
      emptyMessage: others.isEmpty
          ? 'Tidak ada peran lain yang terhubung dengan akun Anda di sekolah ini'
          : null,
    );
  }

  Future<void> _onRoleTap(String role) async {
    AppNavigator.pop(sheetContext);
    final router = GoRouter.of(parentContext);
    try {
      final result = await ref
          .read(dashboardProvider.notifier)
          .switchSchool(schoolId, role: role);
      if (!ref.context.mounted) return;
      final newRole = result['user']?['role']?.toString() ?? role;
      await LocalCacheService.clearAll();
      if (ref.context.mounted) {
        final newKey = shellRoleKey(newRole);
        final currentKey = shellRoleKey(currentRole);
        if (newKey == currentKey) {
          // Same role → reset Navigator GlobalKeys + bump epoch so the
          // IndexedStack subtree fully rebuilds with fresh per-tab
          // state. (Matches the same logic from school-switch.)
          ref.read(shellProvider(newKey).notifier).resetNavigatorStacks();
          bumpSchoolEpoch(ref);
          await ref.read(dashboardProvider.notifier).reinitialize(newRole);
        } else {
          ref.read(dashboardProvider.notifier).resetForSchoolSwitch();
          bumpSchoolEpoch(ref);
          router.go('/$newRole');
        }
      }
    } catch (e) {
      if (ref.context.mounted) {
        // ignore: use_build_context_synchronously
        SnackBarUtils.showError(
          parentContext,
          e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }
}
