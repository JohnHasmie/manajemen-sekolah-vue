// Admin profile shared components — Mockup #15.
//
// Three new shared widgets used by the admin Profil page and the
// account sheet:
//   • IdentityHero            — navy gradient avatar + name + email +
//                               role chips. Replaces the ad-hoc hero
//                               band in dashboard_account_sheet.
//   • RoleScopeChips          — horizontal scrollable chip row of
//                               schools the admin manages. White-fill
//                               for the active school, translucent
//                               for adjacent ones.
//   • SecurityChecklistCard   — navy-bordered card with progress bar
//                               + per-item checklist (✓/!/×). Each
//                               warn/fail item exposes an inline CTA.
//
// All three live under `lib/core/widgets/` so the same idiom can be
// re-used by future role-specific profile screens (guru / wali). They
// consume only existing tokens (`ColorUtils.*`, `AppSpacing.*`) so
// theme changes propagate automatically.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

// =====================================================================
// IdentityHero
// =====================================================================

/// Hero band for the admin account sheet / profile page.
///
/// Renders a navy gradient panel with a circular avatar, name + email,
/// and a row of role tags. Optional [trailing] slot lets the host
/// embed a "Beralih akun" / close icon at the top-right.
class IdentityHero extends StatelessWidget {
  final String avatarInitials;
  final String name;
  final String email;
  final String roleLabel;
  final String? subRoleLabel;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const IdentityHero({
    super.key,
    required this.avatarInitials,
    required this.name,
    required this.email,
    required this.roleLabel,
    this.subRoleLabel,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: ColorUtils.brandGradient('admin')),
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              avatarInitials.isEmpty
                  ? '?'
                  : avatarInitials.substring(
                      0,
                      avatarInitials.length > 2 ? 2 : avatarInitials.length,
                    ).toUpperCase(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Name block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RoleTag(label: roleLabel),
                    if (subRoleLabel != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          subRoleLabel!,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  final String label;
  const _RoleTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// =====================================================================
// RoleScopeChips
// =====================================================================

/// School scope a single user can switch into.
class SchoolScope {
  final String id;
  final String shortName;
  final String fullName;
  final String? badgeLabel; // "AKTIF", "CABANG 2", etc.

  const SchoolScope({
    required this.id,
    required this.shortName,
    required this.fullName,
    this.badgeLabel,
  });
}

/// Horizontal scrollable row of school chips. Designed to live below
/// an [IdentityHero] inside a hero band — that's why active chips are
/// white-fill (so they read against navy) and others are translucent.
class RoleScopeChips extends StatelessWidget {
  final List<SchoolScope> schools;
  final String activeSchoolId;
  final ValueChanged<String> onSelect;

  /// Max chips rendered before falling back to a "+N" overflow chip
  /// that opens a fuller picker. Defaults to 3.
  final int maxVisible;
  final VoidCallback? onOverflowTap;

  const RoleScopeChips({
    super.key,
    required this.schools,
    required this.activeSchoolId,
    required this.onSelect,
    this.maxVisible = 3,
    this.onOverflowTap,
  });

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) return const SizedBox.shrink();

    final visible = schools.take(maxVisible).toList();
    final overflow = schools.length - visible.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEKOLAH YANG DIKELOLA',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(
              children: [
                for (final s in visible) ...[
                  _SchoolChip(
                    scope: s,
                    active: s.id == activeSchoolId,
                    onTap: () => onSelect(s.id),
                  ),
                  const SizedBox(width: 8),
                ],
                if (overflow > 0)
                  _OverflowChip(
                    count: overflow,
                    onTap: onOverflowTap ?? () {},
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolChip extends StatelessWidget {
  final SchoolScope scope;
  final bool active;
  final VoidCallback onTap;

  const _SchoolChip({
    required this.scope,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final bg = active ? Colors.white : Colors.white.withValues(alpha: 0.18);
    final fg = active ? navy : Colors.white;
    final badgeColor = active
        ? ColorUtils.slate500
        : Colors.white.withValues(alpha: 0.7);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (scope.badgeLabel != null)
                Text(
                  scope.badgeLabel!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              Text(
                scope.shortName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _OverflowChip({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            '+$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// SecurityChecklistCard
// =====================================================================

enum SecurityState { ok, warn, fail }

class SecurityCheck {
  final String label;
  final SecurityState state;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SecurityCheck({
    required this.label,
    required this.state,
    this.actionLabel,
    this.onAction,
  });
}

/// Navy-bordered card summarising the user's account-security posture.
///
/// Top kicker pill ("⚡ Cek keamanan") + headline copy ("Akun Anda 80%
/// aman") + progress bar + checklist of items.
///
/// Each item with an action exposes a tiny inline button that calls
/// [SecurityCheck.onAction] (e.g. push to ChangePasswordScreen).
class SecurityChecklistCard extends StatelessWidget {
  final List<SecurityCheck> items;
  final EdgeInsetsGeometry margin;

  const SecurityChecklistCard({
    super.key,
    required this.items,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  double get _percentSecure {
    if (items.isEmpty) return 1;
    final ok = items.where((c) => c.state == SecurityState.ok).length;
    return ok / items.length;
  }

  String get _headline {
    final pct = (_percentSecure * 100).round();
    if (pct >= 100) return 'Akun Anda 100% aman';
    return 'Akun Anda $pct% aman';
  }

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: navy, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '⚡ Cek keamanan',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: navy,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _headline,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: _percentSecure,
              minHeight: 6,
              backgroundColor: ColorUtils.slate200,
              valueColor: AlwaysStoppedAnimation<Color>(
                _percentSecure >= 1
                    ? const Color(0xFF10B981)
                    : _percentSecure >= 0.66
                        ? const Color(0xFF10B981)
                        : _percentSecure >= 0.33
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++) ...[
            _SecurityRow(item: items[i]),
            if (i < items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SecurityRow extends StatelessWidget {
  final SecurityCheck item;
  const _SecurityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SecurityDot(state: item.state),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: switch (item.state) {
                SecurityState.ok => ColorUtils.slate900,
                SecurityState.warn => const Color(0xFF92400E),
                SecurityState.fail => const Color(0xFF991B1B),
              },
            ),
          ),
        ),
        if (item.actionLabel != null && item.onAction != null) ...[
          const SizedBox(width: 8),
          _InlineSecurityAction(
            label: item.actionLabel!,
            onTap: item.onAction!,
            tone: item.state,
          ),
        ],
      ],
    );
  }
}

class _SecurityDot extends StatelessWidget {
  final SecurityState state;
  const _SecurityDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final (bg, glyph) = switch (state) {
      SecurityState.ok => (const Color(0xFF10B981), Icons.check_rounded),
      SecurityState.warn =>
        (const Color(0xFFF59E0B), Icons.priority_high_rounded),
      SecurityState.fail => (const Color(0xFFDC2626), Icons.close_rounded),
    };
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Icon(glyph, size: 10, color: Colors.white),
    );
  }
}

class _InlineSecurityAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final SecurityState tone;
  const _InlineSecurityAction({
    required this.label,
    required this.onTap,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      SecurityState.ok => ColorUtils.getRoleColor('admin'),
      SecurityState.warn => const Color(0xFF92400E),
      SecurityState.fail => const Color(0xFF991B1B),
    };
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
