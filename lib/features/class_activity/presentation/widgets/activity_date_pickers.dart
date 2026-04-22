import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

import 'package:manajemensekolah/features/class_activity/presentation/widgets/mixins/date_picker_header_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/mixins/date_picker_theme_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/mixins/date_picker_footer_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/mixins/time_picker_mixin.dart';

/// Modern date picker for selecting activity date
class ActivityDatePicker extends StatefulWidget {
  final DateTime initialDate;
  final String title;
  final Function(DateTime) onDateSelected;

  const ActivityDatePicker({
    super.key,
    required this.initialDate,
    required this.title,
    required this.onDateSelected,
  });

  @override
  State<ActivityDatePicker> createState() => _ActivityDatePickerState();
}

class _ActivityDatePickerState extends State<ActivityDatePicker>
    with DatePickerHeaderMixin, DatePickerThemeMixin, DatePickerFooterMixin {
  late DateTime tempDate;

  @override
  void initState() {
    super.initState();
    tempDate = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildHeader(
            title: widget.title,
            icon: Icons.calendar_today_rounded,
            primaryColor: p,
          ),
          SizedBox(
            height: 340,
            child: Theme(
              data: buildDatePickerTheme(p),
              child: Material(
                color: Colors.transparent,
                child: CalendarDatePicker(
                  initialDate: tempDate,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (date) {
                    tempDate = date;
                  },
                ),
              ),
            ),
          ),
          buildFooter(
            label: 'Pilih Tanggal',
            primaryColor: p,
            onPressed: () {
              widget.onDateSelected(tempDate);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Modern date-time picker for selecting activity deadline
class ActivityDateTimePicker extends StatefulWidget {
  final DateTime initialDateTime;
  final String title;
  final Function(DateTime) onDateTimeSelected;

  const ActivityDateTimePicker({
    super.key,
    required this.initialDateTime,
    required this.title,
    required this.onDateTimeSelected,
  });

  @override
  State<ActivityDateTimePicker> createState() => _ActivityDateTimePickerState();
}

class _ActivityDateTimePickerState extends State<ActivityDateTimePicker>
    with
        DatePickerHeaderMixin,
        DatePickerThemeMixin,
        DatePickerFooterMixin,
        TimePickerMixin {
  late DateTime tempDate;
  late TimeOfDay tempTime;

  @override
  void initState() {
    super.initState();
    tempDate = widget.initialDateTime;
    tempTime = TimeOfDay.fromDateTime(widget.initialDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildHeader(
            title: widget.title,
            icon: Icons.access_time_rounded,
            primaryColor: p,
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 330,
                    child: Theme(
                      data: buildDatePickerTheme(p),
                      child: Material(
                        color: Colors.transparent,
                        child: CalendarDatePicker(
                          initialDate: tempDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 2),
                          ),
                          onDateChanged: (date) {
                            tempDate = date;
                          },
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        buildTimePickerHeader(),
                        const SizedBox(height: 16),
                        buildTimePickerContainer(
                          primaryColor: p,
                          tempTime: tempTime,
                          onTimeChanged: (hour, minute) {
                            setState(() {
                              tempTime = TimeOfDay(hour: hour, minute: minute);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          buildFooter(
            label: 'Simpan Batas Waktu',
            primaryColor: p,
            onPressed: () {
              final finalDateTime = DateTime(
                tempDate.year,
                tempDate.month,
                tempDate.day,
                tempTime.hour,
                tempTime.minute,
              );
              widget.onDateTimeSelected(finalDateTime);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
