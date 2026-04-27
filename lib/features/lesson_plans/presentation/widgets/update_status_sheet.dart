// Bottom sheet for updating lesson plan (RPP) approval status.
//
// Migrated from the legacy UpdateStatusDialog (Dialog-based) to the shared
// AppBottomSheet + BottomSheetFooter pattern per the Admin Refactor.
//
// Primary entry point: [showUpdateStatusSheet].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';

/// Shows the RPP approval-status update sheet.
///
/// Returns `true` once the status has been successfully updated (caller
/// should refresh its list). Returns `null` if dismissed without change.
Future<bool?> showUpdateStatusSheet({
  required BuildContext context,
  required String lessonPlanId,
  required String currentStatus,
  String? currentNote,
  VoidCallback? onStatusUpdated,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UpdateStatusSheet(
      lessonPlanId: lessonPlanId,
      currentStatus: currentStatus,
      currentNote: currentNote,
      onStatusUpdated: onStatusUpdated,
    ),
  );
}

/// Stateful wrapper that owns the selected-status + notes state and
/// renders them inside an [AppBottomSheet] with a [BottomSheetFooter].
class _UpdateStatusSheet extends ConsumerStatefulWidget {
  final String lessonPlanId;
  final String currentStatus;
  final String? currentNote;
  final VoidCallback? onStatusUpdated;

  const _UpdateStatusSheet({
    required this.lessonPlanId,
    required this.currentStatus,
    this.currentNote,
    this.onStatusUpdated,
  });

  @override
  ConsumerState<_UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends ConsumerState<_UpdateStatusSheet> {
  bool _isUpdating = false;
  late final TextEditingController _notesController;
  String _selectedStatus = 'Pending';

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.currentNote ?? '');
    _mapInitialStatus();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _mapInitialStatus() {
    final status = widget.currentStatus;
    if (status == 'Menunggu' || status == 'Pending') {
      _selectedStatus = 'Pending';
    } else if (status == 'Disetujui' || status == 'Approved') {
      _selectedStatus = 'Approved';
    } else if (status == 'Ditolak' || status == 'Rejected') {
      _selectedStatus = 'Rejected';
    } else {
      _selectedStatus = 'Pending';
    }
  }

  IconData _statusIcon(String status) {
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

  Future<void> _updateStatus() async {
    final statusChanged = _selectedStatus != widget.currentStatus;
    final noteChanged = _notesController.text != (widget.currentNote ?? '');

    if (!statusChanged && !noteChanged) {
      AppNavigator.pop(context, true);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await LessonPlanService.updateLessonPlanStatus(
        widget.lessonPlanId,
        _selectedStatus,
        catatan: _notesController.text.isNotEmpty
            ? _notesController.text
            : null,
      );
      if (!mounted) return;
      AppNavigator.pop(context, true);
      widget.onStatusUpdated?.call();
      SnackBarUtils.showSuccess(
        context,
        AppLocalizations.lessonPlanStatusUpdated.tr,
      );
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${AppLocalizations.failedToUpdate.tr}: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Widget _buildStatusOption(String value, String label, Color color) {
    final isSelected = _selectedStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
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
                  _statusIcon(value),
                  size: 16,
                  color: isSelected ? color : ColorUtils.slate400,
                ),
              ),
              const SizedBox(height: 6),
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
    final primary = ColorUtils.getRoleColor('admin');

    return AppBottomSheet(
      title: 'Update Status RPP',
      subtitle: 'Ubah status persetujuan RPP',
      icon: Icons.swap_horiz_rounded,
      primaryColor: primary,
      content: _buildBody(),
      footer: BottomSheetFooter(
        primaryLabel: _isUpdating ? 'Menyimpan...' : 'Update Status',
        primaryColor: primary,
        primaryEnabled: !_isUpdating,
        onPrimary: _updateStatus,
        onSecondary: _isUpdating ? () {} : () => AppNavigator.pop(context),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status Persetujuan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildStatusOption('Pending', 'Menunggu', ColorUtils.warning600),
            const SizedBox(width: AppSpacing.sm),
            _buildStatusOption('Approved', 'Disetujui', ColorUtils.success600),
            const SizedBox(width: AppSpacing.sm),
            _buildStatusOption('Rejected', 'Ditolak', ColorUtils.error600),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Catatan (Opsional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            style: TextStyle(color: ColorUtils.slate900, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
              hintText: 'Berikan catatan untuk guru...',
              hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }
}
