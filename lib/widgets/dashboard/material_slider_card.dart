// Teaching material slider card for the dashboard with progress tracking.
//
// Like a Vue `<MaterialProgressCard>` dashboard widget with a swipeable
// carousel. Each slide shows a subject's chapter completion progress with
// a progress bar and "next chapter" hint. Similar to a course progress
// card in a Laravel LMS dashboard.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/widgets/dashboard/schedule_slider_card.dart';

/// A swipeable dashboard card showing teaching material progress per subject.
///
/// Like a Vue `<MaterialSliderCard>` with props:
/// - [materials] - list of material data maps with 'class_name', 'subject_name',
///   'total_chapters', 'completed_chapters', 'next_chapter'
/// - [onTap] - navigate to full materials screen
///
/// Uses `PageView` for swiping between subjects and shows a `LinearProgressIndicator`
/// for chapter completion. Shows empty state when no materials exist.
class MaterialSliderCard extends StatefulWidget {
  final List<dynamic> materials;
  final VoidCallback? onTap;

  const MaterialSliderCard({super.key, required this.materials, this.onTap});

  @override
  State<MaterialSliderCard> createState() => _MaterialSliderCardState();
}

class _MaterialSliderCardState extends State<MaterialSliderCard> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.materials.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.info600.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.materials.length,
            itemBuilder: (context, index) {
              final material = widget.materials[index];
              return InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: _buildMaterialContent(material),
                ),
              );
            },
          ),
          if (widget.materials.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.materials.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, color: ColorUtils.slate400, size: 24),
            SizedBox(height: 4),
            Text(
              "No materials",
              style: TextStyle(
                color: ColorUtils.slate500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialContent(dynamic material) {
    final className = material['class_name'] ?? '-';
    final subjectName = material['subject_name'] ?? '-';
    final totalChapters = material['total_chapters'] ?? 0;
    final completedChapters = material['completed_chapters'] ?? 0;
    final nextChapter = material['next_chapter'];
    final progress = totalChapters > 0 ? completedChapters / totalChapters : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ColorUtils.info600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 16,
                color: ColorUtils.info600,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$completedChapters / $totalChapters Bab',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate700,
                ),
              ),
            ),
          ],
        ),
        Spacer(),
        // Subject name
        Text(
          subjectName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
            height: 1.1,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
        // Class name
        Text(
          className,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
            letterSpacing: 0.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 6),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: ColorUtils.slate200,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? ColorUtils.success600 : ColorUtils.info600,
            ),
          ),
        ),
        SizedBox(height: 4),
        // Next chapter
        if (nextChapter != null)
          Text(
            'Selanjutnya: ${nextChapter['title'] ?? '-'}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        else
          Text(
            'Semua bab selesai',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: ColorUtils.success600,
            ),
          ),
        SizedBox(height: 8), // Space for dots
      ],
    );
  }
}
