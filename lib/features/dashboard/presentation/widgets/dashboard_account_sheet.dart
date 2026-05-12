// Account bottom-sheet shown when the user taps the account avatar in the
// app bar.
//
// Extracted from DashboardScreen._showAccountBottomSheet to reduce file size.
// Like a Vue modal component (`<AccountModal>`) that handles profile display,
// role switching, school switching, settings navigation, and logout.
//
// Uses ConsumerStatefulWidget because it needs:
// - Local state for loading flags (isLoggingOut, switchingRole)
// - WidgetRef to call dashboardProvider.notifier.switchRole / logout
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_profile_components.dart';
import 'package:manajemensekolah/features/account/data/profile_service.dart';
import 'package:manajemensekolah/features/dashboard/presentation/'
    'controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/dashboard_account_sheet_header_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/dashboard_account_sheet_role_mixin.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mixins/dashboard_account_sheet_actions_mixin.dart';

/// The content widget shown inside [showModalBottomSheet] on the dashboard.
///
/// Caller is responsible for opening the sheet; this widget owns the inner
/// tree. Pass [state], [primaryColor], [effectiveRole], and
/// [onShowSchoolSelection] (a callback into the parent to open the
/// school-selection dialog, since that dialog itself needs access to the
/// stable widget context of the parent screen).
class DashboardAccountSheet extends ConsumerStatefulWidget {
  final DashboardState state;
  final Color primaryColor;
  final String effectiveRole;

  /// Called when the user taps "Switch School".
  final VoidCallback onShowSchoolSelection;

  /// Called when the user wants to switch app language.
  final VoidCallback onLanguageTap;

  /// Called when the user taps "Switch Role".
  final void Function(String schoolId, List<String> roleList)
  onShowRoleSelection;

  const DashboardAccountSheet({
    super.key,
    required this.state,
    required this.primaryColor,
    required this.effectiveRole,
    required this.onShowSchoolSelection,
    required this.onLanguageTap,
    required this.onShowRoleSelection,
  });

  @override
  ConsumerState<DashboardAccountSheet> createState() =>
      _DashboardAccountSheetState();
}

