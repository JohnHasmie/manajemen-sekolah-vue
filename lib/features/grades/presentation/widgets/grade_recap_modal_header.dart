import 'package:flutter/material.dart';

/// Custom header for the modal-style entry of the grade recap screen.
///
/// Matches the app's "Buku Nilai" design language:
/// - A grabber at the top hints the page is a modal/sheet.
/// - A rounded leading icon badge identifies the screen.
/// - Title + subtitle describe the subject/class context.
/// - Right-aligned action buttons expose Export and Close affordances.
///
/// Unlike [TeacherPageHeader], this widget intentionally puts the dismissal
/// control on the right (next to Export), matching other modal screens in
/// the app.
class GradeRecapModalHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color primaryColor;

  /// Fires when the Export icon is tapped.
  final VoidCallback onExport;

  /// Whether an export is currently in-flight. Shows a spinner in place
  /// of the download icon and blocks taps.
  final bool isExporting;

  /// Fires when the Close (×) icon is tapped.
  final VoidCallback onClose;

  /// Optional key for the Export affordance so the onboarding tour can
  /// target it.
  final Key? exportKey;

  const GradeRecapModalHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onExport,
    required this.onClose,
    this.isExporting = false,
    this.exportKey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 14,
        right: 14,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grabber hints that this is a modal/dismissible surface.
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading icon badge (decorative).
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right-aligned action cluster.
              _HeaderActionButton(
                key: exportKey,
                icon: Icons.download_rounded,
                onTap: onExport,
                isLoading: isExporting,
                tooltip: 'Export',
              ),
              const SizedBox(width: 6),
              _HeaderActionButton(
                icon: Icons.close_rounded,
                onTap: onClose,
                tooltip: 'Tutup',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A 42×42 translucent square icon button used in the modal header's
/// right-action cluster.
class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;
  final String? tooltip;

  const _HeaderActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}
