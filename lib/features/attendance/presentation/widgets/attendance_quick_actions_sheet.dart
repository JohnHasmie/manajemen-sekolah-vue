// Quick actions sheet — Frame C from
// `_design/teacher_attendance_detail_mockup.html`.
//
// Bottom sheet from the "⚡ Cepat" toolbar button. Replaces the legacy
// 5-status tile grid with a list of focused bulk actions:
//
//   • Tandai semua Hadir            override every student → hadir
//   • Sisanya Alpa                  only students without a mark yet
//   • Reset semua ke kosong         clear every student's mark
//
// Each row is rendered as a `_SheetButton` matching the mockup's
// `.sheet-btn` block: tinted icon tile + lead/desc text + chevron.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class AttendanceQuickActionsSheet extends StatelessWidget {
  final LanguageProvider languageProvider;

  /// Override every student's status (e.g. "Tandai semua Hadir").
  final void Function(String status) onStatusSelected;

  /// Apply a status only to students that don't have a status yet
  /// (mockup's "Sisanya Alpa"). Optional — when null, that row is
  /// hidden so callers without the wiring don't show a dead button.
  final void Function(String status)? onFillUnmarked;

  /// Reset every student to "no status" (mockup's "Reset semua ke
  /// kosong"). Optional — same reason as `onFillUnmarked`.
  final VoidCallback? onResetAll;

  /// "Salin dari sesi terakhir" — copy attendance from the teacher's
  /// most recent session. Optional. When null the row is hidden.
  /// `subtitle` shows the source session label e.g. "Matematika · 7B
  /// · 11 Apr"; pass null when there's no last session yet so the
  /// row stays disabled.
  final VoidCallback? onCopyFromLastSession;
  final String? lastSessionLabel;

  /// "Pindah tanggal / sesi" — opens Frame D so the teacher can
  /// switch slots without leaving the take-attendance flow.
  final VoidCallback? onMoveDateOrSession;

  const AttendanceQuickActionsSheet({
    super.key,
    required this.languageProvider,
    required this.onStatusSelected,
    this.onFillUnmarked,
    this.onResetAll,
    this.onCopyFromLastSession,
    this.lastSessionLabel,
    this.onMoveDateOrSession,
  });

  String _tr(Map<String, String> map) =>
      languageProvider.getTranslatedText(map);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        // Scroll the body so the sheet still works on short phones
        // when all five tiles are visible. The host opens the sheet
        // with `isScrollControlled: true`, which sizes the modal to
        // its content; this scroll view kicks in only when content
        // still exceeds the device height (e.g. with a keyboard up).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              const SizedBox(height: 12),
              _buildTitle(),
            _buildSubtitle(),
            const SizedBox(height: 8),
            _SheetButton(
              icon: Icons.check_rounded,
              iconBg: const Color(0xFFDCFCE7),
              iconFg: ColorUtils.success600,
              title: _tr({
                'en': 'Mark all Present',
                'id': 'Tandai semua Hadir',
              }),
              desc: _tr({
                'en': 'Override any current status',
                'id': 'Override status manapun',
              }),
              onTap: () {
                Navigator.pop(context);
                onStatusSelected('hadir');
              },
            ),
            if (onFillUnmarked != null)
              _SheetButton(
                icon: Icons.close_rounded,
                iconBg: const Color(0xFFFEE2E2),
                iconFg: ColorUtils.error600,
                title: _tr({'en': 'Remaining as Absent', 'id': 'Sisanya Alpa'}),
                desc: _tr({
                  'en': 'Only for students not yet marked',
                  'id': 'Hanya untuk siswa belum dinilai',
                }),
                onTap: () {
                  Navigator.pop(context);
                  onFillUnmarked!('alpha');
                },
              ),
            if (onCopyFromLastSession != null)
              _SheetButton(
                icon: Icons.content_copy_rounded,
                iconBg: const Color(0xFFEFF6FF),
                iconFg: ColorUtils.info600,
                title: _tr({
                  'en': 'Copy from last session',
                  'id': 'Salin dari sesi terakhir',
                }),
                desc:
                    lastSessionLabel ??
                    _tr({
                      'en': 'No previous session found',
                      'id': 'Belum ada sesi sebelumnya',
                    }),
                onTap: () {
                  Navigator.pop(context);
                  onCopyFromLastSession!();
                },
              ),
            if (onResetAll != null)
              _SheetButton(
                icon: Icons.refresh_rounded,
                iconBg: const Color(0xFFF5F3FF),
                iconFg: ColorUtils.violet700,
                title: _tr({
                  'en': 'Reset all to empty',
                  'id': 'Reset semua ke kosong',
                }),
                desc: _tr({
                  'en': 'Clear every status — nothing saved',
                  'id': 'Hapus semua status — tidak ada yang disimpan',
                }),
                onTap: () {
                  Navigator.pop(context);
                  onResetAll!();
                },
              ),
            if (onMoveDateOrSession != null)
              _SheetButton(
                icon: Icons.calendar_month_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconFg: const Color(0xFFB45309),
                title: _tr({
                  'en': 'Switch date / session',
                  'id': 'Pindah tanggal / sesi',
                }),
                desc: _tr({
                  'en': 'Change hour, subject, or class',
                  'id': 'Ubah jam, mapel, atau kelas',
                }),
                onTap: () {
                  Navigator.pop(context);
                  onMoveDateOrSession!();
                },
              ),
            const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: ColorUtils.slate300,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _tr({'en': 'Quick actions', 'id': 'Aksi cepat'}),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: ColorUtils.slate900,
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          _tr({
            'en':
                'Apply to every student or only the ones without a '
                'status yet.',
            'id':
                'Terapkan ke seluruh siswa atau hanya yang belum '
                'dinilai.',
          }),
          style: TextStyle(
            fontSize: 11,
            color: ColorUtils.slate500,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Individual list-style action — tinted icon tile + title + desc + chev.
class _SheetButton extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: iconFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: ColorUtils.slate500,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: ColorUtils.slate300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