class _DashboardAccountSheetState extends ConsumerState<DashboardAccountSheet>
    with
        DashboardAccountSheetHeaderMixin,
        DashboardAccountSheetRoleMixin,
        DashboardAccountSheetActionsMixin {
  // ValueNotifiers instead of plain booleans so only the affected subtree
  // rebuilds on change — not the entire bottom sheet.
  //
  // Before: setState() on _isLoggingOut rebuilt the whole sheet (user info
  // row, all role tiles, school/settings buttons, and the logout button).
  // After: only the logout button's ListenableBuilder subtree rebuilds.
  //
  // Similarly, _switchingRole now only rebuilds the role-tiles Column.
  final _isLoggingOut = ValueNotifier<bool>(false);
  final _switchingRole = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _isLoggingOut.dispose();
    _switchingRole.dispose();
    super.dispose();
  }

  String get _userName =>
      (widget.state.userData['name'] ??
              widget.state.userData['nama'] ??
              'Pengguna')
          .toString();

  String get _userEmail => (widget.state.userData['email'] ?? '').toString();

  String get _initial {
    final n = _userName.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  String get _schoolName =>
      (widget.state.userData['school_name'] ??
              widget.state.userData['nama_sekolah'] ??
              '-')
          .toString();

  /// True when the active role is admin — switches the top of the
  /// sheet from the legacy white avatar row to the new
  /// [IdentityHero] + [RoleScopeChips] block (Mockup #15). Other
  /// roles keep the existing layout to avoid disrupting parent and
  /// teacher flows.
  bool get _isAdminVariant => widget.effectiveRole == 'admin';

  @override
  Widget build(BuildContext context) {
    ref.watch(languageRiverpod);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      // Clip so the navy IdentityHero gradient (admin variant)
      // honours the rounded top corners.
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 20 + bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top hero / drag handle (no horizontal padding) ──
            if (_isAdminVariant)
              _buildAdminIdentityHero(context)
            else
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

            // ── Body (24px horizontal padding) ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isAdminVariant) ...[
                    _buildLegacyAvatarRow(context),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 16),

                  // Lihat Profil Lengkap
                  buildLihatProfilTile(context),
                  const SizedBox(height: 20),

                  // Divider
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // AKSES SAYA section
                  Text(
                    AppLocalizations.myAccess.tr.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Peran aktif row
                  () {
                    final roles = widget.state.availableRoles;
                    final hasMultiple = roles.length > 1;
                    return _AccessRow(
                      icon: Icons.person_outline,
                      iconColor: widget.primaryColor,
                      label: AppLocalizations.activeRole.tr,
                      value: roleDisplayName(widget.effectiveRole),
                      action: hasMultiple
                          ? AppLocalizations.switchAction.tr
                          : '',
                      isActive: true,
                      accentColor: widget.primaryColor,
                      onTap: hasMultiple
                          ? () {
                              final sId =
                                  (widget.state.userData['school_id'] ?? '')
                                      .toString();
                              final rList = roles
                                  .map((e) => e.toString())
                                  .toList();
                              Navigator.pop(context);
                              widget.onShowRoleSelection(sId, rList);
                            }
                          : () {},
                    );
                  }(),
                  const SizedBox(height: 8),

                  // Sekolah aktif row
                  () {
                    final schools = widget.state.accessibleSchools;
                    final hasMultiple = schools.length > 1;
                    return _AccessRow(
                      icon: Icons.school_outlined,
                      iconColor: const Color(0xFF10B981),
                      label: AppLocalizations.activeSchool.tr,
                      value: _schoolName,
                      action: hasMultiple
                          ? AppLocalizations.switchAction.tr
                          : '',
                      onTap: hasMultiple
                          ? () {
                              Navigator.pop(context);
                              widget.onShowSchoolSelection();
                            }
                          : () {},
                    );
                  }(),
                  const SizedBox(height: 12),

                  // Divider before Bahasa
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 16),

                  // Bahasa row
                  _AccessRow(
                    icon: Icons.language_outlined,
                    iconColor: const Color(0xFF6366F1),
                    label: AppLocalizations.language.tr,
                    value:
                        ref.watch(languageRiverpod).currentLanguage ==
                            LanguageProvider.english
                        ? 'English'
                        : 'Bahasa Indonesia',
                    action: AppLocalizations.changeAction.tr,
                    onTap: widget.onLanguageTap,
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 20),

                  // Logout
                  buildLogoutButton(context),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mockup #15 admin variant — full-width navy IdentityHero with
  /// RoleScopeChips below, plus a floating drag-handle + close button
  /// over the gradient.
  Widget _buildAdminIdentityHero(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IdentityHero(
              avatarInitials: _initial,
              name: _userName,
              email: _userEmail.isEmpty ? '—' : _userEmail,
              roleLabel: roleDisplayName(widget.effectiveRole),
              subRoleLabel: _schoolName == '-' ? null : _schoolName,
              padding: const EdgeInsets.fromLTRB(20, 28, 56, 20),
            ),
            // RoleScopeChips lives inside the navy gradient too —
            // wrap it in a same-gradient Container that explicitly
            // takes the full sheet width so the navy paints across
            // the entire row even when the chip content is narrower.
            // (Earlier the Container sized to its child's intrinsic
            // width, which left the right half of the row white.)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: ColorUtils.brandGradient('admin'),
              ),
              child: _ScopeChipsLoader(
                onSelectSchool: (id) {
                  Navigator.pop(context);
                  widget.onShowSchoolSelection();
                },
              ),
            ),
          ],
        ),
        // Drag handle floating over the navy
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        // Close X in top-right of the hero
        Positioned(
          top: 14,
          right: 14,
          child: Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => Navigator.pop(context),
              child: const SizedBox(
                width: 30,
                height: 30,
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Legacy white avatar Row used for parent / teacher roles.
  /// Untouched from the original design so nothing changes for those
  /// flows.
  Widget _buildLegacyAvatarRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            _initial,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: widget.primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _userName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userEmail,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  roleDisplayName(widget.effectiveRole),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: widget.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.pop(context),
            child: const SizedBox(
              width: 30,
              height: 30,
              child: Icon(Icons.close, size: 16, color: Color(0xFF475569)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mixin implementations (abstract getters) ──────────────────────────────

  @override
  DashboardState get sheetState => widget.state;

  @override
  Color get primaryColor => widget.primaryColor;

  @override
  bool get isMounted => mounted;

  @override
  ValueNotifier<bool> get isLoggingOutNotifier => _isLoggingOut;

  @override
  ValueNotifier<String?> get switchingRoleNotifier => _switchingRole;
}

/// Wraps [RoleScopeChips] in a Riverpod consumer so the chip row only
/// renders once `managedSchoolsProvider` resolves. While loading we
/// show nothing (the IdentityHero above is enough); on error we hide
/// silently so the rest of the sheet stays usable.
class _ScopeChipsLoader extends ConsumerWidget {
  final ValueChanged<String> onSelectSchool;
  const _ScopeChipsLoader({required this.onSelectSchool});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(managedSchoolsProvider);
    return async.when(
      data: (result) {
        if (!result.hasMultiple) return const SizedBox.shrink();
        return RoleScopeChips(
          schools: result.schools,
          activeSchoolId: result.activeSchoolId,
          onSelect: onSelectSchool,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AccessRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String action;
  final bool isActive;
  final Color? accentColor;
  final VoidCallback onTap;

  const _AccessRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.action,
    this.isActive = false,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? const Color(0xFFF0F9FF) : Colors.white;
    final border = isActive ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 0.75),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              if (action.isNotEmpty)
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: accentColor ?? const Color(0xFF1A8FBE),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
