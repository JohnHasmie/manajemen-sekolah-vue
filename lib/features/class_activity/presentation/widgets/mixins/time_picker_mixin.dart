import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building time picker UI components
mixin TimePickerMixin {
  /// Builds the time picker header label
  Widget buildTimePickerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.access_time_rounded, size: 18, color: ColorUtils.slate400),
        const SizedBox(width: 8),
        Text(
          'Set Waktu (Jam : Menit)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate700,
          ),
        ),
      ],
    );
  }

  /// Builds the time picker container with hours and minutes
  Widget buildTimePickerContainer({
    required Color primaryColor,
    required TimeOfDay tempTime,
    required Function(int, int) onTimeChanged,
  }) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: _buildTimePickerDecoration(),
      child: _buildTimeRow(primaryColor, tempTime, onTimeChanged),
    );
  }

  /// Builds the time row with hour, colon, and minute pickers
  Widget _buildTimeRow(
    Color primaryColor,
    TimeOfDay tempTime,
    Function(int, int) onTimeChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: _buildHourPicker(
            primaryColor: primaryColor,
            initialItem: tempTime.hour,
            onChanged: (hour) {
              onTimeChanged(hour, tempTime.minute);
            },
          ),
        ),
        Text(
          ':',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: ColorUtils.slate400,
          ),
        ),
        Expanded(
          child: _buildMinutePicker(
            primaryColor: primaryColor,
            initialItem: tempTime.minute,
            onChanged: (minute) {
              onTimeChanged(tempTime.hour, minute);
            },
          ),
        ),
      ],
    );
  }

  /// Builds the time picker container decoration
  BoxDecoration _buildTimePickerDecoration() {
    return BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ColorUtils.slate200),
    );
  }

  /// Builds the hour picker
  Widget _buildHourPicker({
    required Color primaryColor,
    required int initialItem,
    required Function(int) onChanged,
  }) {
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initialItem),
      itemExtent: 40,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
        capStartEdge: true,
        capEndEdge: false,
      ),
      onSelectedItemChanged: onChanged,
      children: List.generate(
        24,
        (index) => Center(
          child: Text(
            index.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the minute picker
  Widget _buildMinutePicker({
    required Color primaryColor,
    required int initialItem,
    required Function(int) onChanged,
  }) {
    return CupertinoPicker(
      scrollController: FixedExtentScrollController(initialItem: initialItem),
      itemExtent: 40,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
        capStartEdge: false,
        capEndEdge: true,
      ),
      onSelectedItemChanged: onChanged,
      children: List.generate(
        60,
        (index) => Center(
          child: Text(
            index.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
