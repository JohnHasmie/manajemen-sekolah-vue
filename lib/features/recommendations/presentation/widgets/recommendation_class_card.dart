// Expandable card for a single class in the recommendation class list.
// Like a Vue accordion-card component: shows summary stats and history rows.
// All state mutations (expand toggle, generate, navigation) are via callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_history_item.dart';

/// An expandable card widget showing one class with its recommendation summary.
///
/// Constructor params replace all references to parent state:
/// - [className] -- display name of the class
/// - [classId] -- ID string used as a key in parent state maps
/// - [classData] -- raw class map forwarded to the student screen
/// - [summary] -- optional summary map from the API
/// - [primaryColor] -- accent color derived from teacher role
/// - [isLoading] -- whether the summary is loading
/// - [isGenerating] -- whether a generation job is in progress
/// - [schedulesLoaded] -- whether schedule data is ready (shows Generate button)
/// - [history] -- grouped history list for the expanded section
/// - [isLoadingHistory] -- whether history is loading
/// - [isExpanded] -- whether the card is currently expanded
/// - [onToggleExpand] -- called when the header row is tapped
/// - [onGenerate] -- called when the Generate button is pressed
/// - [onHistoryItemTap] -- called when a history row is tapped; receives [entry]
///   so the parent can navigate and refresh as needed
class RecommendationClassCard extends StatelessWidget {
  final String className;
  final String classId;
  final Map<String, dynamic> classData;
  final Map<String, dynamic>? summary;
  final Color primaryColor;
  final bool isLoading;
  final bool isGenerating;
  final bool schedulesLoaded;
  final List<Map<String, dynamic>> history;
  final bool isLoadingHistory;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onGenerate;
  final void Function(Map<String, dynamic> entry) onHistoryItemTap;

  const RecommendationClassCard({
    super.key,
    required this.className,
    required this.classId,
    required this.classData,
    required this.primaryColor,
    required this.onToggleExpand,
    required this.onGenerate,
    required this.onHistoryItemTap,
    this.summary,
    this.isLoading = false,
    this.isGenerating = false,
    this.schedulesLoaded = false,
    this.history = const [],
    this.isLoadingHistory = false,
    this.isExpanded = false,
  });

  Map<String, int> _toCountMap(dynamic data) {
    if (data is Map) {
      return data.map(
        (k, v) => MapEntry(
          k.toString(),
          v is int ? v : int.tryParse(v.toString()) ?? 0,
        ),
      );
    }
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final byStatus = _toCountMap(summary?['by_status']);
    final totalRec = byStatus.values.fold<int>(0, (sum, v) => sum + v);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row - tap to expand
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggleExpand,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: isExpanded ? Radius.zero : const Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.class_outlined,
                        size: 24,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (isLoading)
                            Text(
                              'Memuat...',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate400,
                              ),
                            )
                          else if (totalRec > 0)
                            Text(
                              '$totalRec rekomendasi  •  ${history.length} sesi',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate500,
                              ),
                            )
                          else
                            Text(
                              'Belum ada rekomendasi',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: ColorUtils.slate400,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Divider(height: 1, color: ColorUtils.slate200),

            // History list
            if (isLoadingHistory)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                ),
              )
            else if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 32,
                      color: ColorUtils.slate300,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Belum ada riwayat rekomendasi',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorUtils.slate500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tekan tombol Generate untuk membuat rekomendasi AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate400,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final entry = history[index];
                  return RecommendationHistoryItem(
                    entry: entry,
                    onTap: () => onHistoryItemTap(entry),
                  );
                },
              ),

            // Generate button
            if (schedulesLoaded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isGenerating ? null : onGenerate,
                    icon: isGenerating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: primaryColor,
                          ),
                    label: Text(
                      isGenerating ? 'Memproses...' : 'Generate Rekomendasi AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isGenerating
                            ? ColorUtils.slate400
                            : primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isGenerating
                            ? ColorUtils.slate300
                            : primaryColor.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
