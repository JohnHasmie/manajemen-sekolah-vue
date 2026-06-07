// Admin Pengumuman compose shared components — Mockup #10.
//
// Two new widgets:
//   • AudienceMatrix       — rows × columns toggle grid (Guru / Wali
//                             Kelas / Wali Murid × Semua / 7 / 8 / 9
//                             / Custom). Tap cells to flip on/off.
//   • AudienceSummaryStrip — navy-tinted live caption showing the
//                             computed reach ("48 guru + 8 wali
//                             kelas (7,8) = 56 orang").
//
// Both are pure presentation widgets — the calling sheet owns the
// state, fetches reach previews from the backend, and composes the
// final outgoing audience_matrix payload.

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

// =====================================================================
// AudienceMatrix
// =====================================================================

/// Identifies one role row in the matrix.
enum AudienceRole { guru, waliKelas, waliMurid }

extension AudienceRoleLabel on AudienceRole {
  String get label {
    switch (this) {
      case AudienceRole.guru:
        return kCorWidTeacher.tr;
      case AudienceRole.waliKelas:
        return kHomeroomTeacher.tr;
      case AudienceRole.waliMurid:
        return kCorWidParent.tr;
    }
  }

  /// Wire-format key used by the backend.
  String get apiKey {
    switch (this) {
      case AudienceRole.guru:
        return 'guru';
      case AudienceRole.waliKelas:
        return 'wali_kelas';
      case AudienceRole.waliMurid:
        return 'wali_murid';
    }
  }
}

/// One column in the matrix. Either a fixed [tingkat] (1-12), the
/// special `'all'` token, or `'custom'` (caller opens a class picker).
class AudienceColumn {
  final String label;
  final Object value; // 'all' | int (tingkat) | 'custom'
  final bool isCustom;
  const AudienceColumn({
    required this.label,
    required this.value,
    this.isCustom = false,
  });

  static const all = AudienceColumn(label: 'Semua', value: 'all');
  static const custom = AudienceColumn(
    label: 'Custom',
    value: 'custom',
    isCustom: true,
  );

  static AudienceColumn tingkat(int t) =>
      AudienceColumn(label: t.toString(), value: t);
}

/// Selected cells expressed as a `Set<(role, columnValue)>`.
class AudienceMatrixSelection {
  final Set<MapEntry<AudienceRole, Object>> cells;
  const AudienceMatrixSelection(this.cells);

  bool contains(AudienceRole role, Object colValue) =>
      cells.any((e) => e.key == role && e.value == colValue);

  bool get isEmpty => cells.isEmpty;
  bool get isNotEmpty => cells.isNotEmpty;

  /// Convert to the backend payload shape:
  ///   { guru: ['all'], wali_kelas: [7, 8], wali_murid: [] }
  Map<String, List<Object>> toApiPayload() {
    final out = <String, List<Object>>{
      'guru': <Object>[],
      'wali_kelas': <Object>[],
      'wali_murid': <Object>[],
    };
    for (final cell in cells) {
      out[cell.key.apiKey]!.add(cell.value);
    }
    return out;
  }

  AudienceMatrixSelection toggle(AudienceRole role, Object colValue) {
    final entry = MapEntry(role, colValue);
    final next = Set<MapEntry<AudienceRole, Object>>.from(cells);
    final existing = next.firstWhere(
      (e) => e.key == role && e.value == colValue,
      orElse: () => const MapEntry(AudienceRole.guru, _Sentinel()),
    );
    if (existing.value is _Sentinel) {
      next.add(entry);
    } else {
      next.remove(existing);
    }
    return AudienceMatrixSelection(next);
  }
}

class _Sentinel {
  const _Sentinel();
}

/// Renders the audience cell grid. Stateless — caller owns the
/// [selection] and rebuilds when it changes.
class AudienceMatrix extends StatelessWidget {
  final List<AudienceRole> rows;
  final List<AudienceColumn> columns;
  final AudienceMatrixSelection selection;
  final void Function(AudienceRole role, Object colValue) onToggle;

  /// Called when the user taps a cell in a [AudienceColumn] flagged
  /// `isCustom: true`. Caller usually opens a class picker sheet.
  final VoidCallback? onCustomTap;

  const AudienceMatrix({
    super.key,
    this.rows = const [
      AudienceRole.guru,
      AudienceRole.waliKelas,
      AudienceRole.waliMurid,
    ],
    required this.columns,
    required this.selection,
    required this.onToggle,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderRow(columns: columns),
            const SizedBox(height: 8),
            Divider(height: 1, color: ColorUtils.slate200),
            const SizedBox(height: 12),
            for (var i = 0; i < rows.length; i++) ...[
              _MatrixRow(
                role: rows[i],
                columns: columns,
                selection: selection,
                onToggle: onToggle,
                onCustomTap: onCustomTap,
              ),
              if (i < rows.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final List<AudienceColumn> columns;
  const _HeaderRow({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 70), // role label gutter
        for (final col in columns) ...[
          Expanded(
            child: Center(
              child: Text(
                col.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MatrixRow extends StatelessWidget {
  final AudienceRole role;
  final List<AudienceColumn> columns;
  final AudienceMatrixSelection selection;
  final void Function(AudienceRole, Object) onToggle;
  final VoidCallback? onCustomTap;

  const _MatrixRow({
    required this.role,
    required this.columns,
    required this.selection,
    required this.onToggle,
    this.onCustomTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            role.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
            ),
          ),
        ),
        for (final col in columns) ...[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _MatrixCell(
                active: selection.contains(role, col.value),
                isCustom: col.isCustom,
                onTap: () {
                  if (col.isCustom && onCustomTap != null) {
                    onCustomTap!();
                  } else {
                    onToggle(role, col.value);
                  }
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MatrixCell extends StatelessWidget {
  final bool active;
  final bool isCustom;
  final VoidCallback onTap;

  const _MatrixCell({
    required this.active,
    required this.isCustom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final bg = active ? navy : Colors.white;
    final border = active ? navy : ColorUtils.slate300;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: active ? 1.4 : 1),
          ),
          child: active
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : (isCustom
                    ? Text(
                        '…',
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : const SizedBox.shrink()),
        ),
      ),
    );
  }
}

// =====================================================================
// AudienceSummaryStrip
// =====================================================================

/// Live navy-tinted band rendered below the matrix. Pure
/// presentation: caller passes `caption` ("48 guru + 8 wali kelas …
/// = 56 orang") and the widget paints it. When [hasAudience] is
/// false the strip turns red.
class AudienceSummaryStrip extends StatelessWidget {
  final String caption;
  final bool hasAudience;

  const AudienceSummaryStrip({
    super.key,
    required this.caption,
    required this.hasAudience,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final bg = hasAudience ? const Color(0xFFEEF2FF) : const Color(0xFFFEF2F2);
    final fg = hasAudience ? navy : const Color(0xFF991B1B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            hasAudience ? Icons.groups_rounded : Icons.error_outline_rounded,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasAudience ? 'Audiens · $caption' : caption,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
