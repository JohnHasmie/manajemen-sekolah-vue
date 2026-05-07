import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';

/// Builds the gradient header for the attendance detail screen.
///
/// Matches Frame B/F from `_design/teacher_attendance_detail_mockup.html`:
///   • back button (‹) + kicker (`PRESENSI · DETAIL` / `PRESENSI · ARSIP`)
///   • title row (`Edit Presensi` / `Lihat Presensi`) with realtime dot —
///     dot is green when canEdit, slate when read-only.
///   • context strip showing the subject icon, `subject · class`, and
///     a date · lesson-hour subtitle.
mixin TeacherAttendanceDetailHeaderMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  /// Get primary color for the role
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');

  /// Build header with subject and class info
  Widget buildHeader(
    BuildContext context,
    LanguageProvider languageProvider, {
    TeacherAttendanceState? state,
    bool isLoading = false,
  }) {
    final primary = getPrimaryColor();
    final canEdit = widget.canEdit;
    final dotColor = canEdit ? ColorUtils.success600 : ColorUtils.slate400;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ColorUtils.brandDarkBlue, primary],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          bottom: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: back · (kicker + title) · trailing icon ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _backButton(),
                const SizedBox(width: 12),
                Expanded(child: _titleBlock(languageProvider, dotColor)),
                _trailingIcon(canEdit),
              ],
            ),
            const SizedBox(height: 14),
            // ── Context strip: subject avatar · subject·class · date ──
            _contextStrip(languageProvider),
          ],
        ),
      ),
    );
  }

  Widget _backButton() {
    return GestureDetector(
      onTap: () => AppNavigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _titleBlock(LanguageProvider lp, Color dotColor) {
    final canEdit = widget.canEdit;
    final kicker = canEdit
        ? lp.getTranslatedText({
            'en': 'Attendance · Detail',
            'id': 'Presensi · Detail',
          })
        : lp.getTranslatedText({
            'en': 'Attendance · Archive',
            'id': 'Presensi · Arsip',
          });
    final title = canEdit
        ? lp.getTranslatedText({'en': 'Edit Attendance', 'id': 'Edit Presensi'})
        : lp.getTranslatedText({
            'en': 'View Attendance',
            'id': 'Lihat Presensi',
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          kicker.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.7),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            // Realtime dot.
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: [
                  BoxShadow(
                    color: dotColor.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _trailingIcon(bool canEdit) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        canEdit ? Icons.more_horiz_rounded : Icons.download_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  /// Context strip — subject letter avatar + subject·class title + date /
  /// lesson hour subtitle. Matches the mockup's `.ctx-strip` block.
  Widget _contextStrip(LanguageProvider lp) {
    final dateStr = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(widget.date);
    final lessonHour = (widget.lessonHourName ?? '').trim();
    final subtitleParts = <String>[
      dateStr,
      if (lessonHour.isNotEmpty) lessonHour,
    ];
    final subtitle = subtitleParts.join(' · ');
    final initial = widget.subjectName.isNotEmpty
        ? widget.subjectName[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: TextStyle(
                color: getPrimaryColor(),
                fontWeight: FontWeight.w900,
                fontSize: 15,
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
                  '${widget.subjectName} · ${widget.className}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
