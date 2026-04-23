import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/report_card_print_screen.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Header widget for report card detail screen.
class ReportCardHeader extends StatelessWidget {
  final String studentName;
  final String className;
  final String? status;
  final Map<String, dynamic>? existingRaport;
  final VoidCallback onBack;

  const ReportCardHeader({
    super.key,
    required this.studentName,
    required this.className,
    required this.status,
    required this.existingRaport,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 8,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p, p.withValues(alpha: 0.85)],
        ),
      ),
      child: Row(
        children: [
          _buildBackButton(),
          const SizedBox(width: 12),
          _buildTitle(p),
          if (status == 'final') _buildPrintButton(context, p),
          const SizedBox(width: 4),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildTitle(Color roleColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Isi Raport',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              Flexible(
                child: Text(
                  '$studentName · $className',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status != null) _buildStatusBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: _getStatusBadgeWidget(),
    );
  }

  Widget _getStatusBadgeWidget() {
    if (status == 'published') {
      return const StatusBadge(
        label: 'Terbit',
        color: Colors.white,
        fontSize: 9,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      );
    } else if (status == 'final') {
      return const StatusBadge(
        label: 'Final',
        color: Colors.white,
        fontSize: 9,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      );
    } else {
      return const StatusBadge(
        label: 'Draft',
        color: Colors.white,
        fontSize: 9,
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      );
    }
  }

  Widget _buildPrintButton(BuildContext context, Color roleColor) {
    return GestureDetector(
      onTap: () {
        if (existingRaport != null) {
          AppNavigator.push(
            context,
            ReportCardPrintScreen(
              reportCardData: existingRaport!,
              studentName: studentName,
              className: className,
            ),
          );
        }
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.print_rounded, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
    );
  }
}
