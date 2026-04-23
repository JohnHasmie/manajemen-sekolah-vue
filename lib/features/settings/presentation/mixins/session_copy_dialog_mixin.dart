import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

mixin SessionCopyDialogMixin on State<DaySessionManagementSheet> {
  Future<void> copySchedule(dynamic sourceDay);

  void showCopyDialog() {
    final availableDays = widget.allDays.where((d) {
      final dId = d['id'].toString();
      return dId != widget.day['id'].toString() &&
          (widget.allSessionsByDay[dId] ?? []).isNotEmpty;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(),
            _buildDaysList(availableDays),
            _buildCloseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: const Icon(
              Icons.copy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Text(
            'Salin Jadwal Dari...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList(List<dynamic> availableDays) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: availableDays.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: ColorUtils.slate100,
          indent: 16,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final d = availableDays[index];
          final count =
              widget.allSessionsByDay[d['id'].toString()]?.length ?? 0;
          return ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(9)),
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: ColorUtils.corporateBlue600,
                size: 17,
              ),
            ),
            title: Text(
              dayNameToIndonesian(d['name'] ?? 'Hari'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate900,
              ),
            ),
            subtitle: Text(
              '$count Sesi',
              style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: ColorUtils.slate400,
            ),
            onTap: () {
              AppNavigator.pop(context);
              copySchedule(d);
            },
          );
        },
      ),
    );
  }

  Widget _buildCloseButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => AppNavigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: BorderSide(color: ColorUtils.slate300),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          child: Text(
            AppLocalizations.cancel.tr,
            style: TextStyle(color: ColorUtils.slate600),
          ),
        ),
      ),
    );
  }
}
