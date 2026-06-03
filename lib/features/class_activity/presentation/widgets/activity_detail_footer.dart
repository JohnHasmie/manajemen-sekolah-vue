// Sticky bottom footer for the teacher activity-detail screen.
//
// Extracted verbatim from `_TeacherActivityDetailScreenState`:
//   • [ActivityDetailFooter] — the SafeArea + decorated bar wrapper that
//     was `_buildFooter`. Picks the layout based on [tracksSubmissions].
//   • `_footerWithSubmit` / `_footerEditPrimary` / `_iconActionButton`
//     are now private helpers on this widget.
//
// Layout depends on whether the activity tracks submissions:
//   tugas / ujian / kuis →  [🗑] [✎] [   Catat Submit   ]
//   aktivitas / catatan  →  [   Hapus   ] [   Edit (primary)   ]
//
// The screen wires the callbacks: [onDelete] / [onEdit] come straight from
// the widget props (Edit is null when the parent passes no edit handler),
// and [onRecordSubmit] is the State's `_openCatatSubmit`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Bottom action bar shown only in editable mode (`canEdit=true`).
class ActivityDetailFooter extends StatelessWidget {
  final LanguageProvider lp;

  /// True for tugas/ujian/kuis — switches to the icon-buttons + Catat
  /// Submit primary CTA layout.
  final bool tracksSubmissions;

  /// Hapus handler (may be null).
  final VoidCallback? onDelete;

  /// Edit handler — null disables the Edit button (parent passed no
  /// `onEdit`). The screen supplies its `_onEditPressed` wrapper here.
  final VoidCallback? onEdit;

  /// Opens the submission picker sheet (State's `_openCatatSubmit`).
  final VoidCallback onRecordSubmit;

  const ActivityDetailFooter({
    super.key,
    required this.lp,
    required this.tracksSubmissions,
    required this.onDelete,
    required this.onEdit,
    required this.onRecordSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: tracksSubmissions
            ? _footerWithSubmit(lp)
            : _footerEditPrimary(lp),
      ),
    );
  }

  /// Submission-tracked footer: small icon buttons + full-width
  /// "Catat Submit" primary CTA. Avoids text wrapping at any width.
  Widget _footerWithSubmit(LanguageProvider lp) {
    return Row(
      children: [
        _iconActionButton(
          icon: Icons.delete_outline_rounded,
          color: ColorUtils.error600,
          tooltip: lp.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
          onPressed: onDelete,
        ),
        const SizedBox(width: 8),
        _iconActionButton(
          icon: Icons.edit_rounded,
          color: ColorUtils.slate700,
          tooltip: lp.getTranslatedText({'en': 'Edit', 'id': 'Edit'}),
          onPressed: onEdit,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onRecordSubmit,
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
              label: Text(
                lp.getTranslatedText({
                  'en': 'Record submit',
                  'id': 'Catat Submit',
                }),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.brandCobalt,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Aktivitas / catatan footer: original Hapus | Edit (primary).
  Widget _footerEditPrimary(LanguageProvider lp) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: Text(
                lp.getTranslatedText({'en': 'Delete', 'id': 'Hapus'}),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorUtils.error600,
                side: BorderSide(color: ColorUtils.slate200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text(lp.getTranslatedText({'en': 'Edit', 'id': 'Edit'})),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.brandCobalt,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Square-ish icon-only action button used in the submission footer
  /// so Hapus + Edit don't compete with Catat Submit for label space.
  Widget _iconActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Tooltip(
        message: tooltip,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: ColorUtils.slate200),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
