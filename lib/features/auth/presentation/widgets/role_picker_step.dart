// Role picker (Frame E of
// `_design/auth_login_school_role_redesign.html`). Renders accent-bar
// cards in the role colour (admin navy / guru cobalt / wali azure),
// each with a role icon + description + stats row, and a sticky CTA.
//
// Tracks a *candidate* selection locally and only fires the network
// call on the Lanjutkan tap, matching the mockup's two-step pattern.
//
// Extracted from `auth_form_builder_mixin.dart` as part of a structural
// readability split — behavior is unchanged.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/auth_controller.dart';
import 'package:manajemensekolah/features/auth/presentation/widgets/auth_picker_shared.dart';

class RolePickerStep extends StatefulWidget {
  final AuthState authState;
  final String Function(String role) getRoleDisplayName;
  final String Function(String role) getRoleDescription;
  final Color Function(String role) getRoleColor;
  final IconData Function(String role) getRoleIconData;
  final List<String> Function(String role) getRoleStats;
  final Future<void> Function(String role) onConfirm;
  final VoidCallback onBackToLogin;

  const RolePickerStep({
    super.key,
    required this.authState,
    required this.getRoleDisplayName,
    required this.getRoleDescription,
    required this.getRoleColor,
    required this.getRoleIconData,
    required this.getRoleStats,
    required this.onConfirm,
    required this.onBackToLogin,
  });

  @override
  State<RolePickerStep> createState() => _RolePickerStepState();
}

class _RolePickerStepState extends State<RolePickerStep> {
  String? _candidateRole;

  String? _firstRole() {
    final list = widget.authState.roleList;
    if (list.isEmpty) return null;
    return list.first.toString();
  }

  @override
  Widget build(BuildContext context) {
    final schoolName =
        widget.authState.selectedSchool?['school_name'] ??
        widget.authState.selectedSchool?['name'] ??
        widget.authState.selectedSchool?['nama_sekolah'] ??
        widget.authState.userData?['school_name'] ??
        widget.authState.userData?['nama_sekolah'] ??
        '-';
    final roles = widget.authState.roleList
        .map((r) => r.toString())
        .toList(growable: false);
    final candidate = _candidateRole ?? _firstRole();
    final candidateColor = candidate == null
        ? ColorUtils.brandCobalt
        : widget.getRoleColor(candidate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PickerHeader(
          kicker: schoolName.toString().toUpperCase(),
          title: 'Pilih Peran',
          subtitle: roles.length <= 1
              ? 'Lanjutkan sebagai…'
              : 'Anda memiliki ${roles.length} peran di sekolah ini.',
          stepDots: const StepDots(active: 2, total: 3),
        ),
        const SizedBox(height: 14),
        for (final r in roles)
          _RoleCard(
            role: r,
            label: widget.getRoleDisplayName(r),
            description: widget.getRoleDescription(r),
            stats: widget.getRoleStats(r),
            color: widget.getRoleColor(r),
            icon: widget.getRoleIconData(r),
            active: candidate == r,
            onTap: () => setState(() => _candidateRole = r),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ColorUtils.slate200,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: ColorUtils.slate500,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Anda dapat berpindah peran kapan saja dari menu profil.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PickerFooterCta(
          primaryLabel: candidate == null
              ? 'Lanjutkan'
              : 'Lanjut Sebagai ${widget.getRoleDisplayName(candidate)}',
          primaryEnabled: candidate != null && !widget.authState.isLoading,
          primaryColor: candidateColor,
          isLoading: widget.authState.isLoading,
          onPrimary: () async {
            if (candidate != null) {
              await widget.onConfirm(candidate);
            }
          },
          onSecondary: widget.onBackToLogin,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  final String label;
  final String description;
  final List<String> stats;
  final Color color;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.label,
    required this.description,
    required this.stats,
    required this.color,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? color : ColorUtils.slate200,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              // Left accent bar in the role's own colour — admin navy /
              // guru cobalt / wali azure per the brand tokens.
              Positioned.fill(
                left: 0,
                right: null,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: ColorUtils.slate900,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: ColorUtils.slate500,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (active)
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: ColorUtils.slate400,
                          ),
                      ],
                    ),
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final s in stats)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ColorUtils.slate200),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: ColorUtils.slate700,
                                ),
                              ),
                            ),
                        ],
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
