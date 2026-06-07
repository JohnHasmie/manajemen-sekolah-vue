import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/mini_bar_chart.dart';

/// Mixin for building chart content in attendance dialog.
mixin ChartContentBuilderMixin {
  void setState(VoidCallback fn);
  BuildContext get context;

  bool get isWeekly;
  PageController get pageController;
  List<Map<String, dynamic>> get classesData;
  bool get isLoading;

  Widget buildDropdownBuilderSection();

  Widget buildChartContent() {
    if (isLoading) {
      return _buildLoadingContent();
    }
    if (classesData.isEmpty) {
      return _buildEmptyContent();
    }
    return _buildPageViewContent();
  }

  Widget _buildLoadingContent() {
    return SizedBox(
      height: 380,
      child: Center(
        child: CircularProgressIndicator(color: ColorUtils.warning600),
      ),
    );
  }

  Widget _buildEmptyContent() {
    return SizedBox(
      height: 380,
      child: Center(child: Text(AppLocalizations.noAttendanceData.tr)),
    );
  }

  Widget _buildPageViewContent() {
    return SizedBox(
      height: 380,
      child: PageView.builder(
        controller: pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: classesData.length,
        itemBuilder: (context, index) => _buildPageItem(index),
      ),
    );
  }

  Widget _buildPageItem(int index) {
    final item = classesData[index];
    final title = item['title'] as String;
    final chartData = _extractChartData(item);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPageItemHeader(title),
        const SizedBox(height: AppSpacing.lg),
        _buildNavigationHint(),
        const SizedBox(height: AppSpacing.xxl),
        _buildChartOrEmpty(title, chartData),
      ],
    );
  }

  Widget _buildPageItemHeader(String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ColorUtils.slate800,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            buildDropdownBuilderSection(),
            const SizedBox(height: AppSpacing.sm),
            isWeekly ? buildMonthDropdown() : buildWeekDropdown(),
          ],
        ),
      ],
    );
  }

  Widget _buildNavigationHint() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        kDasChartSwipeHint.tr,
        style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
      ),
    );
  }

  Widget _buildChartOrEmpty(String title, List<double> chartData) {
    if (title == 'Absensi Belum Ada Data' ||
        chartData.every((val) => val == 0.0)) {
      return _buildNoDataWidget();
    }
    return _buildChartWidget(chartData);
  }

  Widget _buildNoDataWidget() {
    return SizedBox(
      height: 212,
      child: Center(
        child: Text(
          kDasChartNoAttendanceData.tr,
          style: TextStyle(
            fontSize: 14,
            color: ColorUtils.slate400,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildChartWidget(List<double> chartData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildMiniBarChart(chartData),
        const SizedBox(height: AppSpacing.md),
        _buildChartLabels(chartData),
      ],
    );
  }

  Widget _buildMiniBarChart(List<double> chartData) {
    return Container(
      alignment: Alignment.center,
      height: 200,
      child: MiniBarChart(
        data: chartData,
        color: ColorUtils.warning600,
        height: 200,
        width: chartData.length * 44.0,
        barWidth: 22.0,
        barSpacing: 22.0,
        cornerRadius: 4.0,
        showLabels: true,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: ColorUtils.slate700,
        ),
      ),
    );
  }

  Widget _buildChartLabels(List<double> chartData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(chartData.length, _buildLabelItem),
    );
  }

  Widget _buildLabelItem(int idx) {
    return Container(
      width: 44.0,
      alignment: Alignment.center,
      child: Text(
        isWeekly
            ? '${kDasChartWeekLabel.tr} ${idx + 1}'
            : ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'][idx],
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate600,
        ),
        maxLines: 1,
      ),
    );
  }

  List<double> _extractChartData(Map<String, dynamic> item) {
    return isWeekly
        ? List<double>.from(
            (item['weekly_data'] as List).map((e) => (e as num).toDouble()),
          )
        : List<double>.from(
            (item['daily_data'] as List).map((e) => (e as num).toDouble()),
          );
  }

  Widget buildMonthDropdown();
  Widget buildWeekDropdown();
}
