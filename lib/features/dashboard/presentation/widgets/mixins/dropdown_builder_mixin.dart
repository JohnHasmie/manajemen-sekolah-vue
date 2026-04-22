import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building dropdown widgets in attendance dialog.
mixin DropdownBuilderMixin {
  void setState(VoidCallback fn);

  bool get isWeekly;
  String get selectedMonth;
  String get selectedWeek;
  List<String> get months;
  List<String> get weeks;

  Future<void> fetchData();

  Widget buildTypeDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: isWeekly ? 'Pekanan' : 'Harian',
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w500,
          ),
          onChanged: _onTypeChanged,
          items: _buildTypeItems(),
        ),
      ),
    );
  }

  void _onTypeChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _setIsWeekly(newValue == 'Pekanan');
      });
    }
  }

  List<DropdownMenuItem<String>> _buildTypeItems() {
    return ['Harian', 'Pekanan'].map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(value: value, child: Text(value));
    }).toList();
  }

  Widget buildMonthDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedMonth,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 10,
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w500,
          ),
          onChanged: _onMonthChanged,
          items: _buildMonthItems(),
        ),
      ),
    );
  }

  void _onMonthChanged(String? newValue) {
    if (newValue != null && newValue != selectedMonth) {
      setState(() {
        _setSelectedMonth(newValue);
      });
      fetchData();
    }
  }

  List<DropdownMenuItem<String>> _buildMonthItems() {
    return months.map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(value: value, child: Text(value));
    }).toList();
  }

  Widget buildWeekDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedWeek,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 10,
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w500,
          ),
          onChanged: _onWeekChanged,
          items: _buildWeekItems(),
        ),
      ),
    );
  }

  void _onWeekChanged(String? newValue) {
    if (newValue != null && newValue != selectedWeek) {
      setState(() {
        _setSelectedWeek(newValue);
      });
      fetchData();
    }
  }

  List<DropdownMenuItem<String>> _buildWeekItems() {
    return weeks.map<DropdownMenuItem<String>>((String value) {
      return DropdownMenuItem<String>(value: value, child: Text(value));
    }).toList();
  }

  void _setIsWeekly(bool value);
  void _setSelectedMonth(String value);
  void _setSelectedWeek(String value);
}
