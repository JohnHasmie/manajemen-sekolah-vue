import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

mixin ProgressCardMixin {
  Widget buildProgressCard({
    required int totalChapters,
    required int completedChapters,
    required int totalSubs,
    required int completedSubs,
  }) {
    final progressPercent = totalSubs > 0
        ? (completedSubs / totalSubs * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          _buildStatsRow(
            totalChapters: totalChapters,
            totalSubs: totalSubs,
            completedChapters: completedChapters,
            progressPercent: progressPercent,
          ),
          const SizedBox(height: 10),
          _buildProgressBar(totalSubs, completedSubs),
          const SizedBox(height: 10),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildStatsRow({
    required int totalChapters,
    required int totalSubs,
    required int completedChapters,
    required int progressPercent,
  }) {
    return Row(
      children: [
        _statItem('$totalChapters', 'Bab', ColorUtils.getRoleColor('guru')),
        _divider(),
        _statItem('$totalSubs', 'Sub-bab', ColorUtils.slate600),
        _divider(),
        _statItem('$completedChapters', 'Selesai', ColorUtils.success600),
        _divider(),
        _statItem('$progressPercent%', 'Progress', ColorUtils.info600),
      ],
    );
  }

  Widget _buildProgressBar(int totalSubs, int completedSubs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: totalSubs > 0 ? completedSubs / totalSubs : 0,
        minHeight: 5,
        backgroundColor: ColorUtils.slate100,
        color: ColorUtils.getRoleColor('guru'),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        _legendDot(ColorUtils.success600, 'Dipilih'),
        const SizedBox(width: 12),
        _legendDot(ColorUtils.violet500, 'AI Generated'),
        const SizedBox(width: 12),
        _legendDot(ColorUtils.info600, 'Digunakan'),
      ],
    );
  }

  Widget _statItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 30, color: ColorUtils.slate200);
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: ColorUtils.slate500)),
      ],
    );
  }
}
