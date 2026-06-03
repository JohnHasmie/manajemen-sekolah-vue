import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Sticky bottom bar with print/share affordances for the rapor detail
/// screen. Layout adapts to role:
///
/// * **wali / guru** — [Bagikan] [Cetak PDF]. Cetak calls `onPrintRaport`
///   (or `onPrintCertificate` for wali; controlled by the caller via
///   `defaultVariant`).
/// * **admin** — [Cetak Raport] [Cetak E-Raport]. Both formats are
///   exposed side-by-side; admin doesn't share via the bottom bar.
///
/// When [isPublished] is false (rapor still a draft), both Cetak buttons
/// render disabled with a `'Belum tersedia (draft)'` hint and don't fire
/// their handlers.
class ParentRaporBottomActionBar extends StatelessWidget {
  const ParentRaporBottomActionBar({
    super.key,
    required this.role,
    required this.isPublished,
    this.onShare,
    this.onPrintRaport,
    this.onPrintCertificate,
  });

  /// One of `'wali' | 'guru' | 'admin'`. Drives layout + accent color.
  final String role;

  /// True when the rapor has been published. Disables both Cetak CTAs
  /// when false because the backend export endpoint will 404.
  final bool isPublished;

  /// Share callback — only used in the wali/guru layout.
  final VoidCallback? onShare;

  /// Print using the official `raport.pdf` Blade template (full doc).
  /// Used by the "Cetak PDF" CTA on guru, by "Cetak Raport" on admin.
  final VoidCallback? onPrintRaport;

  /// Print using the `raport.certificate` Blade template (modern style).
  /// Used by the "Cetak PDF" CTA on wali, by "Cetak E-Raport" on admin.
  final VoidCallback? onPrintCertificate;

  bool get _isAdmin => role == 'admin' || role == 'administrator';

  Color get _accent => ColorUtils.getRoleColor(role);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isPublished) ...[
            _DraftHintRow(accent: _accent),
            const SizedBox(height: 8),
          ],
          _isAdmin ? _buildAdminRow() : _buildDefaultRow(),
        ],
      ),
    );
  }

  // ── wali / guru variant ─────────────────────────────────────────────
  Widget _buildDefaultRow() {
    final printHandler = role == 'wali' ? onPrintCertificate : onPrintRaport;
    return Row(
      children: [
        Expanded(
          child: _ghostButton(
            label: 'Bagikan',
            icon: Icons.ios_share_rounded,
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _primaryButton(
            label: 'Cetak PDF',
            icon: Icons.picture_as_pdf_outlined,
            onTap: isPublished ? printHandler : null,
          ),
        ),
      ],
    );
  }

  // ── admin variant ───────────────────────────────────────────────────
  Widget _buildAdminRow() {
    return Row(
      children: [
        Expanded(
          child: _outlinedAccentButton(
            label: 'Cetak Raport',
            icon: Icons.description_outlined,
            onTap: isPublished ? onPrintRaport : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _primaryButton(
            label: 'Cetak E-Raport',
            icon: Icons.picture_as_pdf_outlined,
            onTap: isPublished ? onPrintCertificate : null,
          ),
        ),
      ],
    );
  }

  Widget _ghostButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: ColorUtils.slate700),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: ColorUtils.slate200),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? _accent : ColorUtils.slate200,
          disabledBackgroundColor: ColorUtils.slate200,
          disabledForegroundColor: ColorUtils.slate500,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _outlinedAccentButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    final fg = enabled ? _accent : ColorUtils.slate400;
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: fg),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: enabled
                ? _accent.withValues(alpha: 0.45)
                : ColorUtils.slate200,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _DraftHintRow extends StatelessWidget {
  const _DraftHintRow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: const Color(0xFFFDE68A), width: 0.75),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFFB45309)),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Rapor masih draft — cetak PDF belum tersedia',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
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
