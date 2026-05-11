// AdminEntityDetailSheet — canonical detail view for any admin entity
// (Siswa, Guru, Kelas, Mapel, Jadwal, …) shown as a full-height bottom
// sheet rather than a separate route.
//
// Mirrors the v3 actions mockup (frame A): admin-navy hero band with a
// gradient avatar + close ✕ + kicker + bold title + meta + status pill,
// then a scrollable body of label/value sections, then a Hapus / Edit
// footer pinned to the bottom.
//
// Why a sheet instead of a screen
// -------------------------------
// Every admin detail today (StudentDetailScreen / TeacherDetailScreen /
// ClassDetailDialog / ScheduleDetailDialog) re-implements its own
// gradient header, scroll body, edit/delete actions, safe-area handling,
// and back-navigation. Moving the visual into a single shared sheet:
//   • removes 4× per-feature header/scaffold code,
//   • locks the v3 mockup look across roles in one place,
//   • makes the sheet dismiss-then-edit pattern (close → showSheet) trivial.
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
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';

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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // useSafeArea: false — the navy hero band owns its own top inset so
    // the gradient can extend behind the status bar without a white gap.
    useSafeArea: false,
    builder: (_) => _AdminEntityDetailSheet(
      kicker: kicker,
      title: title,
      meta: meta,
      initials: initials ?? title,
      status: status,
      role: role ?? 'admin',
      sections: sections,
      onEdit: onEdit,
      onDelete: onDelete,
      isReadOnly: isReadOnly,
    ),
  );
}

class _AdminEntityDetailSheet extends StatelessWidget {
  final String kicker;
  final String title;
  final String meta;
  final String initials;
  final EntityStatus? status;
  final String role;
  final List<EntityDetailSection> sections;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isReadOnly;

  const _AdminEntityDetailSheet({
    required this.kicker,
    required this.title,
    required this.meta,
    required this.initials,
    required this.status,
    required this.role,
    required this.sections,
    required this.onEdit,
    required this.onDelete,
    required this.isReadOnly,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor(role);
    // Full-height sheet so the navy hero band can extend behind the
    // status bar with no white strip above. The hero's own top padding
    // pushes its content below the status bar.
    final maxHeight = MediaQuery.of(context).size.height;
    final canEdit = onEdit != null && !isReadOnly;
    final canDelete = onDelete != null && !isReadOnly;
    final showFooter = canEdit || canDelete;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        // Top corners stay rounded for visual continuity with other sheets
        // but the navy hero fills the radius cleanly.
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Material(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hero band — owns the drag handle so the navy gradient
              // draws flush against the rounded top edge (no white strip).
              _HeroBand(
                accent: accent,
                kicker: kicker,
                title: title,
                meta: meta,
                initials: initials,
                status: status,
              ),
              // Scrollable body
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 18),
                  itemBuilder: (_, i) =>
                      _DetailSectionView(section: sections[i], accent: accent),
                ),
              ),
              if (showFooter)
                _Footer(
                  accent: accent,
                  onEdit: canEdit ? onEdit : null,
                  onDelete: canDelete ? onDelete : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBand extends StatelessWidget {
  final Color accent;
  final String kicker;
  final String title;
  final String meta;
  final String initials;
  final EntityStatus? status;

  const _HeroBand({
    required this.accent,
    required this.kicker,
    required this.title,
    required this.meta,
    required this.initials,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Sheet is rendered without `useSafeArea`, so the hero owns the top
    // inset (status bar + notch). The navy gradient now extends edge-to-
    // edge — no white strip above the hero, even on devices with cameras
    // bumps or large status bars.
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: ColorUtils.brandGradient('admin')),
      padding: EdgeInsets.fromLTRB(20, topInset + 8, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle — sits ON the gradient with white opacity.
          Center(
            child: Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Top row — close icon trailing
          Row(
            children: [
              const Spacer(),
              _CloseButton(onTap: () => AppNavigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          // Avatar + meta block
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InitialsAvatar(
                name: initials,
                size: 64,
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: 16,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kicker.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF9DC4E8),
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF9DC4E8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 12),
            _StatusPill(status: status!),
          ],
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color,
        borderRadius: const BorderRadius.all(Radius.circular(11)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
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

class _Footer extends StatelessWidget {
  final Color accent;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _Footer({
    required this.accent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (onDelete != null)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.4),
                  foregroundColor: const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  AppNavigator.pop(context);
                  onDelete!();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(
                  'Hapus',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          if (onDelete != null && onEdit != null) const SizedBox(width: 10),
          if (onEdit != null)
            Expanded(
              flex: onDelete == null ? 1 : 1,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  AppNavigator.pop(context);
                  onEdit!();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Edit Data',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
