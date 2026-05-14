import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

mixin SessionCopyDialogMixin on State<DaySessionManagementSheet> {
  Future<void> copySchedule(dynamic sourceDay);

  void showCopyDialog() {
    final availableDays = widget.allDays.where((d) {
      final dId = d['id'].toString();
      return dId != widget.day['id'].toString() &&
          (widget.allSessionsByDay[dId] ?? []).isNotEmpty;
    }).toList();

    AppBottomSheet.show<void>(
      context: context,
      title: 'Salin Jadwal Dari...',
      icon: Icons.copy_rounded,
      primaryColor: ColorUtils.brandAzure,
      content: _buildDaysList(availableDays),
    );
  }

  Widget _buildDaysList(List<dynamic> availableDays) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < availableDays.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: ColorUtils.slate100,
              indent: 16,
              endIndent: 16,
            ),
          _buildDayTile(availableDays[i]),
        ],
      ],
    );
  }

  Widget _buildDayTile(dynamic d) {
    final count = widget.allSessionsByDay[d['id'].toString()]?.length ?? 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: ColorUtils.brandAzure.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(9)),
        ),
        child: Icon(
          Icons.calendar_today_rounded,
          color: ColorUtils.brandAzure,
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
  }
}
