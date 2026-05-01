// Brand-aligned school + role switcher bottom sheets.
//
// Phase-5 redesign — replaces the legacy `AlertDialog`s. Both sheets
// follow the "Hero Saat ini + Ganti ke" pattern from the v3 mockup:
//
//   ┌──────────────────────────────────────┐
//   │ ✚  Pilih Sekolah                     │  ← brand-azure tinted icon
//   │    Akun terhubung ke 2 sekolah       │
//   ├──────────────────────────────────────┤
//   │ ┌────────────────────────────────┐  │
//   │ │ SAAT INI       [AKTIF]         │  │  ← brand gradient
//   │ │ KA  SMP Kamil Edu A            │  │
//   │ │     Jl. Mawar No. 12 · Bandung │  │
//   │ └────────────────────────────────┘  │
//   │                                       │
//   │   GANTI KE                            │
//   │ ┌────────────────────────────────┐  │
//   │ │ KB  SMP Kamil Edu B            │  │  ← compact tile
//   │ │     Jl. Melati No. 7 · Bandung │  │     (no chevron)
//   │ └────────────────────────────────┘  │
//   └──────────────────────────────────────┘
//
// Public API kept identical — `showDashboardSchoolSelectionDialog` and
// `showDashboardRolePickerDialog` are still the only entry points,
// so call sites in dialog_mixin.dart and dashboard_account_sheet
// don't need to change. Internally each opens a `showModalBottomSheet`
// that hosts the corresponding `_SwitcherSheet`.
//
// Why a custom sheet (not AppBottomSheet)
// ---------------------------------------
// AppBottomSheet's default header is a colored gradient — but in this
// design the gradient is reserved for the "Saat ini" hero card so the
// active selection reads as a card rather than a header. The Phase-5A
// language picker set the precedent (see core/widgets/language_picker_sheet)
// so we follow the same pattern here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/school_epoch_provider.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/shell/shell_controller.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
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

    return _SwitcherSheetScaffold(
      icon: Icons.school_rounded,
      title: 'Pilih Sekolah',
      subtitle: 'Akun terhubung ke ${schools.length} sekolah',
      heroCard: currentSchool == null
          ? null
          : _SchoolHeroCard(school: currentSchool),
      sectionLabel: others.isEmpty ? null : 'GANTI KE',
      tiles: [
        for (final s in others)
          _SchoolTile(
            school: s,
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
        // Compare via the *effective* role (the shell-family key) — the
        // backend uses English ('parent' / 'teacher') while
        // [currentRole] carries the Indonesian alias ('wali' / 'guru').
        // Without normalizing, parent → parent looked like a cross-role
        // switch and we'd `router.go('/parent')`, which GoRouter treats
        // as a same-route no-op, so the refresh code never ran.
        final newKey = _shellRoleKey(newRole);
        final currentKey = _shellRoleKey(currentRole);
        if (newKey == currentKey) {
          ref.read(shellProvider(newKey).notifier).resetNavigatorStacks();
          bumpSchoolEpoch(ref);
          await ref
              .read(dashboardProvider.notifier)
              .reinitialize(newRole);
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

/// Maps a backend role value (`'parent'` / `'teacher'` / `'admin'`) to the
/// `shellProvider` family key (`'wali'` / `'guru'` / `'admin'`). Mirrors the
/// normalization done in `DashboardController._effectiveRole` — keep these
/// two in sync, otherwise the school-switch fix will read the wrong shell
/// notifier and the GlobalKeys won't actually be regenerated.
String _shellRoleKey(String role) {
  if (role == 'teacher') return 'guru';
  if (role == 'parent') return 'wali';
  return role;
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
    final currentKey = _shellRoleKey(currentRole);
    String? activeRole;
    final others = <String>[];
    for (final r in roleList) {
      if (_shellRoleKey(r) == currentKey && activeRole == null) {
        activeRole = r;
      } else {
        others.add(r);
      }
    }

    return _SwitcherSheetScaffold(
      icon: Icons.swap_horiz_rounded,
      title: 'Pilih Peran',
      subtitle: 'Akun terdaftar di ${roleList.length} peran',
      heroCard: activeRole == null ? null : _RoleHeroCard(role: activeRole),
      sectionLabel: others.isEmpty ? null : 'GANTI KE',
      tiles: [
        for (final r in others)
          _RoleTile(role: r, onTap: () => _onRoleTap(r)),
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
        final newKey = _shellRoleKey(newRole);
        final currentKey = _shellRoleKey(currentRole);
        if (newKey == currentKey) {
          // Same role → reset Navigator GlobalKeys + bump epoch so the
          // IndexedStack subtree fully rebuilds with fresh per-tab
          // state. (Matches the same logic from school-switch.)
          ref
              .read(shellProvider(newKey).notifier)
              .resetNavigatorStacks();
          bumpSchoolEpoch(ref);
          await ref
              .read(dashboardProvider.notifier)
              .reinitialize(newRole);
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

// ════════════════════════════════════════════════════════════════
// SHARED SCAFFOLD — header + drag handle + content layout
// ════════════════════════════════════════════════════════════════

class _SwitcherSheetScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? heroCard;
  final String? sectionLabel;
  final List<Widget> tiles;
  final String? emptyMessage;

  const _SwitcherSheetScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.heroCard,
    this.sectionLabel,
    required this.tiles,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.md + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header row: tinted icon disc + title + subtitle
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColorUtils.brandAzure.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 20,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Hero "Saat ini" card
          if (heroCard != null) heroCard!,
          if (heroCard != null) const SizedBox(height: AppSpacing.md),

          // "GANTI KE" section
          if (sectionLabel != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
              child: Text(
                sectionLabel!,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate400,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            // Constrain the alternatives list so very long ones can scroll.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.35,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      tiles[i],
                      if (i != tiles.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Empty state when nothing to switch to
          if (emptyMessage != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: AppSpacing.md,
              ),
              child: Text(
                emptyMessage!,
                style: TextStyle(
                  fontSize: 11.5,
                  color: ColorUtils.slate500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HERO CARDS (current selection — gradient background, white text)
// ════════════════════════════════════════════════════════════════

class _SchoolHeroCard extends StatelessWidget {
  final Map<dynamic, dynamic> school;

  const _SchoolHeroCard({required this.school});

  @override
  Widget build(BuildContext context) {
    final name = (school['school_name'] ?? school['name'] ?? 'Sekolah')
        .toString();
    final address = (school['address'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandAzure, ColorUtils.brandAzureDeep],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'SAAT INI',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'AKTIF',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleHeroCard extends StatelessWidget {
  final String role;

  const _RoleHeroCard({required this.role});

  @override
  Widget build(BuildContext context) {
    final name = _roleDisplayName(role);
    final desc = _roleDescription(role);
    final gradient = ColorUtils.brandGradient(role);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'SAAT INI',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text(
                  'AKTIF',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(_roleIcon(role), color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// COMPACT TILES (alternatives — white card, no chevron)
// ════════════════════════════════════════════════════════════════

class _SchoolTile extends StatelessWidget {
  final Map<dynamic, dynamic> school;
  final VoidCallback onTap;

  const _SchoolTile({required this.school, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (school['school_name'] ?? school['name'] ?? 'Sekolah')
        .toString();
    final address = (school['address'] ?? '').toString();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ColorUtils.slate400,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(name),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final String role;
  final VoidCallback onTap;

  const _RoleTile({required this.role, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: ColorUtils.brandGradient(role),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _roleIcon(role),
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _roleDisplayName(role),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleDescription(role),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HELPERS — role label/description/icon + initials
// ════════════════════════════════════════════════════════════════

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final tokens = trimmed.split(RegExp(r'\s+'));
  if (tokens.length == 1) {
    return tokens.first.characters.first.toUpperCase();
  }
  return (tokens[0].characters.first + tokens[1].characters.first)
      .toUpperCase();
}

String _roleDisplayName(String role) {
  switch (role) {
    case 'admin':
    case 'administrator':
      return 'Administrator';
    case 'guru':
    case 'teacher':
      return 'Guru';
    case 'wali':
    case 'parent':
    case 'orang_tua':
      return 'Wali Murid';
    case 'staff':
      return 'Staff';
    default:
      return role;
  }
}

String _roleDescription(String role) {
  switch (role) {
    case 'admin':
    case 'administrator':
      return 'Kelola sekolah, guru, dan siswa';
    case 'guru':
    case 'teacher':
      return 'Mengajar dan mengelola kelas';
    case 'wali':
    case 'parent':
    case 'orang_tua':
      return 'Pantau perkembangan anak';
    case 'staff':
      return 'Tugas operasional sekolah';
    default:
      return '';
  }
}

IconData _roleIcon(String role) {
  switch (role) {
    case 'admin':
    case 'administrator':
      return Icons.admin_panel_settings_rounded;
    case 'guru':
    case 'teacher':
      return Icons.school_rounded;
    case 'wali':
    case 'parent':
    case 'orang_tua':
      return Icons.family_restroom_rounded;
    case 'staff':
      return Icons.work_rounded;
    default:
      return Icons.person_rounded;
  }
}
