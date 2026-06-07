// AdminEntityDetailSheet — canonical detail view for any admin entity
// (Siswa, Guru, Kelas, Mapel, Jadwal, …) shown as a bottom sheet.
//
// Built on top of the shared [AppBottomSheet] scaffold so it inherits
// the app-wide max-height (0.85), border radius (24), DragHandle,
// gradient header, scrollable body, and footer conventions.
//
// Caller pattern:
// ```dart
// await showAdminEntityDetailSheet(
//   context,
//   kicker: 'SISWA',
//   title: model.name,
//   meta: '7A · NIS 1234567',
//   initials: 'AY',
//   status: const EntityStatus(label: 'Aktif',
//                              color: Color(0xFF15803D)),
//   sections: [
//     EntityDetailSection(label: 'DATA AKADEMIK', rows: [
//       EntityDetailRow(label: 'Kelas', value: '7-A · Reguler'),
//       EntityDetailRow(label: 'Tingkat', value: '7 (SMP)'),
//     ]),
//   ],
//   onEdit: _openEdit,
//   onDelete: _delete,
// );
// ```
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';

import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Pill rendered in the top-right of the hero band — typically the
/// entity's primary status (Aktif, Nonaktif, Cuti, etc.).
class EntityStatus {
  final String label;
  final Color color;

  const EntityStatus({required this.label, required this.color});

  factory EntityStatus.success(String label) =>
      EntityStatus(label: label, color: const Color(0xFF15803D));
  factory EntityStatus.warning(String label) =>
      EntityStatus(label: label, color: const Color(0xFFB45309));
  factory EntityStatus.danger(String label) =>
      EntityStatus(label: label, color: const Color(0xFFDC2626));
}

/// One label/value row inside an [EntityDetailSection].
class EntityDetailRow {
  /// Caption shown above the value (e.g. `Kelas`).
  final String label;

  /// Value text (e.g. `7-A · Reguler`).
  final String value;

  /// Optional drill-down callback. When non-null, the row gets a chevron
  /// and the value is rendered in the brand color.
  final VoidCallback? onTap;

  /// Optional copy / share / link icon at the end of the row.
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;

  const EntityDetailRow({
    required this.label,
    required this.value,
    this.onTap,
    this.trailingIcon,
    this.onTrailingTap,
  });
}

/// One labelled group of detail rows. Renders as an uppercase section
/// header + a slate-tinted card containing the rows.
class EntityDetailSection {
  /// Uppercase heading (e.g. `DATA AKADEMIK`).
  final String label;

  /// Rows inside the card. Dividers are rendered between them
  /// automatically.
  final List<EntityDetailRow> rows;

  /// Optional trailing widget at the right of the section header (e.g.
  /// a "Lihat semua" link or "+ Tambah" mini-button).
  final Widget? trailing;

  const EntityDetailSection({
    required this.label,
    required this.rows,
    this.trailing,
  });
}

/// Show the canonical admin entity detail sheet. Resolves once the user
/// dismisses the sheet (no return value — actions fire their own callbacks).
Future<void> showAdminEntityDetailSheet(
  BuildContext context, {
  required String kicker,
  required String title,
  required String meta,
  String? initials,
  EntityStatus? status,
  String? role,
  required List<EntityDetailSection> sections,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  bool isReadOnly = false,
}) {
  final effectiveRole = role ?? 'admin';
  final accent = ColorUtils.getRoleColor(effectiveRole);
  final canEdit = onEdit != null && !isReadOnly;
  final canDelete = onDelete != null && !isReadOnly;

  // Build the scrollable body content (sections list).
  final body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Identity card — avatar + name + meta + status pill
      _IdentityCard(
        kicker: kicker,
        title: title,
        meta: meta,
        initials: initials ?? title,
        status: status,
      ),
      const SizedBox(height: 18),
      // Detail sections
      for (var i = 0; i < sections.length; i++) ...[
        _DetailSectionView(section: sections[i], accent: accent),
        if (i < sections.length - 1) const SizedBox(height: 18),
      ],
    ],
  );

  // Build footer using BottomSheetFooter if edit/delete are available.
  Widget? footer;
  if (canEdit || canDelete) {
    footer = BottomSheetFooter(
      primaryLabel: kCorWidEditData.tr,
      secondaryLabel: kDelete.tr,
      primaryColor: accent,
      onPrimary: () {
        AppNavigator.pop(context);
        onEdit?.call();
      },
      onSecondary: () {
        AppNavigator.pop(context);
        onDelete?.call();
      },
      secondaryDestructive: true,
    );
  }

  // Construct sheetTitle based on kicker and current active language.
  final isIndonesian = languageProvider.currentLanguage == 'id';
  final displayKicker = kicker
      .toLowerCase()
      .split(' ')
      .map((word) {
        if (word.isEmpty) return '';
        return word[0].toUpperCase() + word.substring(1);
      })
      .join(' ');

  final sheetTitle = isIndonesian
      ? 'Detail $displayKicker'
      : '$displayKicker Detail';

  return AppBottomSheet.show<void>(
    context: context,
    title: sheetTitle,
    subtitle: null,
    icon: Icons.person_rounded,
    primaryColor: accent,
    content: body,
    footer: footer,
    contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Internal widgets
// ─────────────────────────────────────────────────────────────────────

/// Identity card — avatar disc + kicker + name + meta + status pill.
/// Sits at the top of the scrollable body, inside a branded card.
class _IdentityCard extends StatelessWidget {
  final String kicker;
  final String title;
  final String meta;
  final String initials;
  final EntityStatus? status;

  const _IdentityCard({
    required this.kicker,
    required this.title,
    required this.meta,
    required this.initials,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ColorUtils.brandGradient('admin'),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InitialsAvatar.onDark(name: initials, size: 56, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kicker.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF9DC4E8),
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9DC4E8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 8),
                  _StatusPill(status: status!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final EntityStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSectionView extends StatelessWidget {
  final EntityDetailSection section;
  final Color accent;

  const _DetailSectionView({required this.section, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                section.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (section.trailing != null) section.trailing!,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(
            children: [
              for (var i = 0; i < section.rows.length; i++) ...[
                _DetailRowView(row: section.rows[i], accent: accent),
                if (i < section.rows.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: ColorUtils.slate200,
                    indent: 14,
                    endIndent: 14,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRowView extends StatelessWidget {
  final EntityDetailRow row;
  final Color accent;

  const _DetailRowView({required this.row, required this.accent});

  @override
  Widget build(BuildContext context) {
    final isInteractive = row.onTap != null;
    final valueColor = isInteractive ? accent : ColorUtils.slate900;

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              row.value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
          if (row.trailingIcon != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: row.onTrailingTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(row.trailingIcon, size: 16, color: accent),
              ),
            ),
          ] else if (isInteractive) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ColorUtils.slate400,
            ),
          ],
        ],
      ),
    );

    if (!isInteractive) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: row.onTap, child: body),
    );
  }
}
