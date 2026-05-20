import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

mixin SessionTimePickerMixin on State<DaySessionManagementSheet> {
  /// Renders the Mulai/Selesai time fields.
  ///
  /// History: this used to own the `showTimePicker` call internally,
  /// mutating its own `startTime` / `endTime` parameters and calling
  /// `setModalState` — which silently failed because the parent
  /// `StatefulBuilder` rebuilt with the OLD values from its enclosing
  /// scope. We now expose a pure-presentational widget that delegates
  /// picking + state mutation to [onPickTime], so the parent owns the
  /// scope where the mutation lives.
  Widget buildTimeFields(
    TimeOfDay startTime,
    TimeOfDay endTime,
    Future<void> Function(bool isStart) onPickTime,
  ) {
    return Row(
      children: [
        buildTimeField('Mulai', startTime, true, onPickTime),
        const SizedBox(width: 10),
        buildTimeField('Selesai', endTime, false, onPickTime),
      ],
    );
  }

  Widget buildTimeField(
    String label,
    TimeOfDay time,
    bool isStart,
    Future<void> Function(bool isStart) pickTime,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => pickTime(isStart),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: ColorUtils.corporateBlue600,
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
                  ),
                  const SizedBox(height: 1),
                  Builder(
                    builder: (context) => Text(
                      time.format(context),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHourField(TextEditingController hourController) {
    return TextField(
      controller: hourController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Jam Ke-',
        prefixIcon: Icon(
          Icons.tag_rounded,
          color: ColorUtils.corporateBlue600,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: ColorUtils.corporateBlue600,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}
