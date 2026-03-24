// Schedule slider card for the dashboard showing today's upcoming classes.
//
// Like a Vue `<ScheduleCarousel>` dashboard widget with swipeable cards,
// or a Bootstrap carousel in a Laravel dashboard. Each slide shows one
// schedule entry with subject name, class, and time. Also exports the
// reusable [SmoothPageIndicator] dot indicator widget.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A swipeable dashboard card showing today's class schedule entries.
///
/// Like a Vue `<ScheduleSliderCard>` with props:
/// - [schedules] - list of schedule data maps with subject, class, and time info
/// - [onTap] - navigate to the full schedule screen
///
/// Uses `PageView` for swiping between schedule entries (like a Vue Swiper).
/// Shows an empty state when no schedules exist for today.
class ScheduleSliderCard extends StatefulWidget {
  final List<dynamic> schedules;
  final VoidCallback? onTap;

  const ScheduleSliderCard({super.key, required this.schedules, this.onTap});

  @override
  State<ScheduleSliderCard> createState() => _ScheduleSliderCardState();
}

class _ScheduleSliderCardState extends State<ScheduleSliderCard> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.schedules.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.corporateBlue600.withValues(alpha: 0.12),
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
            itemCount: widget.schedules.length,
            itemBuilder: (context, index) {
              final schedule = widget.schedules[index];
              return InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: _buildScheduleContent(schedule),
                ),
              );
            },
          ),
          // Page Indicator (dots)
          if (widget.schedules.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.schedules.length,
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
            Icon(Icons.event_busy, color: ColorUtils.slate400, size: 24),
            SizedBox(height: 4),
            Text(
              "No classes",
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

  /// Builds the content for a single schedule slide: icon, time badge,
  /// subject name, and class name. Like a Vue `<ScheduleSlide>` template.
  Widget _buildScheduleContent(dynamic schedule) {
    final subjectName =
        schedule['subject']?['name'] ??
        schedule['subject_name'] ??
        'Unknown Subject';
    final className =
        schedule['class']?['name'] ?? schedule['class_name'] ?? '-';
    final startTime =
        schedule['lesson_hour']?['start_time'] ??
        schedule['start_time'] ??
        '--:--';
    final endTime =
        schedule['lesson_hour']?['end_time'] ?? schedule['end_time'] ?? '--:--';
    final formattedTime = "${_formatTime(startTime)} - ${_formatTime(endTime)}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header Row with Icon and Time
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ColorUtils.corporateBlue50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.class_outlined,
                size: 16,
                color: ColorUtils.corporateBlue600,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate700,
                ),
              ),
            ),
          ],
        ),
        Spacer(), // Push text to bottom
        Text(
          subjectName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
            height: 1.1,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2),
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
        SizedBox(height: 12), // Space for dots
      ],
    );
  }

  String _formatTime(String time) {
    if (time.length > 5) {
      return time.substring(0, 5);
    }
    return time;
  }
}

/// A smooth animated page indicator (dots) for PageView widgets.
///
/// Like a Vue carousel dot indicator or the `smooth_page_indicator` package.
/// Animates the active dot to be wider than inactive dots using `AnimatedContainer`.
/// Reused across multiple dashboard slider cards (schedule, material, attendance, finance).
class SmoothPageIndicator extends StatelessWidget {
  final PageController controller;
  final int count;

  const SmoothPageIndicator({
    super.key,
    required this.controller,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Calculate current page (handling initial state)
        double page = 0;
        try {
          if (controller.hasClients) page = controller.page ?? 0;
        } catch (e) {
          page = 0;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (index) {
            // Simple logic for active dot
            bool isActive = (page.round() == index);
            return AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 2),
              width: isActive ? 12 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? ColorUtils.corporateBlue600
                    : ColorUtils.slate300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }
}
