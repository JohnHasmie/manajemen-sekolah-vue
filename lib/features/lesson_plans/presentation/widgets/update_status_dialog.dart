// Dialog for updating lesson plan status. Extracted from admin_lesson_plan_screen.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';

class UpdateStatusDialog extends ConsumerStatefulWidget {
  final String lessonPlanId;
  final String currentStatus;
  final String? currentNote;
  final VoidCallback onStatusUpdated;

  const UpdateStatusDialog({
    super.key,
    required this.lessonPlanId,
    required this.currentStatus,
    this.currentNote,
    required this.onStatusUpdated,
  });

  @override
  ConsumerState<UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends ConsumerState<UpdateStatusDialog> {
  bool isUpdating = false;
  late TextEditingController notesController;
  String selectedStatus = 'Pending';

  @override
  void initState() {
    super.initState();
    notesController = TextEditingController(text: widget.currentNote ?? '');
    mapInitialStatus();
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  void mapInitialStatus() {
    // Map Indonesian/Display status to Backend/Value status
    final String status = widget.currentStatus;
    if (status == 'Menunggu' || status == 'Pending') {
      selectedStatus = 'Pending';
    } else if (status == 'Disetujui' || status == 'Approved') {
      selectedStatus = 'Approved';
    } else if (status == 'Ditolak' || status == 'Rejected') {
      selectedStatus = 'Rejected';
    } else {
      selectedStatus = 'Pending';
    }
  }

  Color getPrimaryColor() => ColorUtils.getRoleColor('admin');

  Color getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return ColorUtils.success600;
      case 'Rejected':
        return ColorUtils.error600;
      case 'Pending':
      default:
        return ColorUtils.warning600;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status) {
      case 'Approved':
        return Icons.check_circle_outline;
      case 'Rejected':
        return Icons.cancel_outlined;
      case 'Pending':
      default:
        return Icons.access_time_rounded;
    }
  }

  Future<void> updateStatus() async {
    final bool statusChanged = selectedStatus != widget.currentStatus;
    final bool noteChanged = notesController.text != (widget.currentNote ?? '');

    if (!statusChanged && !noteChanged) {
      AppNavigator.pop(context);
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      await LessonPlanService.updateLessonPlanStatus(
        widget.lessonPlanId,
        selectedStatus,
        catatan: notesController.text.isNotEmpty ? notesController.text : null,
      );
      if (mounted) {
        AppNavigator.pop(context);
        widget.onStatusUpdated();
        SnackBarUtils.showSuccess(context, AppLocalizations.rppStatusUpdated.tr);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, '${AppLocalizations.failedToUpdate.tr}: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Widget buildStatusOption(String value, String label, Color color) {
    final isSelected = selectedStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedStatus = value),
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : ColorUtils.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : ColorUtils.slate200,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.15)
                      : ColorUtils.slate100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getStatusIcon(value),
                  size: 16,
                  color: isSelected ? color : ColorUtils.slate400,
                ),
              ),
              SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = getPrimaryColor();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Gradient Header
          Container(
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Status RPP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ubah status persetujuan RPP',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Form Content
          Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status label
                Text(
                  'Status Persetujuan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                  ),
                ),
                SizedBox(height: 10),
                // Status option chips
                Row(
                  children: [
                    buildStatusOption(
                      'Pending',
                      'Menunggu',
                      ColorUtils.warning600,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    buildStatusOption(
                      'Approved',
                      'Disetujui',
                      ColorUtils.success600,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    buildStatusOption(
                      'Rejected',
                      'Ditolak',
                      ColorUtils.error600,
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xl),
                // Catatan label
                Text(
                  'Catatan (Opsional)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate700,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                // Styled text field
                Container(
                  decoration: BoxDecoration(
                    color: ColorUtils.slate50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ColorUtils.slate200),
                  ),
                  child: TextField(
                    controller: notesController,
                    maxLines: 3,
                    style: TextStyle(color: ColorUtils.slate900, fontSize: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                      hintText: 'Berikan catatan untuk guru...',
                      hintStyle: TextStyle(
                        color: ColorUtils.slate400,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer Buttons
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isUpdating
                        ? null
                        : () => AppNavigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.cancel.tr,
                      style: TextStyle(color: ColorUtils.slate600),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isUpdating ? null : updateStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isUpdating
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Update Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
