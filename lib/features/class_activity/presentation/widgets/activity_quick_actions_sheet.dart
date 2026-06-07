// Quick actions sheet for an activity — Frame D from
// `_design/teacher_class_activity_mockup.html`.
//
// Bottom sheet with four list-style actions:
//   • Salin tautan        — copy a deep link to share
//   • Duplikat ke kelas lain — clone the activity to N other classes
//   • Ekspor PDF          — download a printable summary
//   • Hapus kegiatan      — destructive, red row
//
// Each row uses the .sheet-btn pattern (tinted icon tile + title +
// desc + chevron) consistent with the absensi quick-actions sheet.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class ActivityQuickActions {
  final VoidCallback? onCopyLink;
  final VoidCallback? onDuplicate;
  final VoidCallback? onExportPdf;
  final VoidCallback? onDelete;

  const ActivityQuickActions({
    this.onCopyLink,
    this.onDuplicate,
    this.onExportPdf,
    this.onDelete,
  });
}

Future<void> showActivityQuickActionsSheet({
  required BuildContext context,
  required ActivityQuickActions actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActivityQuickActionsSheet(actions: actions),
  );
}

class _ActivityQuickActionsSheet extends StatelessWidget {
  final ActivityQuickActions actions;
  const _ActivityQuickActionsSheet({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _handle(),
            const SizedBox(height: 12),
            _title(),
            _subtitle(),
            const SizedBox(height: 8),
            if (actions.onCopyLink != null)
              _SheetButton(
                icon: Icons.link_rounded,
                iconBg: const Color(0xFFDBEAFE),
                iconFg: ColorUtils.info600,
                title: kClaActCopyLink.tr,
                desc: kClaActShareWithTeacherParents.tr,
                onTap: () {
                  Navigator.pop(context);
                  actions.onCopyLink!();
                },
              ),
            if (actions.onDuplicate != null)
              _SheetButton(
                icon: Icons.content_copy_rounded,
                iconBg: const Color(0xFFEDE9FE),
                iconFg: ColorUtils.violet700,
                title: kClaActDuplicateToAnotherClass.tr,
                desc: kClaActCopyToYourClasses.tr,
                onTap: () {
                  Navigator.pop(context);
                  actions.onDuplicate!();
                },
              ),
            if (actions.onExportPdf != null)
              _SheetButton(
                icon: Icons.picture_as_pdf_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconFg: ColorUtils.success600,
                title: kClaActExportPdf.tr,
                desc: kClaActAttachToReport.tr,
                onTap: () {
                  Navigator.pop(context);
                  actions.onExportPdf!();
                },
              ),
            if (actions.onDelete != null)
              _SheetButton(
                icon: Icons.delete_outline_rounded,
                iconBg: const Color(0xFFFEE2E2),
                iconFg: ColorUtils.error600,
                title: kClaActDeleteActivity.tr,
                desc: kClaActCannotBeRecovered.tr,
                titleColor: ColorUtils.error600,
                onTap: () {
                  Navigator.pop(context);
                  actions.onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Container(
    margin: const EdgeInsets.only(top: 12),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: ColorUtils.slate300,
      borderRadius: BorderRadius.circular(999),
    ),
  );

  Widget _title() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        kClaActQuickActions.tr,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: ColorUtils.slate900,
        ),
      ),
    ),
  );

  Widget _subtitle() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        kClaActQuickActionsDesc.tr,
        style: TextStyle(fontSize: 11, color: ColorUtils.slate500, height: 1.4),
      ),
    ),
  );
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String desc;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.desc,
    required this.onTap,
    this.titleColor,
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
            padding: const EdgeInsets.all(12),
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
                          color: titleColor ?? ColorUtils.slate900,
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
